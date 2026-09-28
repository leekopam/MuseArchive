import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/models/artist.dart';
import 'package:my_album_app/services/i_album_repository.dart';

/// 테스트 공용 스텁 — 플랫폼 채널·파일시스템 의존을 경계에서 차단한다.

/// 인메모리 저장소. widget 테스트에서 실제 Hive IO를 제거해 fakeAsync와 충돌하지 않는다.
class FakeAlbumRepository implements IAlbumRepository {
  @override
  String? get lastBackupRestoreError => null;

  @override
  int get lastBackupSkippedCount => 0;

  FakeAlbumRepository({List<Album>? albums, List<Artist>? artists})
    : albums = List.of(albums ?? const []),
      _artists = {
        for (final artist in artists ?? const <Artist>[]) artist.name: artist,
      };

  final List<Album> albums;
  final Map<String, Artist> _artists;
  final ValueNotifier<int> _notifier = ValueNotifier<int>(0);

  /// 복원 실패 경로 테스트용 — add 호출 시 예외를 던진다.
  bool failOnAdd = false;

  @override
  Future<void> init() async {}

  @override
  ValueListenable<int> get listenable => _notifier;

  void _notify() => _notifier.value++;

  @override
  Future<List<Album>> getAll() async => List.of(albums);

  @override
  Future<void> add(Album album) async {
    if (failOnAdd) throw StateError('injected add failure');
    albums.add(album);
    _notify();
  }

  @override
  Future<void> update(String albumId, Album album) async {
    final index = albums.indexWhere((a) => a.id == albumId);
    if (index < 0) return;
    albums[index] = album;
    _notify();
  }

  @override
  Future<void> delete(String albumId, {bool preserveFiles = false}) async {
    albums.removeWhere((a) => a.id == albumId);
    _notify();
  }

  @override
  Future<void> reorder(int oldIndex, int newIndex) async {
    albums.insert(newIndex, albums.removeAt(oldIndex));
    _notify();
  }

  @override
  List<String> getAllFormats() =>
      albums.expand((a) => a.formats).toSet().toList();

  @override
  List<String> getAllGenres() =>
      albums.expand((a) => a.genres).toSet().toList();

  @override
  List<String> getAllStyles() =>
      albums.expand((a) => a.styles).toSet().toList();

  @override
  List<String> getAllLabels() =>
      albums.expand((a) => a.labels).toSet().toList();

  @override
  List<String> getSmartArtistSuggestions(String query) => const [];

  @override
  List<Artist> getAllArtists() => _artists.values.toList();

  @override
  List<Album> getAlbumsByArtist(String artistName) =>
      albums.where((a) => a.artists.contains(artistName)).toList();

  @override
  Artist? getArtistByName(String artistName) => _artists[artistName];

  // 실구현 계약: 아티스트 레코드가 없으면 조용히 아무 것도 하지 않는다.
  // artistBox 변경은 albumBox listenable을 발화시키지 않으므로 _notify도 호출하지 않는다.
  @override
  Future<void> updateArtistImage(String artistName, String? imagePath) async {
    final current = _artists[artistName];
    if (current == null) return;
    _artists[artistName] = Artist(
      id: current.id,
      name: artistName,
      imagePath: imagePath,
      albumIds: current.albumIds,
      aliases: current.aliases,
      groups: current.groups,
    );
  }

  @override
  Future<void> updateArtistMetadata(
    String artistName,
    List<String> aliases,
    List<String> groups,
  ) async {
    final current = _artists[artistName];
    if (current == null) return;
    _artists[artistName] = current.copyWith(aliases: aliases, groups: groups);
  }

  @override
  List<String> getArtistNamesMatching(String query) {
    if (query.isEmpty) return const [];
    final lowerQuery = query.toLowerCase();
    bool matches(String name, List<String> aliases) =>
        name.toLowerCase().contains(lowerQuery) ||
        aliases.any((a) => a.toLowerCase().contains(lowerQuery));
    return <String>{
      for (final artist in _artists.values)
        if (matches(artist.name, artist.aliases)) artist.name,
    }.toList();
  }

  @override
  Future<String?> exportBackup() async => null;

  @override
  Future<bool> shareBackup() async => false;

  @override
  Future<bool> saveBackupToDevice() async => false;

  @override
  Future<bool> importBackup() async => false;
}

/// path_provider 대체. 필요한 경로만 주입하면 된다.
class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform({
    this.temporaryPath,
    this.applicationDocumentsPath,
    this.throwOnTemporaryPath = false,
    this.throwOnApplicationDocumentsPath = false,
  });

  final String? temporaryPath;
  final String? applicationDocumentsPath;
  final bool throwOnTemporaryPath;
  final bool throwOnApplicationDocumentsPath;

  @override
  Future<String?> getTemporaryPath() async {
    if (throwOnTemporaryPath) throw Exception('temporary path lookup failed');
    return temporaryPath;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    if (throwOnApplicationDocumentsPath) {
      throw Exception('application documents lookup failed');
    }
    return applicationDocumentsPath;
  }
}

/// image_picker 대체. `result`가 null이면 사용자 취소와 동일하다.
class FakeImagePickerPlatform extends ImagePickerPlatform {
  FakeImagePickerPlatform({this.result});

  final XFile? result;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => result;
}

/// file_picker 대체. `result`가 null이면 사용자 취소와 동일하다.
class FakeFilePicker extends FilePicker {
  FakeFilePicker({this.result});

  final FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => result;
}
