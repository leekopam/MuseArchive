import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/models/artist.dart';
import 'package:my_album_app/services/discogs_service.dart';
import 'package:my_album_app/services/i_album_repository.dart';
import 'package:my_album_app/services/musicbrainz_service.dart';
import 'package:my_album_app/services/spotify_service.dart';
import 'package:my_album_app/services/vocadb_service.dart';
import 'package:my_album_app/viewmodels/album_form_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Discogs 설정/오류 상태', () {
    test('제목 검색에서 토큰 누락을 빈 검색 결과와 구분한다', () async {
      final viewModel = _buildViewModel(
        DiscogsService.forTesting(
          tokenProvider: () async => null,
          get: _unexpectedDiscogsGet,
        ),
      );
      viewModel.initialize(null, false);

      final results = await viewModel.searchByTitleArtist(
        artist: 'wowaka',
        title: 'Unhappy Refrain',
      );

      expect(results, isEmpty);
      expect(viewModel.errorMessage, contains('Discogs API 토큰'));
      expect(viewModel.errorMessage, isNot('검색 결과가 없습니다.'));
    });

    test('바코드 검색에서 토큰 누락을 앨범 없음 상태와 구분한다', () async {
      final viewModel = _buildViewModel(
        DiscogsService.forTesting(
          tokenProvider: () async => null,
          get: _unexpectedDiscogsGet,
        ),
      );
      viewModel.initialize(null, false);

      await viewModel.searchByBarcode('8801234567890');

      expect(viewModel.errorMessage, contains('Discogs API 토큰'));
      expect(viewModel.errorMessage, isNot('앨범을 찾을 수 없습니다.'));
    });

    test('Discogs 요청 한도 응답을 빈 검색 결과와 구분한다', () async {
      final viewModel = _buildViewModel(
        DiscogsService.forTesting(
          tokenProvider: () async => 'token',
          get: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response('{"message":"rate limit exceeded"}', 429);
          },
        ),
      );
      viewModel.initialize(null, false);

      final results = await viewModel.searchByTitleArtist(
        title: 'World 0123456789',
      );

      expect(results, isEmpty);
      expect(viewModel.errorMessage, contains('요청 한도'));
      expect(viewModel.errorMessage, isNot('검색 결과가 없습니다.'));
    });
  });

  group('Discogs 이미지 다운로드', () {
    test('HTTP 200 invalid bytes는 캐시 성공 경로를 만들지 않는다', () async {
      final originalPathProvider = PathProviderPlatform.instance;
      final sandbox = await Directory.systemTemp.createTemp(
        'musearchive_discogs_invalid_image_test_',
      );
      addTearDown(() async {
        PathProviderPlatform.instance = originalPathProvider;
        if (await sandbox.exists()) {
          await sandbox.delete(recursive: true);
        }
      });
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        temporaryPath: sandbox.path,
      );
      final service = DiscogsService.forTesting(
        tokenProvider: () async => 'token',
        get: _unexpectedDiscogsGet,
        imageGet: (Uri uri, {Map<String, String>? headers}) async {
          return http.Response.bytes(<int>[1, 2, 3], 200);
        },
      );

      final savedPath = await service.downloadAndSaveImage(
        'https://example.com/cover.png',
        'invalid_bytes',
      );

      expect(savedPath, isNull);
      expect(await sandbox.list().toList(), isEmpty);
    });

    test('HTTP 200 valid PNG bytes는 쿼리를 제거한 확장자로 캐시한다', () async {
      final originalPathProvider = PathProviderPlatform.instance;
      final sandbox = await Directory.systemTemp.createTemp(
        'musearchive_discogs_valid_image_test_',
      );
      addTearDown(() async {
        PathProviderPlatform.instance = originalPathProvider;
        if (await sandbox.exists()) {
          await sandbox.delete(recursive: true);
        }
      });
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        temporaryPath: sandbox.path,
      );
      final service = DiscogsService.forTesting(
        tokenProvider: () async => 'token',
        get: _unexpectedDiscogsGet,
        imageGet: (Uri uri, {Map<String, String>? headers}) async {
          return http.Response.bytes(_validPngImageBytes, 200);
        },
      );

      final savedPath = await service.downloadAndSaveImage(
        'https://example.com/cover.png?size=large',
        'valid_png',
      );

      expect(savedPath, isNotNull);
      expect(savedPath, startsWith(sandbox.path));
      expect(savedPath, endsWith('.png'));
      expect(await File(savedPath!).readAsBytes(), _validPngImageBytes);
    });

    test('이미지 HTTP non-200은 캐시 파일을 만들지 않고 null을 반환한다', () async {
      final originalPathProvider = PathProviderPlatform.instance;
      final sandbox = await Directory.systemTemp.createTemp(
        'musearchive_discogs_non_200_image_test_',
      );
      addTearDown(() async {
        PathProviderPlatform.instance = originalPathProvider;
        if (await sandbox.exists()) {
          await sandbox.delete(recursive: true);
        }
      });
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        temporaryPath: sandbox.path,
      );
      final service = DiscogsService.forTesting(
        tokenProvider: () async => 'token',
        get: _unexpectedDiscogsGet,
        imageGet: (Uri uri, {Map<String, String>? headers}) async {
          return http.Response('not found', 404);
        },
      );

      final savedPath = await service.downloadAndSaveImage(
        'https://example.com/missing-cover.png',
        'missing_cover',
      );

      expect(savedPath, isNull);
      expect(await sandbox.list().toList(), isEmpty);
    });

    test('Discogs 상세 응답에 이미지가 없으면 커버 없이 앨범을 반환한다', () async {
      var imageRequested = false;
      final service = DiscogsService.forTesting(
        tokenProvider: () async => 'token',
        get: (Uri uri, {Map<String, String>? headers}) async {
          expect(uri.path, '/releases/77');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(<String, Object?>{
                'title': 'No Cover Album',
                'artists': <Object?>[
                  <String, Object?>{'name': 'No Cover Artist'},
                ],
                'released': '2011-05-18',
                'formats': <Object?>[],
                'tracklist': <Object?>[],
                'labels': <Object?>[],
                'genres': <Object?>[],
                'styles': <Object?>[],
                'notes': '',
              }),
            ),
            200,
          );
        },
        imageGet: (Uri uri, {Map<String, String>? headers}) async {
          imageRequested = true;
          return http.Response('unexpected image request', 500);
        },
      );

      final album = await service.fetchAlbumById(77);

      expect(album, isNotNull);
      expect(album?.title, 'No Cover Album');
      expect(album?.imagePath, isNull);
      expect(imageRequested, isFalse);
    });
  });
}

AlbumFormViewModel _buildViewModel(DiscogsService discogsService) {
  return AlbumFormViewModel(
    _FakeAlbumRepository(),
    discogsService,
    SpotifyService(),
    VocadbService(),
    MusicBrainzService(),
  );
}

Future<http.Response> _unexpectedDiscogsGet(
  Uri uri, {
  Map<String, String>? headers,
}) async {
  fail('토큰이 없을 때는 Discogs HTTP 요청을 보내면 안 됩니다: $uri');
}

final List<int> _validPngImageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
);

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform({required this.temporaryPath});

  final String temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}

class _FakeAlbumRepository implements IAlbumRepository {
  final ValueNotifier<Object?> _listenable = ValueNotifier<Object?>(null);

  @override
  ValueListenable get listenable => _listenable;

  @override
  Future<void> init() async {}

  @override
  Future<List<Album>> getAll() async => <Album>[];

  @override
  Future<void> add(Album album) async {}

  @override
  Future<void> update(String albumId, Album album) async {}

  @override
  Future<void> delete(String albumId) async {}

  @override
  Future<void> reorder(int oldIndex, int newIndex) async {}

  @override
  List<String> getAllFormats() => <String>[];

  @override
  List<String> getAllGenres() => <String>[];

  @override
  List<String> getAllStyles() => <String>[];

  @override
  List<String> getAllLabels() => <String>[];

  @override
  List<String> getSmartArtistSuggestions(String query) => <String>[];

  @override
  List<Artist> getAllArtists() => <Artist>[];

  @override
  List<Album> getAlbumsByArtist(String artistName) => <Album>[];

  @override
  Artist? getArtistByName(String artistName) => null;

  @override
  Future<void> updateArtistImage(String artistName, String? imagePath) async {}

  @override
  Future<void> updateArtistMetadata(
    String artistName,
    List<String> aliases,
    List<String> groups,
  ) async {}

  @override
  List<String> getArtistNamesMatching(String query) => <String>[];

  @override
  Future<String?> exportBackup() async => null;

  @override
  Future<bool> shareBackup() async => false;

  @override
  Future<bool> saveBackupToDevice() async => false;

  @override
  Future<bool> importBackup() async => false;
}
