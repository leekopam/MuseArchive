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

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VocaDB 오류/빈 상태', () {
    test('검색 200 empty 응답은 오류 없이 빈 결과로 유지한다', () async {
      final viewModel = _buildViewModel(
        VocadbService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response('{"items":[]}', 200);
          },
        ),
      );
      viewModel.initialize(null, false);

      final results = await viewModel.searchVocadb('없는 앨범');

      expect(results, isEmpty);
      expect(viewModel.errorMessage, isNull);
    });

    test('검색 서버 오류를 빈 검색 결과와 구분한다', () async {
      final viewModel = _buildViewModel(
        VocadbService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response('{"message":"server error"}', 500);
          },
        ),
      );
      viewModel.initialize(null, false);

      final results = await viewModel.searchVocadb('wowaka');

      expect(results, isEmpty);
      expect(viewModel.errorMessage, contains('VocaDB 서버 오류'));
      expect(viewModel.errorMessage, isNot(contains('Exception')));
      expect(viewModel.errorMessage, isNot('VocaDB 검색 결과가 없습니다.'));
    });

    test('검색 응답 파싱 실패를 빈 검색 결과와 구분한다', () async {
      final viewModel = _buildViewModel(
        VocadbService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response('not-json', 200);
          },
        ),
      );
      viewModel.initialize(null, false);

      final results = await viewModel.searchVocadb('wowaka');

      expect(results, isEmpty);
      expect(viewModel.errorMessage, contains('VocaDB 검색 응답을 처리할 수 없습니다'));
      expect(viewModel.errorMessage, isNot(contains('FormatException')));
      expect(viewModel.errorMessage, isNot('VocaDB 검색 결과가 없습니다.'));
    });

    test('검색 네트워크 실패를 빈 검색 결과와 구분한다', () async {
      final viewModel = _buildViewModel(
        VocadbService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            throw const SocketException('offline');
          },
        ),
      );
      viewModel.initialize(null, false);

      final results = await viewModel.searchVocadb('wowaka');

      expect(results, isEmpty);
      expect(viewModel.errorMessage, contains('네트워크 상태를 확인한 뒤 다시 시도해주세요'));
      expect(viewModel.errorMessage, isNot(contains('SocketException')));
      expect(viewModel.errorMessage, isNot('VocaDB 검색 결과가 없습니다.'));
    });

    test('로드 404 not-found를 provider failure와 구분하고 현재 앨범을 유지한다', () async {
      final viewModel = _buildViewModel(
        VocadbService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response('<html>not found</html>', 404);
          },
        ),
      );
      viewModel.initialize(_existingAlbum(), false);

      await viewModel.loadVocadbAlbumById(999999999);

      expect(viewModel.errorMessage, contains('VocaDB에서 해당 앨범을 찾을 수 없습니다'));
      expect(viewModel.errorMessage, isNot(contains('서버 오류')));
      expect(viewModel.currentAlbum?.title, '기존 앨범');
      expect(viewModel.hasUnsavedChanges, isFalse);
    });

    test('로드 서버 오류를 not-found와 구분하고 현재 앨범을 유지한다', () async {
      final viewModel = _buildViewModel(
        VocadbService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response('{"message":"server error"}', 500);
          },
        ),
      );
      viewModel.initialize(_existingAlbum(), false);

      await viewModel.loadVocadbAlbumById(501);

      expect(viewModel.errorMessage, contains('VocaDB 서버 오류'));
      expect(viewModel.errorMessage, isNot(contains('찾을 수 없습니다')));
      expect(viewModel.currentAlbum?.title, '기존 앨범');
      expect(viewModel.hasUnsavedChanges, isFalse);
    });

    test('로드 응답 파싱 실패를 not-found와 구분하고 현재 앨범을 유지한다', () async {
      final viewModel = _buildViewModel(
        VocadbService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response('not-json', 200);
          },
        ),
      );
      viewModel.initialize(_existingAlbum(), false);

      await viewModel.loadVocadbAlbumById(501);

      expect(viewModel.errorMessage, contains('VocaDB 앨범 응답을 처리할 수 없습니다'));
      expect(viewModel.errorMessage, isNot(contains('FormatException')));
      expect(viewModel.errorMessage, isNot(contains('찾을 수 없습니다')));
      expect(viewModel.currentAlbum?.title, '기존 앨범');
      expect(viewModel.hasUnsavedChanges, isFalse);
    });

    test('로드 네트워크 실패를 not-found와 구분하고 현재 앨범을 유지한다', () async {
      final viewModel = _buildViewModel(
        VocadbService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            throw const SocketException('offline');
          },
        ),
      );
      viewModel.initialize(_existingAlbum(), false);

      await viewModel.loadVocadbAlbumById(501);

      expect(viewModel.errorMessage, contains('네트워크 상태를 확인한 뒤 다시 시도해주세요'));
      expect(viewModel.errorMessage, isNot(contains('SocketException')));
      expect(viewModel.errorMessage, isNot(contains('찾을 수 없습니다')));
      expect(viewModel.currentAlbum?.title, '기존 앨범');
      expect(viewModel.hasUnsavedChanges, isFalse);
    });

    test('로드 이미지 다운로드 실패는 메타데이터 성공과 부분 경고를 분리한다', () async {
      final viewModel = _buildViewModel(
        VocadbService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return _vocadbDetailResponse(
              imageUrl: 'https://example.com/cover.jpg',
            );
          },
          imageGet: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response('not found', 404);
          },
        ),
      );
      viewModel.initialize(_existingAlbum(), false);

      await viewModel.loadVocadbAlbumById(501);

      expect(viewModel.errorMessage, isNull);
      expect(
        viewModel.vocadbImageWarningMessage,
        contains('커버 이미지를 저장하지 못했습니다'),
      );
      expect(viewModel.currentAlbum?.title, 'VocaDB 로드 앨범');
      expect(viewModel.currentAlbum?.artists, <String>['wowaka']);
      expect(viewModel.currentAlbum?.imagePath, isNull);
      expect(viewModel.hasUnsavedChanges, isTrue);
    });

    test('로드 이미지 캐시 실패도 부분 경고로 처리하고 하드 오류로 만들지 않는다', () async {
      final originalPathProvider = PathProviderPlatform.instance;
      addTearDown(() {
        PathProviderPlatform.instance = originalPathProvider;
      });
      PathProviderPlatform.instance = FakePathProviderPlatform(
        throwOnTemporaryPath: true,
      );
      final viewModel = _buildViewModel(
        VocadbService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return _vocadbDetailResponse(
              imageUrl: 'https://example.com/cover.jpg',
            );
          },
          imageGet: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response.bytes(_validPngImageBytes, 200);
          },
        ),
      );
      viewModel.initialize(_existingAlbum(), false);

      await viewModel.loadVocadbAlbumById(502);

      expect(viewModel.errorMessage, isNull);
      expect(
        viewModel.vocadbImageWarningMessage,
        contains('커버 이미지를 저장하지 못했습니다'),
      );
      expect(viewModel.currentAlbum?.title, 'VocaDB 로드 앨범');
      expect(viewModel.currentAlbum?.imagePath, isNull);
      expect(viewModel.hasUnsavedChanges, isTrue);
    });

    test('로드 이미지 URL이 없는 앨범은 부분 경고 없이 메타데이터를 반영한다', () async {
      final viewModel = _buildViewModel(
        VocadbService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return _vocadbDetailResponse();
          },
          imageGet: (Uri uri, {Map<String, String>? headers}) async {
            throw StateError('이미지 요청이 호출되면 안 됩니다.');
          },
        ),
      );
      viewModel.initialize(_existingAlbum(), false);

      await viewModel.loadVocadbAlbumById(503);

      expect(viewModel.errorMessage, isNull);
      expect(viewModel.vocadbImageWarningMessage, isNull);
      expect(viewModel.currentAlbum?.title, 'VocaDB 로드 앨범');
      expect(viewModel.currentAlbum?.imagePath, isNull);
      expect(viewModel.hasUnsavedChanges, isTrue);
    });

    test('로드 이미지 HTTP 200 invalid bytes는 캐시 성공이 아니라 부분 경고로 처리한다', () async {
      final originalPathProvider = PathProviderPlatform.instance;
      final sandbox = await Directory.systemTemp.createTemp(
        'musearchive_vocadb_invalid_image_test_',
      );
      addTearDown(() async {
        PathProviderPlatform.instance = originalPathProvider;
        if (await sandbox.exists()) {
          await sandbox.delete(recursive: true);
        }
      });
      PathProviderPlatform.instance = FakePathProviderPlatform(
        temporaryPath: sandbox.path,
      );
      final viewModel = _buildViewModel(
        VocadbService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return _vocadbDetailResponse(
              imageUrl: 'https://example.com/cover.png?size=large',
            );
          },
          imageGet: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response.bytes(<int>[1, 2, 3], 200);
          },
        ),
      );
      viewModel.initialize(_existingAlbum(), false);

      await viewModel.loadVocadbAlbumById(504);

      expect(viewModel.errorMessage, isNull);
      expect(
        viewModel.vocadbImageWarningMessage,
        contains('커버 이미지를 저장하지 못했습니다'),
      );
      expect(viewModel.currentAlbum?.title, 'VocaDB 로드 앨범');
      expect(viewModel.currentAlbum?.imagePath, isNull);
      expect(viewModel.hasUnsavedChanges, isTrue);
    });

    test('로드 이미지 다운로드 성공은 경고 없이 로컬 캐시 경로를 반영한다', () async {
      final originalPathProvider = PathProviderPlatform.instance;
      final sandbox = await Directory.systemTemp.createTemp(
        'musearchive_vocadb_image_test_',
      );
      addTearDown(() async {
        PathProviderPlatform.instance = originalPathProvider;
        if (await sandbox.exists()) {
          await sandbox.delete(recursive: true);
        }
      });
      PathProviderPlatform.instance = FakePathProviderPlatform(
        temporaryPath: sandbox.path,
      );
      final viewModel = _buildViewModel(
        VocadbService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return _vocadbDetailResponse(
              imageUrl: 'https://example.com/cover.png?size=large',
            );
          },
          imageGet: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response.bytes(_validPngImageBytes, 200);
          },
        ),
      );
      viewModel.initialize(_existingAlbum(), false);

      await viewModel.loadVocadbAlbumById(504);

      final imagePath = viewModel.currentAlbum?.imagePath;
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.vocadbImageWarningMessage, isNull);
      expect(imagePath, isNotNull);
      expect(imagePath, startsWith(sandbox.path));
      expect(imagePath, endsWith('.png'));
      expect(await File(imagePath!).readAsBytes(), _validPngImageBytes);
      expect(viewModel.hasUnsavedChanges, isTrue);
    });
  });
}

String _vocadbDetailJson({String? imageUrl}) {
  return jsonEncode(<String, Object?>{
    'name': 'VocaDB 로드 앨범',
    'artistString': 'wowaka',
    if (imageUrl != null)
      'mainPicture': <String, String>{'urlOriginal': imageUrl},
    'discType': 'Album',
    'releaseDate': <String, int>{'year': 2011, 'month': 5, 'day': 18},
    'tracks': <Object?>[],
    'artists': <Object?>[],
    'tags': <Object?>[],
    'identifiers': <Object?>[],
  });
}

http.Response _vocadbDetailResponse({String? imageUrl}) {
  return http.Response.bytes(
    utf8.encode(_vocadbDetailJson(imageUrl: imageUrl)),
    200,
    headers: const <String, String>{
      'content-type': 'application/json; charset=utf-8',
    },
  );
}

final List<int> _validPngImageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
);

Album _existingAlbum() {
  return Album(
    id: 'existing-vocadb-album',
    title: '기존 앨범',
    artists: const <String>['기존 아티스트'],
  );
}

AlbumFormViewModel _buildViewModel(VocadbService vocadbService) {
  return AlbumFormViewModel(
    _FakeAlbumRepository(),
    DiscogsService(),
    SpotifyService(),
    vocadbService,
    MusicBrainzService(),
  );
}

class _FakeAlbumRepository implements IAlbumRepository {
  @override
  String? get lastBackupRestoreError => null;

  @override
  int get lastBackupSkippedCount => 0;

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
  Future<void> delete(String albumId, {bool preserveFiles = false}) async {}

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
