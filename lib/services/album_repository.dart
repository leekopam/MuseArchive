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
import 'i_album_repository.dart';

/// 앨범 저장소 구현 (Hive 기반)
class AlbumRepository implements IAlbumRepository {
  // region 싱글톤 패턴
  static final AlbumRepository _instance = AlbumRepository._internal();
  factory AlbumRepository() => _instance;
  AlbumRepository._internal();
  //endregion

  // endregion

  // region 상수
  static const String _boxName = 'albumBox';
  static const String _artistBoxName = 'artistBox';
  //endregion

  // endregion

  // region 초기화 및 리스너
  @override
  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
    await Hive.openBox(_artistBoxName);
  }

  Box get box => Hive.box(_boxName);
  Box get artistBox => Hive.box(_artistBoxName);

  @override
  ValueListenable get listenable => box.listenable();
  //endregion

  // endregion

  // region CRUD 작업
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
        debugPrint("이미지 저장 실패: $e");
      }
    }

    await box.add(album.toMap());
    await _updateArtistAlbums(album.artist, album.id, isAdding: true);
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
      debugPrint("업데이트할 앨범을 찾지 못했습니다: $albumId");
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
        debugPrint("이미지 업데이트 실패: $e");
      }
    }

    await box.put(keyToUpdate, albumToSave.toMap());

    if (oldAlbum.artist != albumToSave.artist) {
      await _updateArtistAlbums(oldAlbum.artist, albumId, isAdding: false);
      await _updateArtistAlbums(albumToSave.artist, albumId, isAdding: true);
    }
  }

  @override
  Future<void> delete(String albumId) async {
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
      debugPrint("삭제할 앨범을 찾지 못했습니다: $albumId");
      return;
    }

    final album = Album.fromMap(albumMap);
    if (album.imagePath != null) {
      try {
        final file = File(album.imagePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint("이미지 삭제 실패: $e");
      }
    }

    await box.delete(keyToDelete);
    await _updateArtistAlbums(album.artist, album.id, isAdding: false);
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

  // region 아티스트 관리
  Future<void> _updateArtistAlbums(
    String artistName,
    String albumId, {
    required bool isAdding,
  }) async {
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
      debugPrint("아티스트 업데이트 실패: $e");
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
        .where((album) => album.artist == artistName)
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
      debugPrint("아티스트 조회 실패: $e");
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
        // 기존 이미지 삭제 (새 이미지가 다르거나 null인 경우)
        if (existingArtist.imagePath != null &&
            existingArtist.imagePath != imagePath) {
          final oldFile = File(existingArtist.imagePath!);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        }

        String? newPath = imagePath;

        // 새 이미지 저장
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
        // 아티스트가 없는 경우 생성 (앨범은 없음)
        // 일반적으로 이 메서드는 이미 존재하는 아티스트에 대해 호출됨
      }
    } catch (e) {
      debugPrint("아티스트 이미지 업데이트 실패: $e");
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
      debugPrint("아티스트 메타데이터 업데이트 실패: $e");
    }
  }

  @override
  List<String> getArtistNamesMatching(String query) {
    if (query.isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    final matchingNames = <String>{};

    for (var value in artistBox.values) {
      final artist = Artist.fromMap(value);
      // 1. 이름 매칭
      if (artist.name.toLowerCase().contains(lowerQuery)) {
        matchingNames.add(artist.name);
        continue; // 이미 추가했으므로 다음 아티스트로
      }

      // 2. 별명 매칭
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

  // region 쿼리 메서드
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
        .map((e) => Album.fromMap(e).artist)
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

  // region 백업 및 복원
  @override
  Future<String?> exportBackup() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final backupDir = Directory(
        '${tempDir.path}/backup_${DateTime.now().millisecondsSinceEpoch}',
      );
      await backupDir.create();

      final albums = box.values.map((e) => Album.fromMap(e)).toList();
      final albumsJson = albums.map((album) => album.toMap()).toList();
      final albumsFile = File('${backupDir.path}/albums.json');
      await albumsFile.writeAsString(jsonEncode(albumsJson));

      final artists = artistBox.values.map((e) => Artist.fromMap(e)).toList();
      final artistsJson = artists.map((artist) => artist.toMap()).toList();
      final artistsFile = File('${backupDir.path}/artists.json');
      await artistsFile.writeAsString(jsonEncode(artistsJson));

      final imagesDir = Directory('${backupDir.path}/images');
      await imagesDir.create();

      for (var album in albums) {
        if (album.imagePath != null && File(album.imagePath!).existsSync()) {
          final imageFile = File(album.imagePath!);
          final fileName = path.basename(album.imagePath!);
          await imageFile.copy('${imagesDir.path}/$fileName');
        }
      }

      final zipFile =
          '${tempDir.path}/muse_archive_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
      final encoder = ZipFileEncoder();
      encoder.create(zipFile);

      if (await albumsFile.exists()) {
        await encoder.addFile(albumsFile);
      }
      if (await artistsFile.exists()) {
        await encoder.addFile(artistsFile);
      }

      if (await imagesDir.exists()) {
        final images = await imagesDir.list().toList();
        for (var img in images) {
          if (img is File) {
            final fileName = path.basename(img.path);
            await encoder.addFile(img, 'images/$fileName');
          }
        }
      }

      encoder.close();

      final file = File(zipFile);
      final size = await file.length();
      if (size <= 22) {
        throw Exception('백업 파일 생성 실패 (용량 과소: ${size}B)');
      }

      await backupDir.delete(recursive: true);

      return zipFile;
    } catch (e) {
      debugPrint('백업 생성 실패: $e');
      return null;
    }
  }

  @override
  Future<bool> shareBackup() async {
    try {
      final backupPath = await exportBackup();
      if (backupPath == null) return false;

      await SharePlus.instance.share(
        ShareParams(files: [XFile(backupPath)], subject: 'MuseArchive 백업'),
      );

      return true;
    } catch (e) {
      debugPrint('백업 공유 실패: $e');
      return false;
    }
  }

  @override
  Future<bool> saveBackupToDevice() async {
    try {
      final backupPath = await exportBackup();
      if (backupPath == null) return false;

      final fileName = path.basename(backupPath);
      final savedPath = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          sourceFilePath: backupPath,
          fileName: fileName,
        ),
      );

      return savedPath != null;
    } catch (e) {
      debugPrint('백업 저장 실패: $e');
      return false;
    }
  }

  @override
  Future<bool> importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.isEmpty) return false;

      final zipPath = result.files.first.path;
      if (zipPath == null) return false;

      final tempDir = await getTemporaryDirectory();
      final extractDir = Directory(
        '${tempDir.path}/restore_${DateTime.now().millisecondsSinceEpoch}',
      );
      await extractDir.create();

      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      extractArchiveToDisk(archive, extractDir.path);

      final albumsFile = File('${extractDir.path}/albums.json');
      if (!await albumsFile.exists()) {
        throw Exception('백업 파일이 손상되었습니다.');
      }

      final albumsJson = jsonDecode(await albumsFile.readAsString()) as List;
      final artistsFile = File('${extractDir.path}/artists.json');

      await box.clear();
      await artistBox.clear();

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/album_images');
      if (await imagesDir.exists()) {
        await imagesDir.delete(recursive: true);
      }
      await imagesDir.create();

      for (var albumData in albumsJson) {
        final album = Album.fromMap(albumData);

        if (album.imagePath != null) {
          final imageName = path.basename(album.imagePath!);
          final restoredImagePath = '${extractDir.path}/images/$imageName';

          if (File(restoredImagePath).existsSync()) {
            final newImagePath = '${imagesDir.path}/$imageName';
            await File(restoredImagePath).copy(newImagePath);
            await box.add(album.copyWith(imagePath: newImagePath).toMap());
          } else {
            await box.add(album.copyWith(imagePath: null).toMap());
          }
        } else {
          await box.add(album.toMap());
        }
      }

      if (await artistsFile.exists()) {
        final artistsJson =
            jsonDecode(await artistsFile.readAsString()) as List;
        for (var artistData in artistsJson) {
          final artist = Artist.fromMap(artistData);
          await artistBox.add(artist.toMap());
        }
      }

      await extractDir.delete(recursive: true);

      return true;
    } catch (e) {
      debugPrint('백업 복원 실패: $e');
      return false;
    }
  }

  //endregion
}
