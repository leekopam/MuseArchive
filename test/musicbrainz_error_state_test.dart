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

  group('MusicBrainz 오류/빈 상태', () {
    test('검색 200 empty 응답은 오류 없이 빈 결과로 유지한다', () async {
      final viewModel = _buildViewModel(
        MusicBrainzService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response('{"releases":[]}', 200);
          },
        ),
      );
      viewModel.initialize(null, false);

      final results = await viewModel.searchMusicBrainz('없는 앨범');

      expect(results, isEmpty);
      expect(viewModel.errorMessage, isNull);
    });

    test('검색 요청 한도 초과를 빈 검색 결과와 구분한다', () async {
      final viewModel = _buildViewModel(
        MusicBrainzService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response('{"error":"rate limit"}', 429);
          },
        ),
      );
      viewModel.initialize(null, false);

      final results = await viewModel.searchMusicBrainz('wowaka');

      expect(results, isEmpty);
      expect(viewModel.errorMessage, contains('MusicBrainz 요청 한도를 초과했습니다'));
      expect(viewModel.errorMessage, isNot(contains('rate limit')));
      expect(viewModel.errorMessage, isNot('MusicBrainz 검색 결과가 없습니다.'));
    });

    test('검색 서버 오류를 빈 검색 결과와 구분한다', () async {
      final viewModel = _buildViewModel(
        MusicBrainzService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response('{"message":"server error"}', 500);
          },
        ),
      );
      viewModel.initialize(null, false);

      final results = await viewModel.searchMusicBrainz('wowaka');

      expect(results, isEmpty);
      expect(viewModel.errorMessage, contains('MusicBrainz 서버 오류'));
      expect(viewModel.errorMessage, isNot(contains('server error')));
      expect(viewModel.errorMessage, isNot('MusicBrainz 검색 결과가 없습니다.'));
    });

    test('검색 네트워크 실패를 빈 검색 결과와 구분한다', () async {
      final viewModel = _buildViewModel(
        MusicBrainzService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            throw const SocketException('offline');
          },
        ),
      );
      viewModel.initialize(null, false);

      final results = await viewModel.searchMusicBrainz('wowaka');

      expect(results, isEmpty);
      expect(viewModel.errorMessage, contains('네트워크 상태를 확인한 뒤 다시 시도해주세요'));
      expect(viewModel.errorMessage, isNot(contains('SocketException')));
      expect(viewModel.errorMessage, isNot('MusicBrainz 검색 결과가 없습니다.'));
    });

    test('검색 응답 파싱 실패를 빈 검색 결과와 구분한다', () async {
      final viewModel = _buildViewModel(
        MusicBrainzService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response('not-json', 200);
          },
        ),
      );
      viewModel.initialize(null, false);

      final results = await viewModel.searchMusicBrainz('wowaka');

      expect(results, isEmpty);
      expect(viewModel.errorMessage, contains('MusicBrainz 검색 응답을 처리할 수 없습니다'));
      expect(viewModel.errorMessage, isNot(contains('FormatException')));
      expect(viewModel.errorMessage, isNot('MusicBrainz 검색 결과가 없습니다.'));
    });

    test('검색 releases 누락 응답을 빈 검색 결과와 구분한다', () async {
      final viewModel = _buildViewModel(
        MusicBrainzService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response('{"count":0}', 200);
          },
        ),
      );
      viewModel.initialize(null, false);

      final results = await viewModel.searchMusicBrainz('wowaka');

      expect(results, isEmpty);
      expect(viewModel.errorMessage, contains('MusicBrainz 검색 응답을 처리할 수 없습니다'));
      expect(viewModel.errorMessage, isNot('MusicBrainz 검색 결과가 없습니다.'));
    });

    test('로드 404 not-found를 provider failure와 구분하고 현재 앨범을 유지한다', () async {
      final viewModel = _buildViewModel(
        MusicBrainzService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response('<html>not found</html>', 404);
          },
        ),
      );
      viewModel.initialize(_existingAlbum(), false);

      await viewModel.loadMusicBrainzAlbumById('missing-mbid');

      expect(
        viewModel.errorMessage,
        contains('MusicBrainz에서 해당 앨범을 찾을 수 없습니다'),
      );
      expect(viewModel.errorMessage, isNot(contains('서버 오류')));
      expect(viewModel.currentAlbum?.title, '기존 앨범');
      expect(viewModel.hasUnsavedChanges, isFalse);
    });

    test('로드 서버 오류를 not-found와 구분하고 현재 앨범을 유지한다', () async {
      final viewModel = _buildViewModel(
        MusicBrainzService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response('{"message":"server error"}', 500);
          },
        ),
      );
      viewModel.initialize(_existingAlbum(), false);

      await viewModel.loadMusicBrainzAlbumById('server-error-mbid');

      expect(viewModel.errorMessage, contains('MusicBrainz 서버 오류'));
      expect(viewModel.errorMessage, isNot(contains('server error')));
      expect(viewModel.errorMessage, isNot(contains('찾을 수 없습니다')));
      expect(viewModel.currentAlbum?.title, '기존 앨범');
      expect(viewModel.hasUnsavedChanges, isFalse);
    });

    test('로드 요청 한도 초과를 not-found와 구분하고 현재 앨범을 유지한다', () async {
      final viewModel = _buildViewModel(
        MusicBrainzService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response('{"error":"rate limit"}', 429);
          },
        ),
      );
      viewModel.initialize(_existingAlbum(), false);

      await viewModel.loadMusicBrainzAlbumById('rate-limit-mbid');

      expect(viewModel.errorMessage, contains('MusicBrainz 요청 한도를 초과했습니다'));
      expect(viewModel.errorMessage, isNot(contains('rate limit')));
      expect(viewModel.errorMessage, isNot(contains('찾을 수 없습니다')));
      expect(viewModel.currentAlbum?.title, '기존 앨범');
      expect(viewModel.hasUnsavedChanges, isFalse);
    });

    test('로드 네트워크 실패를 not-found와 구분하고 현재 앨범을 유지한다', () async {
      final viewModel = _buildViewModel(
        MusicBrainzService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            throw const SocketException('offline');
          },
        ),
      );
      viewModel.initialize(_existingAlbum(), false);

      await viewModel.loadMusicBrainzAlbumById('network-mbid');

      expect(viewModel.errorMessage, contains('네트워크 상태를 확인한 뒤 다시 시도해주세요'));
      expect(viewModel.errorMessage, isNot(contains('SocketException')));
      expect(viewModel.errorMessage, isNot(contains('찾을 수 없습니다')));
      expect(viewModel.currentAlbum?.title, '기존 앨범');
      expect(viewModel.hasUnsavedChanges, isFalse);
    });

    test('로드 응답 파싱 실패를 not-found와 구분하고 현재 앨범을 유지한다', () async {
      final viewModel = _buildViewModel(
        MusicBrainzService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            if (uri.host == 'coverartarchive.org') {
              return http.Response('', 404);
            }
            return http.Response('not-json', 200);
          },
        ),
      );
      viewModel.initialize(_existingAlbum(), false);

      await viewModel.loadMusicBrainzAlbumById('parsing-mbid');

      expect(viewModel.errorMessage, contains('MusicBrainz 앨범 응답을 처리할 수 없습니다'));
      expect(viewModel.errorMessage, isNot(contains('FormatException')));
      expect(viewModel.errorMessage, isNot(contains('찾을 수 없습니다')));
      expect(viewModel.currentAlbum?.title, '기존 앨범');
      expect(viewModel.hasUnsavedChanges, isFalse);
    });

    test('HTTP 200 invalid bytes는 커버 캐시 성공 경로를 만들지 않는다', () async {
      final originalPathProvider = PathProviderPlatform.instance;
      final sandbox = await Directory.systemTemp.createTemp(
        'musearchive_musicbrainz_invalid_image_test_',
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
      final service = MusicBrainzService.forTesting(
        get: (Uri uri, {Map<String, String>? headers}) async {
          expect(uri.host, 'coverartarchive.org');
          return http.Response.bytes(<int>[1, 2, 3], 200);
        },
      );

      final savedPath = await service.downloadAndSaveImage('invalid-mbid');

      expect(savedPath, isNull);
      expect(await sandbox.list().toList(), isEmpty);
    });

    test('HTTP 200 valid PNG bytes는 MusicBrainz 고정 파일명으로 캐시한다', () async {
      final originalPathProvider = PathProviderPlatform.instance;
      final sandbox = await Directory.systemTemp.createTemp(
        'musearchive_musicbrainz_valid_image_test_',
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
      final service = MusicBrainzService.forTesting(
        get: (Uri uri, {Map<String, String>? headers}) async {
          expect(uri.host, 'coverartarchive.org');
          return http.Response.bytes(_validPngImageBytes, 200);
        },
      );

      final savedPath = await service.downloadAndSaveImage('valid-mbid');

      expect(savedPath, isNotNull);
      expect(savedPath, startsWith(sandbox.path));
      expect(savedPath, endsWith('musicbrainz_valid-mbid.jpg'));
      expect(await File(savedPath!).readAsBytes(), _validPngImageBytes);
    });

    test('로드 커버 invalid bytes는 메타데이터만 반영하고 깨진 경로를 남기지 않는다', () async {
      final originalPathProvider = PathProviderPlatform.instance;
      final sandbox = await Directory.systemTemp.createTemp(
        'musearchive_musicbrainz_load_invalid_image_test_',
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
        MusicBrainzService.forTesting(
          get: (Uri uri, {Map<String, String>? headers}) async {
            if (uri.host == 'coverartarchive.org') {
              return http.Response.bytes(<int>[1, 2, 3], 200);
            }
            return _musicBrainzReleaseResponse();
          },
        ),
      );
      viewModel.initialize(_existingAlbum(), false);

      await viewModel.loadMusicBrainzAlbumById('invalid-cover-mbid');

      expect(viewModel.errorMessage, isNull);
      expect(viewModel.currentAlbum?.title, 'MusicBrainz 로드 앨범');
      expect(viewModel.currentAlbum?.artists, <String>['wowaka']);
      expect(viewModel.currentAlbum?.imagePath, isNull);
      expect(await sandbox.list().toList(), isEmpty);
      expect(viewModel.hasUnsavedChanges, isTrue);
    });
  });
}

http.Response _musicBrainzReleaseResponse() {
  return http.Response.bytes(
    utf8.encode(
      jsonEncode(<String, Object?>{
        'title': 'MusicBrainz 로드 앨범',
        'artist-credit': <Object?>[
          <String, Object?>{'name': 'wowaka'},
        ],
        'date': '2011-05-18',
        'label-info': <Object?>[],
        'media': <Object?>[
          <String, Object?>{'format': 'CD', 'tracks': <Object?>[]},
        ],
      }),
    ),
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
    id: 'existing-musicbrainz-album',
    title: '기존 앨범',
    artists: const <String>['기존 아티스트'],
  );
}

AlbumFormViewModel _buildViewModel(MusicBrainzService musicBrainzService) {
  return AlbumFormViewModel(
    _FakeAlbumRepository(),
    DiscogsService(),
    SpotifyService(),
    VocadbService(),
    musicBrainzService,
  );
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
