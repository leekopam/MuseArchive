import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive_io.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/track.dart';
import '../utils/file_utils.dart';
import 'album_backup_utils.dart';
import 'i_album_repository.dart';

typedef ShareBackupFile = Future<void> Function(String backupPath);
typedef SaveBackupFile =
    Future<String?> Function(String backupPath, String fileName);

/// Album repository implementation backed by Hive.
class AlbumRepository implements IAlbumRepository {
  // region singleton
  static final AlbumRepository _instance = AlbumRepository._internal();
  factory AlbumRepository() => _instance;
  AlbumRepository._internal();
  //endregion

  // endregion

  @visibleForTesting
  ShareBackupFile shareBackupFile = _defaultShareBackupFile;

  @visibleForTesting
  SaveBackupFile saveBackupFile = _defaultSaveBackupFile;

  /// 마지막 복원 시도의 실패 사유(사용자 표시용). 성공 시 null.
  @override
  String? get lastBackupRestoreError => _lastBackupRestoreError;
  String? _lastBackupRestoreError;

  /// 마지막 복원에서 스키마 불일치로 건너뛴 항목 수.
  @override
  int get lastBackupSkippedCount => _lastBackupSkippedCount;
  int _lastBackupSkippedCount = 0;

  @protected
  set lastBackupSkippedCount(int value) => _lastBackupSkippedCount = value;

  // region constants
  static const String _boxName = 'albumBox';
  static const String _artistBoxName = 'artistBox';
  //endregion

  // endregion

  // region initialization and listeners
  @override
  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
    await Hive.openBox(_artistBoxName);
  }

  Box get box => Hive.box(_boxName);
  Box get artistBox => Hive.box(_artistBoxName);

  // box.listenable()은 호출마다 새 인스턴스와 스트림 구독을 만든다.
  // add/removeListener가 같은 대상에 적용되도록 인스턴스를 유지한다.
  late final ValueListenable _boxListenable = box.listenable();

  @override
  ValueListenable get listenable => _boxListenable;

  @visibleForTesting
  void resetPlatformHooks() {
    shareBackupFile = _defaultShareBackupFile;
    saveBackupFile = _defaultSaveBackupFile;
  }
  //endregion

  // endregion

  // region CRUD
  @override
  Future<List<Album>> getAll() async {
    return box.values.map((data) => Album.fromMap(data)).toList();
  }

  @override
  Future<void> add(Album album) async {
    if (album.imagePath != null && album.imagePath!.isNotEmpty) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory('${appDir.path}/album_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        final imageFile = File(album.imagePath!);
        if (await imageFile.exists()) {
          final extension = path.extension(album.imagePath!);
          final newPath =
              '${imagesDir.path}/${album.id}_${DateTime.now().millisecondsSinceEpoch}$extension';
          await imageFile.copy(newPath);
          album = album.copyWith(imagePath: newPath);
        }
      } catch (e) {
        debugPrint("Image save failed: $e");
      }
    }

    await box.add(album.toMap());
    await _updateArtistAlbums(album.artists, album.id, isAdding: true);
  }

  @override
  Future<void> update(String albumId, Album album) async {
    dynamic keyToUpdate;
    Map? oldAlbumMap;

    for (final key in box.keys) {
      final value = box.get(key) as Map?;
      if (value != null && value['id'] == albumId) {
        keyToUpdate = key;
        oldAlbumMap = value;
        break;
      }
    }

    if (keyToUpdate == null || oldAlbumMap == null) {
      debugPrint("Album to update not found: $albumId");
      return;
    }

    final oldAlbum = Album.fromMap(oldAlbumMap);
    var albumToSave = album;

    if (oldAlbum.imagePath != album.imagePath && album.imagePath != null) {
      try {
        if (oldAlbum.imagePath != null) {
          final oldFile = File(oldAlbum.imagePath!);
          if (await oldFile.exists()) {
            await oldFile.delete();
            invalidateFileExists(oldAlbum.imagePath!);
          }
        }

        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory('${appDir.path}/album_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        final imageFile = File(album.imagePath!);
        if (await imageFile.exists()) {
          final extension = path.extension(album.imagePath!);
          final newPath =
              '${imagesDir.path}/${album.id}_${DateTime.now().millisecondsSinceEpoch}$extension';
          await imageFile.copy(newPath);
          albumToSave = album.copyWith(imagePath: newPath);
        }
      } catch (e) {
        debugPrint("Image update failed: $e");
      }
    }

    await box.put(keyToUpdate, albumToSave.toMap());

    final oldArtists = oldAlbum.artists.toSet();
    final newArtists = albumToSave.artists.toSet();

    final removedArtists = oldArtists.difference(newArtists);
    final addedArtists = newArtists.difference(oldArtists);

    if (removedArtists.isNotEmpty) {
      await _updateArtistAlbums(
        removedArtists.toList(),
        albumId,
        isAdding: false,
      );
    }
    if (addedArtists.isNotEmpty) {
      await _updateArtistAlbums(addedArtists.toList(), albumId, isAdding: true);
    }

    // 동일 곡 한글명 동기화
    await _syncTrackTitleKr(oldAlbum, albumToSave);
  }

  /// 트랙 titleKr 변경 시 같은 아티스트의 다른 앨범 동일 곡에 자동 반영
  Future<void> _syncTrackTitleKr(Album oldAlbum, Album newAlbum) async {
    // 변경된 titleKr이 있는 트랙만 수집
    final changedTracks = <String, String?>{};
    for (final newTrack in newAlbum.tracks) {
      if (newTrack.isHeader) continue;
      final oldTrack = oldAlbum.tracks.cast<Track?>().firstWhere(
        (t) => t!.title == newTrack.title && !t.isHeader,
        orElse: () => null,
      );
      if (oldTrack == null && newTrack.titleKr != null ||
          oldTrack != null && oldTrack.titleKr != newTrack.titleKr) {
        changedTracks[newTrack.title.toLowerCase()] = newTrack.titleKr;
      }
    }
    if (changedTracks.isEmpty) return;

    final artistName = newAlbum.artist.toLowerCase();

    for (final key in box.keys) {
      final value = box.get(key) as Map?;
      if (value == null || value['id'] == newAlbum.id) continue;

      final otherAlbum = Album.fromMap(value);
      if (otherAlbum.artist.toLowerCase() != artistName) continue;

      var updated = false;
      final updatedTracks = otherAlbum.tracks.map((track) {
        if (track.isHeader) return track;
        final newTitleKr = changedTracks[track.title.toLowerCase()];
        if (newTitleKr == null &&
            !changedTracks.containsKey(track.title.toLowerCase())) {
          return track;
        }
        if (track.titleKr == newTitleKr) return track;
        updated = true;
        return track.copyWith(titleKr: newTitleKr);
      }).toList();

      if (updated) {
        final updatedAlbum = otherAlbum.copyWith(tracks: updatedTracks);
        await box.put(key, updatedAlbum.toMap());
      }
    }
  }

  @override
  Future<void> delete(String albumId, {bool preserveFiles = false}) async {
    dynamic keyToDelete;
    Map? albumMap;

    for (final key in box.keys) {
      final value = box.get(key) as Map?;
      if (value != null && value['id'] == albumId) {
        keyToDelete = key;
        albumMap = value;
        break;
      }
    }

    if (keyToDelete == null || albumMap == null) {
      debugPrint("Album to delete not found: $albumId");
      return;
    }

    final album = Album.fromMap(albumMap);
    // preserveFiles면 Undo 복원을 위해 커버 파일을 유지한다 (확정 시 호출자가 정리)
    if (!preserveFiles && album.imagePath != null) {
      try {
        final file = File(album.imagePath!);
        if (await file.exists()) {
          await file.delete();
          invalidateFileExists(album.imagePath!);
        }
      } catch (e) {
        debugPrint("Image delete failed: $e");
      }
    }

    await box.delete(keyToDelete);
    await _updateArtistAlbums(album.artists, album.id, isAdding: false);
  }

  @override
  Future<void> reorder(int oldIndex, int newIndex) async {
    final album = Album.fromMap(box.getAt(oldIndex));
    await box.deleteAt(oldIndex);

    final allAlbums = await getAll();
    allAlbums.insert(newIndex, album);

    await box.clear();
    for (var albumItem in allAlbums) {
      await box.add(albumItem.toMap());
    }
  }
  //endregion

  // endregion

  // region artist management
  Future<void> _updateArtistAlbums(
    List<String> artistNames,
    String albumId, {
    required bool isAdding,
  }) async {
    for (var artistName in artistNames) {
      try {
        dynamic artistKey;
        for (var key in artistBox.keys) {
          if (artistBox.get(key)['name'] == artistName) {
            artistKey = key;
            break;
          }
        }

        if (artistKey != null) {
          final artist = Artist.fromMap(artistBox.get(artistKey));
          List<String> albumIds = List.from(artist.albumIds);

          if (isAdding) {
            if (!albumIds.contains(albumId)) {
              albumIds.add(albumId);
            }
          } else {
            albumIds.remove(albumId);
          }

          if (albumIds.isEmpty) {
            await artistBox.delete(artistKey);
          } else {
            final updatedArtist = artist.copyWith(albumIds: albumIds);
            await artistBox.put(artistKey, updatedArtist.toMap());
          }
        } else if (isAdding) {
          final newArtist = Artist(name: artistName, albumIds: [albumId]);
          await artistBox.add(newArtist.toMap());
        }
      } catch (e) {
        debugPrint("Artist update failed: $e");
      }
    }
  }

  @override
  List<Artist> getAllArtists() {
    return artistBox.values.map((e) => Artist.fromMap(e)).toList();
  }

  @override
  List<Album> getAlbumsByArtist(String artistName) {
    return box.values
        .map((e) => Album.fromMap(e))
        .where((album) => album.artists.contains(artistName))
        .toList();
  }

  @override
  Artist? getArtistByName(String artistName) {
    try {
      final artistData = artistBox.values.firstWhere(
        (e) => Artist.fromMap(e).name == artistName,
        orElse: () => null,
      );
      if (artistData != null) {
        return Artist.fromMap(artistData);
      }
    } catch (e) {
      debugPrint("Artist lookup failed: $e");
    }
    return null;
  }

  @override
  Future<void> updateArtistImage(String artistName, String? imagePath) async {
    try {
      dynamic artistKey;
      Artist? existingArtist;

      for (var key in artistBox.keys) {
        final artist = Artist.fromMap(artistBox.get(key));
        if (artist.name == artistName) {
          artistKey = key;
          existingArtist = artist;
          break;
        }
      }

      if (artistKey != null && existingArtist != null) {
        // Delete the old image when it changes or is cleared.
        if (existingArtist.imagePath != null &&
            existingArtist.imagePath != imagePath) {
          final oldFile = File(existingArtist.imagePath!);
          if (await oldFile.exists()) {
            await oldFile.delete();
            invalidateFileExists(existingArtist.imagePath!);
          }
        }

        String? newPath = imagePath;

        // Save the new image if provided.
        if (imagePath != null) {
          final appDir = await getApplicationDocumentsDirectory();
          final imagesDir = Directory('${appDir.path}/artist_images');
          if (!await imagesDir.exists()) {
            await imagesDir.create(recursive: true);
          }

          final imageFile = File(imagePath);
          if (await imageFile.exists()) {
            final extension = path.extension(imagePath);
            newPath =
                '${imagesDir.path}/artist_${existingArtist.id}_${DateTime.now().millisecondsSinceEpoch}$extension';
            await imageFile.copy(newPath);
          }
        }

        final updatedArtist = existingArtist.copyWith(imagePath: newPath);
        await artistBox.put(artistKey, updatedArtist.toMap());
      } else {
        // Create an artist record when one does not exist yet.
        // This path is uncommon because this method usually updates an existing artist.
      }
    } catch (e) {
      debugPrint("Artist image update failed: $e");
    }
  }

  @override
  Future<void> updateArtistMetadata(
    String artistName,
    List<String> aliases,
    List<String> groups,
  ) async {
    try {
      dynamic artistKey;
      Artist? existingArtist;

      for (var key in artistBox.keys) {
        final artist = Artist.fromMap(artistBox.get(key));
        if (artist.name == artistName) {
          artistKey = key;
          existingArtist = artist;
          break;
        }
      }

      if (artistKey != null && existingArtist != null) {
        final updatedArtist = existingArtist.copyWith(
          aliases: aliases,
          groups: groups,
        );
        await artistBox.put(artistKey, updatedArtist.toMap());
      }
    } catch (e) {
      debugPrint("Artist metadata update failed: $e");
    }
  }

  @override
  List<String> getArtistNamesMatching(String query) {
    if (query.isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    final matchingNames = <String>{};

    for (var value in artistBox.values) {
      final artist = Artist.fromMap(value);
      // 1. Match by name
      if (artist.name.toLowerCase().contains(lowerQuery)) {
        matchingNames.add(artist.name);
        continue; // Already added, move on to the next artist.
      }

      // 2. Match aliases
      if (artist.aliases.any(
        (alias) => alias.toLowerCase().contains(lowerQuery),
      )) {
        matchingNames.add(artist.name);
      }
    }

    return matchingNames.toList();
  }
  //endregion

  // endregion

  // region query helpers
  @override
  List<String> getAllFormats() {
    final formats = <String>{};
    for (var data in box.values) {
      final album = Album.fromMap(data);
      formats.addAll(album.formats);
    }
    return formats.toList()..sort();
  }

  @override
  List<String> getAllGenres() {
    final genres = <String>{};
    for (var data in box.values) {
      final album = Album.fromMap(data);
      genres.addAll(album.genres);
    }
    return genres.toList()..sort();
  }

  @override
  List<String> getAllStyles() {
    final styles = <String>{};
    for (var data in box.values) {
      final album = Album.fromMap(data);
      styles.addAll(album.styles);
    }
    return styles.toList()..sort();
  }

  @override
  List<String> getAllLabels() {
    final labels = <String>{};
    for (var data in box.values) {
      final album = Album.fromMap(data);
      labels.addAll(album.labels);
    }
    return labels.toList()..sort();
  }

  @override
  List<String> getSmartArtistSuggestions(String query) {
    final lowerQuery = query.toLowerCase();
    final allArtists = box.values
        .expand((e) => Album.fromMap(e).artists)
        .toSet()
        .toList();

    allArtists.sort((a, b) {
      final aLower = a.toLowerCase();
      final bLower = b.toLowerCase();

      final aStarts = aLower.startsWith(lowerQuery);
      final bStarts = bLower.startsWith(lowerQuery);
      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;

      final aContains = aLower.contains(lowerQuery);
      final bContains = bLower.contains(lowerQuery);
      if (aContains && !bContains) return -1;
      if (!aContains && bContains) return 1;

      return a.compareTo(b);
    });

    return allArtists
        .where((artist) => artist.toLowerCase().contains(lowerQuery))
        .take(10)
        .toList();
  }
  //endregion

  // endregion

  // region backup and restore
  @override
  Future<String?> exportBackup() async {
    try {
      final tempDir = await getTemporaryDirectory();
      return exportBackupFromTempDirectory(tempDir);
    } catch (e) {
      debugPrint('Backup export failed: $e');
      return null;
    }
  }

  @visibleForTesting
  Future<String?> exportBackupFromTempDirectory(
    Directory tempDir, {
    int? timestamp,
  }) async {
    Directory? backupDir;
    String? zipFilePath;
    final effectiveTimestamp =
        timestamp ?? DateTime.now().millisecondsSinceEpoch;

    try {
      backupDir = Directory('${tempDir.path}/backup_$effectiveTimestamp');
      await backupDir.create(recursive: true);

      final albums = box.values.map((e) => Album.fromMap(e)).toList();
      final albumImagesDir = Directory('${backupDir.path}/images');
      await albumImagesDir.create(recursive: true);

      final albumsJson = <Map<String, dynamic>>[];
      for (final album in albums) {
        final albumJson = album.toMap();
        final imagePath = album.imagePath?.trim();
        if (imagePath != null && imagePath.isNotEmpty) {
          final imageFile = File(imagePath);
          if (await imageFile.exists()) {
            final fileName = buildBackupImageFileName(
              'album_${album.id}',
              imagePath,
            );
            await imageFile.copy('${albumImagesDir.path}/$fileName');
            albumJson['imagePath'] = 'images/$fileName';
          } else {
            albumJson['imagePath'] = null;
          }
        }
        albumsJson.add(albumJson);
      }

      final albumsFile = File('${backupDir.path}/albums.json');
      await albumsFile.writeAsString(jsonEncode(albumsJson));

      final artists = artistBox.values.map((e) => Artist.fromMap(e)).toList();
      final artistImagesDir = Directory('${backupDir.path}/artist_images');
      await artistImagesDir.create(recursive: true);

      final artistsJson = <Map<String, dynamic>>[];
      for (final artist in artists) {
        final artistJson = artist.toMap();
        final imagePath = artist.imagePath?.trim();
        if (imagePath != null && imagePath.isNotEmpty) {
          final imageFile = File(imagePath);
          if (await imageFile.exists()) {
            final fileName = buildBackupImageFileName(
              'artist_${artist.id}',
              imagePath,
            );
            await imageFile.copy('${artistImagesDir.path}/$fileName');
            artistJson['imagePath'] = 'artist_images/$fileName';
          } else {
            artistJson['imagePath'] = null;
          }
        }
        artistsJson.add(artistJson);
      }

      final artistsFile = File('${backupDir.path}/artists.json');
      await artistsFile.writeAsString(jsonEncode(artistsJson));

      zipFilePath =
          '${tempDir.path}/muse_archive_backup_$effectiveTimestamp.zip';
      final encoder = ZipFileEncoder();
      encoder.create(zipFilePath);

      if (await albumsFile.exists()) {
        await encoder.addFile(albumsFile);
      }
      if (await artistsFile.exists()) {
        await encoder.addFile(artistsFile);
      }

      if (await albumImagesDir.exists()) {
        final images = await albumImagesDir.list().toList();
        for (var img in images) {
          if (img is File) {
            final fileName = path.basename(img.path);
            await encoder.addFile(img, 'images/$fileName');
          }
        }
      }

      if (await artistImagesDir.exists()) {
        final images = await artistImagesDir.list().toList();
        for (var img in images) {
          if (img is File) {
            final fileName = path.basename(img.path);
            await encoder.addFile(img, 'artist_images/$fileName');
          }
        }
      }

      encoder.close();

      final file = File(zipFilePath);
      final size = await file.length();
      if (size <= 22) {
        throw Exception(
          'Backup file generation failed (size too small: ${size}B)',
        );
      }

      return zipFilePath;
    } catch (e) {
      debugPrint('Backup export failed: $e');
      if (zipFilePath != null) {
        try {
          final zipFile = File(zipFilePath);
          if (await zipFile.exists()) {
            await zipFile.delete();
          }
        } catch (_) {}
      }

      return null;
    } finally {
      if (backupDir != null) {
        try {
          if (await backupDir.exists()) {
            await backupDir.delete(recursive: true);
          }
        } catch (_) {}
      }
    }
  }

  @override
  Future<bool> shareBackup() async {
    try {
      final backupPath = await exportBackup();
      if (backupPath == null) return false;

      await shareBackupFile(backupPath);

      return true;
    } catch (e) {
      debugPrint('Backup share failed: $e');
      return false;
    }
  }

  @override
  Future<bool> saveBackupToDevice() async {
    try {
      final backupPath = await exportBackup();
      if (backupPath == null) return false;

      final fileName = path.basename(backupPath);
      final savedPath = await saveBackupFile(backupPath, fileName);

      return savedPath != null;
    } catch (e) {
      debugPrint('Backup save failed: $e');
      return false;
    }
  }

  @override
  Future<bool> importBackup() async {
    _lastBackupRestoreError = null;
    _lastBackupSkippedCount = 0;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.isEmpty) return false;

      final zipPath = result.files.first.path;
      if (zipPath == null) {
        _lastBackupRestoreError = '파일 경로를 읽을 수 없습니다.';
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final appDir = await getApplicationDocumentsDirectory();

      return importBackupFromZipPath(zipPath, tempDir: tempDir, appDir: appDir);
    } catch (e) {
      debugPrint('Backup restore failed: $e');
      _lastBackupRestoreError = '파일 선택 중 오류가 발생했습니다.';
      return false;
    }
  }

  static Future<void> _defaultShareBackupFile(String backupPath) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(backupPath)], subject: 'MuseArchive Backup'),
    );
  }

  static Future<String?> _defaultSaveBackupFile(
    String backupPath,
    String fileName,
  ) {
    return FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(
        sourceFilePath: backupPath,
        fileName: fileName,
      ),
    );
  }

  @visibleForTesting
  Future<bool> importBackupFromZipPath(
    String zipPath, {
    required Directory tempDir,
    required Directory appDir,
    int? timestamp,
  }) async {
    Directory? extractDir;
    Directory? stageDir;
    final effectiveTimestamp =
        timestamp ?? DateTime.now().millisecondsSinceEpoch;

    try {
      extractDir = Directory('${tempDir.path}/restore_$effectiveTimestamp');
      await extractDir.create(recursive: true);

      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      // 추출이 끝나기 전에 스테이징하면 이미지 해석이 누락된다
      await extractArchiveToDisk(archive, extractDir.path);

      // 구버전·재압축 zip에서 albums.json이 하위 폴더에 있을 수 있다
      final albumsFile = findBackupJsonFile(extractDir, 'albums.json');
      if (albumsFile == null) {
        throw Exception('백업 파일에서 albums.json을 찾을 수 없습니다.');
      }
      final backupRoot = albumsFile.parent;

      final albumsJsonRaw = decodeBackupList(await albumsFile.readAsString());
      if (albumsJsonRaw == null) {
        throw Exception('앨범 백업 데이터 형식이 올바르지 않습니다.');
      }

      final artistsFile = findBackupJsonFile(backupRoot, 'artists.json');
      List<dynamic>? artistsJsonRaw;
      if (artistsFile != null && await artistsFile.exists()) {
        artistsJsonRaw = decodeBackupList(await artistsFile.readAsString());
        if (artistsJsonRaw == null) {
          throw Exception('아티스트 백업 데이터 형식이 올바르지 않습니다.');
        }
      }

      stageDir = Directory('${tempDir.path}/restore_stage_$effectiveTimestamp');
      await stageDir.create(recursive: true);

      final stagedAlbumImagesDir = Directory('${stageDir.path}/album_images');
      await stagedAlbumImagesDir.create(recursive: true);
      final stagedArtistImagesDir = Directory('${stageDir.path}/artist_images');
      await stagedArtistImagesDir.create(recursive: true);

      // 한 항목의 파싱 실패가 전체 복원을 중단시키지 않도록 항목별로 건너뛴다
      var skippedAlbums = 0;
      final stagedAlbums = <Map<String, dynamic>>[];
      for (final albumData in albumsJsonRaw) {
        try {
          final albumMap = parseBackupJsonMap(albumData, 'album');
          final album = Album.fromMap(normalizeBackupAlbumMap(albumMap));
          final stagedAlbum = album.toMap();
          final imagePath = album.imagePath?.trim();

          if (imagePath != null && imagePath.isNotEmpty) {
            final sourceImage = resolveBackupImageFile(
              backupRoot,
              imagePath,
              searchFolders: const ['images'],
            );
            if (sourceImage != null) {
              final ext = path.extension(sourceImage.path);
              final fileName = 'album_${album.id}$ext';
              final stagedImagePath = '${stagedAlbumImagesDir.path}/$fileName';
              await sourceImage.copy(stagedImagePath);
              stagedAlbum['imagePath'] = 'album_images/$fileName';
            } else {
              debugPrint(
                '[Backup] 앨범 이미지 해석 실패: '
                'albumId=${album.id}, path=$imagePath',
              );
              stagedAlbum['imagePath'] = null;
            }
          } else {
            stagedAlbum['imagePath'] = null;
          }

          stagedAlbums.add(stagedAlbum);
        } catch (e) {
          skippedAlbums++;
          debugPrint('[Backup] 앨범 항목 건너뜀: $e');
        }
      }

      // 파일은 정상인데 전부 파싱 실패면 데이터를 건드리지 않고 실패 처리한다
      if (albumsJsonRaw.isNotEmpty && stagedAlbums.isEmpty) {
        throw Exception('앨범 데이터를 해석할 수 없습니다.');
      }

      var skippedArtists = 0;
      final stagedArtists = <Map<String, dynamic>>[];
      if (artistsJsonRaw != null) {
        for (final artistData in artistsJsonRaw) {
          try {
            final artistMap = parseBackupJsonMap(artistData, 'artist');
            final artist = Artist.fromMap(normalizeBackupArtistMap(artistMap));
            final stagedArtist = artist.toMap();
            final imagePath = artist.imagePath?.trim();

            if (imagePath != null && imagePath.isNotEmpty) {
              final sourceImage = resolveBackupImageFile(
                backupRoot,
                imagePath,
                searchFolders: const ['artist_images', 'images'],
              );
              if (sourceImage != null) {
                final ext = path.extension(sourceImage.path);
                final fileName = 'artist_${artist.id}$ext';
                final stagedImagePath =
                    '${stagedArtistImagesDir.path}/$fileName';
                await sourceImage.copy(stagedImagePath);
                stagedArtist['imagePath'] = 'artist_images/$fileName';
              } else {
                debugPrint(
                  '[Backup] 아티스트 이미지 해석 실패: '
                  'artistId=${artist.id}, path=$imagePath',
                );
                stagedArtist['imagePath'] = null;
              }
            } else {
              stagedArtist['imagePath'] = null;
            }

            stagedArtists.add(stagedArtist);
          } catch (e) {
            skippedArtists++;
            debugPrint('[Backup] 아티스트 항목 건너뜀: $e');
          }
        }
      }

      lastBackupSkippedCount = skippedAlbums + skippedArtists;

      final albumImagesDir = Directory('${appDir.path}/album_images');
      if (await albumImagesDir.exists()) {
        await albumImagesDir.delete(recursive: true);
      }
      await albumImagesDir.create(recursive: true);

      final artistImagesDir = Directory('${appDir.path}/artist_images');
      if (await artistImagesDir.exists()) {
        await artistImagesDir.delete(recursive: true);
      }
      await artistImagesDir.create(recursive: true);

      // 이미지 디렉터리가 통째로 바뀌므로 경로 캐시를 전부 버린다
      clearFileExistsCache();

      await box.clear();
      await artistBox.clear();

      final currentStageDir = stageDir;
      for (final album in stagedAlbums) {
        final stagedImagePath = album['imagePath'] as String?;
        if (stagedImagePath != null) {
          final stagedFile = File(
            path.join(currentStageDir.path, stagedImagePath),
          );
          if (await stagedFile.exists()) {
            final newImagePath = path.normalize(
              path.join(appDir.path, stagedImagePath),
            );
            await stagedFile.copy(newImagePath);
            album['imagePath'] = newImagePath;
          } else {
            album['imagePath'] = null;
          }
        }

        await box.add(album);
      }

      for (final artist in stagedArtists) {
        final stagedImagePath = artist['imagePath'] as String?;
        if (stagedImagePath != null) {
          final stagedFile = File(
            path.join(currentStageDir.path, stagedImagePath),
          );
          if (await stagedFile.exists()) {
            final newImagePath = path.normalize(
              path.join(appDir.path, stagedImagePath),
            );
            await stagedFile.copy(newImagePath);
            artist['imagePath'] = newImagePath;
          } else {
            artist['imagePath'] = null;
          }
        }

        await artistBox.add(artist);
      }

      return true;
    } catch (e) {
      debugPrint('Backup restore failed: $e');
      _lastBackupRestoreError = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : '복원 중 오류가 발생했습니다.';
      return false;
    } finally {
      if (stageDir != null) {
        try {
          if (await stageDir.exists()) {
            await stageDir.delete(recursive: true);
          }
        } catch (_) {}
      }
      if (extractDir != null) {
        try {
          if (await extractDir.exists()) {
            await extractDir.delete(recursive: true);
          }
        } catch (_) {}
      }
    }
  }

  //endregion
}
