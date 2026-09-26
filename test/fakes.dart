import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/models/artist.dart';
import 'package:my_album_app/services/i_album_repository.dart';

/// 테스트 공용 스텁 — 플랫폼 채널·파일시스템 의존을 경계에서 차단한다.

/// 인메모리 저장소. widget 테스트에서 실제 Hive IO를 제거해 fakeAsync와 충돌하지 않는다.
class FakeAlbumRepository implements IAlbumRepository {
  FakeAlbumRepository({List<Album>? albums, Map<String, List<String>>? aliases})
    : albums = List.of(albums ?? const []),
      _aliases = aliases ?? {};

  final List<Album> albums;
  final Map<String, List<String>> _aliases;
  final ValueNotifier<int> _notifier = ValueNotifier<int>(0);

  @override
  Future<void> init() async {}

  @override
  ValueListenable<int> get listenable => _notifier;

  void _notify() => _notifier.value++;

  @override
  Future<List<Album>> getAll() async => List.of(albums);

  @override
  Future<void> add(Album album) async {
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
  Future<void> delete(String albumId) async {
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
  List<Artist> getAllArtists() => const [];

  @override
  List<Album> getAlbumsByArtist(String artistName) =>
      albums.where((a) => a.artists.contains(artistName)).toList();

  @override
  Artist? getArtistByName(String artistName) => null;

  @override
  Future<void> updateArtistImage(
    String artistName,
    String? imagePath,
  ) async {}

  @override
  Future<void> updateArtistMetadata(
    String artistName,
    List<String> aliases,
    List<String> groups,
  ) async {
    _aliases[artistName] = aliases;
  }

  @override
  List<String> getArtistNamesMatching(String query) {
    final lowerQuery = query.toLowerCase();
    return _aliases.entries
        .where(
          (entry) =>
              entry.key.toLowerCase().contains(lowerQuery) ||
              entry.value.any((a) => a.toLowerCase().contains(lowerQuery)),
        )
        .map((entry) => entry.key)
        .toList();
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
