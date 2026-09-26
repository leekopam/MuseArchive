import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

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

  group('Spotify 오류/빈 상태', () {
    test('검색 200 empty 응답은 오류 없이 빈 결과로 유지한다', () async {
      final viewModel = _buildViewModel(
        SpotifyService.forTesting(
          credentialProvider: () async => const SpotifyCredentials(
            clientId: 'client-id',
            clientSecret: 'client-secret',
          ),
          post: (uri, {headers, body, encoding}) async {
            return http.Response(
              '{"access_token":"token","expires_in":3600}',
              200,
            );
          },
          get: (uri, {headers}) async {
            return http.Response('{"albums":{"items":[]}}', 200);
          },
        ),
      );
      viewModel.initialize(null, false);

      final results = await viewModel.searchSpotifyForConnect('없는 앨범');

      expect(results, isEmpty);
      expect(viewModel.errorMessage, isNull);
    });

    test('누락된 Spotify 키를 빈 검색 결과와 구분하고 네트워크를 호출하지 않는다', () async {
      var authCalled = false;
      var searchCalled = false;
      final viewModel = _buildViewModel(
        SpotifyService.forTesting(
          credentialProvider: () async => null,
          post: (uri, {headers, body, encoding}) async {
            authCalled = true;
            return http.Response('{}', 500);
          },
          get: (uri, {headers}) async {
            searchCalled = true;
            return http.Response('{}', 500);
          },
        ),
      );
      viewModel.initialize(null, false);

      final results = await viewModel.searchSpotifyForConnect('wowaka');

      expect(results, isEmpty);
      expect(viewModel.errorMessage, contains('Spotify 키가 설정되지 않았습니다'));
      expect(viewModel.errorMessage, isNot('검색 결과가 없습니다.'));
      expect(authCalled, isFalse);
      expect(searchCalled, isFalse);
    });

    for (final statusCode in <int>[401, 403]) {
      test('인증 $statusCode 응답을 빈 검색 결과와 구분한다', () async {
        var searchCalled = false;
        final viewModel = _buildViewModel(
          SpotifyService.forTesting(
            credentialProvider: () async => const SpotifyCredentials(
              clientId: 'client-id',
              clientSecret: 'client-secret',
            ),
            post: (uri, {headers, body, encoding}) async {
              return http.Response('{"error":"invalid_client"}', statusCode);
            },
            get: (uri, {headers}) async {
              searchCalled = true;
              return http.Response('{}', 200);
            },
          ),
        );
        viewModel.initialize(null, false);

        final results = await viewModel.searchSpotifyForConnect('wowaka');

        expect(results, isEmpty);
        expect(viewModel.errorMessage, contains('Spotify 인증에 실패했습니다'));
        expect(viewModel.errorMessage, isNot(contains('invalid_client')));
        expect(searchCalled, isFalse);
      });
    }

    test('인증 응답 파싱 실패를 빈 검색 결과와 구분한다', () async {
      final viewModel = _buildViewModel(
        SpotifyService.forTesting(
          credentialProvider: () async => const SpotifyCredentials(
            clientId: 'client-id',
            clientSecret: 'client-secret',
          ),
          post: (uri, {headers, body, encoding}) async {
            return http.Response('not-json', 200);
          },
          get: (uri, {headers}) async {
            return http.Response('{"albums":{"items":[]}}', 200);
          },
        ),
      );
      viewModel.initialize(null, false);

      final results = await viewModel.searchSpotifyForConnect('wowaka');

      expect(results, isEmpty);
      expect(viewModel.errorMessage, contains('Spotify 인증 응답을 처리할 수 없습니다'));
      expect(viewModel.errorMessage, isNot(contains('FormatException')));
    });

    for (final entry in <int, String>{
      401: 'Spotify 인증에 실패했습니다',
      403: 'Spotify 인증에 실패했습니다',
      429: 'Spotify 요청 한도를 초과했습니다',
      500: 'Spotify 서버 오류가 발생했습니다',
    }.entries) {
      test('검색 ${entry.key} 응답을 빈 검색 결과와 구분한다', () async {
        final viewModel = _buildViewModel(
          SpotifyService.forTesting(
            credentialProvider: () async => const SpotifyCredentials(
              clientId: 'client-id',
              clientSecret: 'client-secret',
            ),
            post: (uri, {headers, body, encoding}) async {
              return http.Response(
                '{"access_token":"token","expires_in":3600}',
                200,
              );
            },
            get: (uri, {headers}) async {
              return http.Response('{"message":"provider failure"}', entry.key);
            },
          ),
        );
        viewModel.initialize(null, false);

        final results = await viewModel.searchSpotifyForConnect('wowaka');

        expect(results, isEmpty);
        expect(viewModel.errorMessage, contains(entry.value));
        expect(viewModel.errorMessage, isNot(contains('provider failure')));
        expect(viewModel.errorMessage, isNot('검색 결과가 없습니다.'));
      });
    }

    test('검색 네트워크 실패를 빈 검색 결과와 구분한다', () async {
      final viewModel = _buildViewModel(
        SpotifyService.forTesting(
          credentialProvider: () async => const SpotifyCredentials(
            clientId: 'client-id',
            clientSecret: 'client-secret',
          ),
          post: (uri, {headers, body, encoding}) async {
            return http.Response(
              '{"access_token":"token","expires_in":3600}',
              200,
            );
          },
          get: (uri, {headers}) async {
            throw const SocketException('offline');
          },
        ),
      );
      viewModel.initialize(null, false);

      final results = await viewModel.searchSpotifyForConnect('wowaka');

      expect(results, isEmpty);
      expect(viewModel.errorMessage, contains('네트워크 상태를 확인한 뒤 다시 시도해주세요'));
      expect(viewModel.errorMessage, isNot(contains('SocketException')));
      expect(viewModel.errorMessage, isNot('검색 결과가 없습니다.'));
    });

    test('검색 응답 파싱 실패를 빈 검색 결과와 구분한다', () async {
      final viewModel = _buildViewModel(
        SpotifyService.forTesting(
          credentialProvider: () async => const SpotifyCredentials(
            clientId: 'client-id',
            clientSecret: 'client-secret',
          ),
          post: (uri, {headers, body, encoding}) async {
            return http.Response(
              '{"access_token":"token","expires_in":3600}',
              200,
            );
          },
          get: (uri, {headers}) async {
            return http.Response('not-json', 200);
          },
        ),
      );
      viewModel.initialize(null, false);

      final results = await viewModel.searchSpotifyForConnect('wowaka');

      expect(results, isEmpty);
      expect(viewModel.errorMessage, contains('Spotify 검색 응답을 처리할 수 없습니다'));
      expect(viewModel.errorMessage, isNot(contains('FormatException')));
      expect(viewModel.errorMessage, isNot('검색 결과가 없습니다.'));
    });

    test('커버 이미지 invalid bytes는 Spotify 링크만 부분 적용하고 깨진 경로를 만들지 않는다', () async {
      final viewModel = _buildViewModel(
        SpotifyService(),
        discogsService: DiscogsService.forTesting(
          tokenProvider: () async => 'token',
          get: _unexpectedDiscogsGet,
          imageGet: (Uri uri, {Map<String, String>? headers}) async {
            return http.Response.bytes(<int>[1, 2, 3], 200);
          },
        ),
      );
      viewModel.initialize(
        Album(
          id: 'spotify-partial-link',
          title: 'Unhappy Refrain',
          artists: const <String>['wowaka'],
        ),
        false,
      );

      await viewModel.updateFromSpotify(
        imageUrl: 'https://example.com/cover.png',
        linkUrl: 'https://open.spotify.com/album/unhappy-refrain',
      );

      expect(viewModel.currentAlbum?.imagePath, isNull);
      expect(
        viewModel.currentAlbum?.linkUrl,
        'https://open.spotify.com/album/unhappy-refrain',
      );
      expect(viewModel.errorMessage, contains('커버 이미지를 저장하지 못했습니다'));
      expect(viewModel.hasUnsavedChanges, isTrue);
    });
  });
}

AlbumFormViewModel _buildViewModel(
  SpotifyService spotifyService, {
  DiscogsService? discogsService,
}) {
  return AlbumFormViewModel(
    _FakeAlbumRepository(),
    discogsService ?? DiscogsService(),
    spotifyService,
    VocadbService(),
    MusicBrainzService(),
  );
}

Future<http.Response> _unexpectedDiscogsGet(
  Uri uri, {
  Map<String, String>? headers,
}) async {
  fail('Spotify 커버 저장 테스트에서 Discogs API 요청을 보내면 안 됩니다: $uri');
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
