/// S15·S16 스텁 경계 E2E — 시나리오 ID ↔ 테스트 함수 매핑은
/// docs/qa/E2E_TEST_TOOL_PLAN_PHASE2.md §2 표를 따른다.
///
/// 실서비스 코드(기본 `http.get`/`http.post` 경로)를 `http.runWithClient`로 감싸
/// 요청 URL만 루프백 스텁 서버로 재작성한다. 외부 네트워크 요청 0건을 유지하면서
/// dart:io 실제 소켓 경계까지 검증한다.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' show IOClient;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_album_app/services/discogs_service.dart';
import 'package:my_album_app/services/musicbrainz_service.dart';
import 'package:my_album_app/services/spotify_service.dart';
import 'package:my_album_app/services/update_service.dart';
import 'package:my_album_app/services/vocadb_service.dart';

import 'boogle_hook.dart';

// --- 스텁 서버 canned 응답 -------------------------------------------------

const _mbSearchJson =
    '{"releases":[{"id":"mbid-0001","title":"アンハッピーリフレイン",'
    '"artist-credit":[{"name":"wowaka"}],"date":"2011-05-18",'
    '"media":[{"format":"CD"}]}]}';

const _vocadbSearchJson =
    '{"items":[{"id":1234,"name":"ワールズエンド・ダンスホール",'
    '"artistString":"wowaka, 初音ミク",'
    '"mainPicture":{"urlThumb":"https://vocadb.net/thumb.png"},'
    '"releaseDate":{"year":2010,"month":5,"day":7},"discType":"Album"}]}';

const _spotifyTokenJson =
    '{"access_token":"stub-token","token_type":"Bearer","expires_in":3600}';

const _spotifySearchJson =
    '{"albums":{"items":[{"id":"sp-001","name":"SEVEN GIRLS DISCORD",'
    '"artists":[{"name":"wowaka"}],"images":[{"url":"https://i.example/1.jpg"}],'
    '"release_date":"2010-11-14",'
    '"external_urls":{"spotify":"https://open.spotify.com/album/sp-001"}}]}}';

const _discogsSearchJson =
    '{"results":[{"id":9001,"title":"Unhappy Refrain","artist":"wowaka",'
    '"year":"2011","thumb":"https://i.example/2.jpg",'
    '"format":["Vinyl","LP"]}]}';

String _githubReleaseJson(String tag) =>
    '{"tag_name":"$tag","body":"릴리스 노트","html_url":"https://example.com/release/$tag",'
    '"assets":[{"name":"app-release.apk",'
    '"browser_download_url":"https://example.com/app-$tag.apk"}]}';

const _githubReleaseNoApkJson =
    '{"tag_name":"v9.9.9","body":"릴리스 노트","html_url":"https://example.com/release/v9.9.9",'
    '"assets":[]}';

// --- 루프백 스텁 인프라 -----------------------------------------------------

/// 요청 URL만 루프백으로 재작성하는 실제 HTTP 클라이언트.
/// 원본 호스트를 첫 경로 세그먼트로 옮겨 서버가 가상 호스트별로 분기한다.
class _LoopbackRewriteClient extends http.BaseClient {
  _LoopbackRewriteClient(this._inner, this._port);

  final http.Client _inner;
  final int _port;

  Uri _rewrite(Uri url) => url.replace(
    scheme: 'http',
    host: '127.0.0.1',
    port: _port,
    path: '/${url.host}${url.path}',
  );

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      super.get(_rewrite(url), headers: headers);

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => super.post(
    _rewrite(url),
    headers: headers,
    body: body,
    encoding: encoding,
  );

  @override
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => super.put(
    _rewrite(url),
    headers: headers,
    body: body,
    encoding: encoding,
  );

  @override
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => super.patch(
    _rewrite(url),
    headers: headers,
    body: body,
    encoding: encoding,
  );

  @override
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => super.delete(
    _rewrite(url),
    headers: headers,
    body: body,
    encoding: encoding,
  );

  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) =>
      super.head(_rewrite(url), headers: headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  /// http.get 등 편의 함수가 호출마다 close()를 호출하므로 공유 inner를 닫지 않는다.
  /// inner 수명은 tearDownAll에서 관리한다.
  @override
  void close() {}
}

/// flutter_test 바인딩의 네트워크 차단 HttpOverrides를 우회해 실제
/// HttpClient를 만들기 위한 기본 구현체.
class _PassthroughHttpOverrides extends HttpOverrides {}

/// 가상 호스트별 canned JSON을 반환하는 로컬 스텁 서버.
class _StubApiServer {
  _StubApiServer._(this._server);

  final HttpServer _server;
  final List<Map<String, String>> requests = [];

  /// 테스트별 교체 가능한 GitHub 응답 (상태, 본문)
  ({int status, String body}) githubResponse = (status: 200, body: '');

  static const _ok = 200;
  static const _failMarker = '__fail__';

  /// 'vhost path' → (status, body) 고정 라우트
  static final _routes = <String, ({int status, String body})>{
    'musicbrainz.org /ws/2/release/': (status: _ok, body: _mbSearchJson),
    'vocadb.net /api/albums': (status: _ok, body: _vocadbSearchJson),
    'accounts.spotify.com /api/token': (status: _ok, body: _spotifyTokenJson),
    'api.spotify.com /v1/search': (status: _ok, body: _spotifySearchJson),
    'api.discogs.com /database/search': (status: _ok, body: _discogsSearchJson),
  };

  int get port => _server.port;

  static Future<_StubApiServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final stub = _StubApiServer._(server);
    server.listen(stub._handle);
    return stub;
  }

  Future<void> close() => _server.close(force: true);

  List<Map<String, String>> requestsTo(String vhost) =>
      requests.where((r) => r['vhost'] == vhost).toList();

  void _handle(HttpRequest req) {
    final segments = req.uri.pathSegments;
    final vhost = segments.isEmpty ? '' : segments.first;
    final rest = '/${segments.skip(1).join('/')}';

    requests.add({
      'vhost': vhost,
      'method': req.method,
      'path': rest,
      'query': req.uri.query,
      if (req.headers.value('authorization') != null)
        'authorization': req.headers.value('authorization')!,
    });

    final params = req.uri.queryParameters;
    final marker = params['query'] ?? params['q'];
    final ({int status, String body}) result;
    if (marker == _failMarker) {
      result = (status: 500, body: '{"error":"stub failure"}');
    } else if (vhost == 'api.github.com' && rest.startsWith('/repos/')) {
      result = githubResponse;
    } else {
      result =
          _routes['$vhost $rest'] ??
          (status: 404, body: '{"error":"no stub route: $vhost $rest"}');
    }

    req.response
      ..statusCode = result.status
      ..headers.contentType = ContentType.json
      ..write(result.body);
    req.response.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late http.Client innerClient;
  late _StubApiServer stub;
  late Directory tmpDir;

  /// 서비스 호출을 스텁 클라이언트 존 안에서 실행한다.
  Future<T> withStub<T>(Future<T> Function() body) => http.runWithClient(
    body,
    () => _LoopbackRewriteClient(innerClient, stub.port),
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'spotify_client_id': 'stub-client-id',
      'spotify_client_secret': 'stub-client-secret',
      'discogs_api_token': 'stub-discogs-token',
    });
    PackageInfo.setMockInitialValues(
      appName: 'MuseArchive',
      packageName: 'com.example.musearchive',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'stub',
    );
    // 바인딩이 설치한 네트워크 차단 오버라이드를 벗어나 실제 소켓 클라이언트 생성
    innerClient = HttpOverrides.runWithHttpOverrides(
      () => IOClient(HttpClient()),
      _PassthroughHttpOverrides(),
    );
    stub = await _StubApiServer.start();
    tmpDir = await Directory.systemTemp.createTemp('api_stub_boundary_');
  });

  tearDownAll(() async {
    innerClient.close();
    await stub.close();

    // 스텁 서버가 받은 요청 로그를 봉인 evidence로 남긴다.
    final logFile = File('${tmpDir.path}/stub-requests.json');
    await logFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(stub.requests),
    );
    await BoogleHook.artifact(
      logFile.path,
      fileName: 'api-stub-requests.json',
      kind: 'output',
    );
  });

  group('S15 API 조회 스텁 경계', () {
    test('S15 MusicBrainz 검색이 실서비스 경로로 스텁 응답을 파싱한다', () async {
      final results = await withStub(
        () => MusicBrainzService().searchAlbums('wowaka'),
      );

      expect(results, hasLength(1));
      expect(results.first['id'], 'mbid-0001');
      expect(results.first['artist'], 'wowaka');
      expect(results.first['year'], '2011');
      expect(results.first['format'], 'CD');

      final reqs = stub.requestsTo('musicbrainz.org');
      expect(reqs, hasLength(1));
      expect(reqs.first['path'], '/ws/2/release/');

      await BoogleHook.metric(
        'e2e/api.searchResults',
        value: 1,
        unit: 'count',
        thresholdValue: 1,
      );
    });

    test('S15 MusicBrainz 서버 오류를 빈 결과가 아닌 예외로 구분한다', () async {
      await expectLater(
        withStub(
          () => MusicBrainzService().searchAlbums(_StubApiServer._failMarker),
        ),
        throwsA(
          isA<MusicBrainzServiceException>().having(
            (e) => e.message,
            'message',
            contains('서버 오류'),
          ),
        ),
      );

      await BoogleHook.metric(
        'e2e/api.errorSurfaced',
        value: 1,
        unit: 'bool',
        thresholdValue: 1,
      );
    });

    test('S15 VocaDB 검색이 실서비스 경로로 스텁 응답을 파싱한다', () async {
      final results = await withStub(
        () => VocadbService().searchAlbums('wowaka'),
      );

      expect(results, hasLength(1));
      expect(results.first['title'], 'ワールズエンド・ダンスホール');
      expect(results.first['artist'], 'wowaka, 初音ミク');
      expect(results.first['year'], '2010.5.7');
      expect(results.first['format'], 'Album');

      await BoogleHook.metric(
        'e2e/api.searchResults',
        value: 2,
        unit: 'count',
        thresholdValue: 2,
      );
    });

    test('S15 Spotify 토큰 발급 후 검색까지 Bearer 인증을 실어 보낸다', () async {
      final results = await withStub(
        () => SpotifyService().searchAlbums('wowaka'),
      );

      expect(results, hasLength(1));
      expect(results.first['title'], 'SEVEN GIRLS DISCORD');
      expect(results.first['artist'], 'wowaka');
      expect(results.first['release_date'], '2010-11-14');

      final tokenReqs = stub.requestsTo('accounts.spotify.com');
      expect(tokenReqs, hasLength(1));
      expect(tokenReqs.first['method'], 'POST');

      final searchReqs = stub.requestsTo('api.spotify.com');
      expect(searchReqs, hasLength(1));
      expect(searchReqs.first['authorization'], 'Bearer stub-token');

      await BoogleHook.metric(
        'e2e/api.searchResults',
        value: 3,
        unit: 'count',
        thresholdValue: 3,
      );
    });

    test('S15 Discogs 검색이 실서비스 경로로 스텁 응답을 파싱한다', () async {
      final results = await withStub(
        () => DiscogsService().searchAlbumsByTitleArtist(
          artist: 'wowaka',
          title: 'Unhappy',
        ),
      );

      expect(results, hasLength(1));
      expect(results.first['title'], 'Unhappy Refrain');
      expect(results.first['year'], '2011');
      expect(results.first['format'], 'Vinyl, LP');

      await BoogleHook.metric(
        'e2e/api.searchResults',
        value: 4,
        unit: 'count',
        thresholdValue: 4,
      );
    });

    // 응답이 오지 않는 호출이 무한 대기하지 않고 타임아웃 예외로 변환되는지 검증
    test('S15 VocaDB 응답 지연이 타임아웃 예외로 변환된다', () async {
      final service = VocadbService.forTesting(
        get: (uri, {headers}) => Completer<http.Response>().future,
        apiTimeout: const Duration(milliseconds: 200),
      );
      await expectLater(
        service.searchAlbums('wowaka'),
        throwsA(isA<VocadbServiceException>()),
      );
    });

    test('S15 Discogs 응답 지연이 타임아웃 예외로 변환된다', () async {
      final service = DiscogsService.forTesting(
        tokenProvider: () async => 'test-token',
        get: (uri, {headers}) => Completer<http.Response>().future,
        apiTimeout: const Duration(milliseconds: 200),
      );
      await expectLater(
        service.searchAlbumsByTitleArtist(title: 'test'),
        throwsA(isA<DiscogsServiceException>()),
      );
    });

    test('S15 VocaDB 첫 요청 지연 시 재시도가 실제 응답으로 회복된다', () async {
      var calls = 0;
      final service = VocadbService.forTesting(
        get: (uri, {headers}) {
          calls++;
          // 첫 요청만 응답 없이 지연시켜 재시도 경로를 검증한다
          if (calls == 1) return Completer<http.Response>().future;
          return Future.value(http.Response('{"items":[]}', 200));
        },
        apiTimeout: const Duration(milliseconds: 200),
      );
      expect(await service.searchAlbums('wowaka'), isEmpty);
      expect(calls, 2);
    });

    test('S15 Spotify 인증 응답 지연이 타임아웃 예외로 변환된다', () async {
      final service = SpotifyService.forTesting(
        credentialProvider: () async =>
            const SpotifyCredentials(clientId: 'id', clientSecret: 'secret'),
        post: (uri, {headers, body, encoding}) =>
            Completer<http.Response>().future,
        apiTimeout: const Duration(milliseconds: 200),
      );
      await expectLater(
        service.searchAlbums('wowaka'),
        throwsA(isA<SpotifyServiceException>()),
      );
    });

    test('S15 MusicBrainz 응답 지연이 타임아웃 예외로 변환된다', () async {
      final service = MusicBrainzService.forTesting(
        get: (uri, {headers}) => Completer<http.Response>().future,
        apiTimeout: const Duration(milliseconds: 200),
      );
      await expectLater(
        service.searchAlbums('wowaka'),
        throwsA(isA<MusicBrainzServiceException>()),
      );
    });
  });

  group('S16 업데이트 확인 스텁 경계', () {
    test('S16 최신 릴리스가 더 높으면 UpdateInfo와 APK URL을 반환한다', () async {
      stub.githubResponse = (status: 200, body: _githubReleaseJson('v9.9.9'));

      final info = await withStub(() => UpdateService().checkForUpdate());

      expect(info, isNotNull);
      expect(info!.latestVersion, '9.9.9');
      expect(info.downloadUrl, endsWith('.apk'));
      expect(info.releaseNotes, '릴리스 노트');

      final reqs = stub.requestsTo('api.github.com');
      expect(reqs, hasLength(1));
      expect(reqs.first['path'], contains('/releases/latest'));

      await BoogleHook.metric(
        'e2e/update.branches',
        value: 1,
        unit: 'count',
        thresholdValue: 1,
      );
    });

    test('S16 현재 버전과 같거나 낮으면 UpdateInfo를 반환하지 않는다', () async {
      stub.githubResponse = (status: 200, body: _githubReleaseJson('v1.0.0'));

      final info = await withStub(() => UpdateService().checkForUpdate());

      expect(info, isNull);

      await BoogleHook.metric(
        'e2e/update.branches',
        value: 2,
        unit: 'count',
        thresholdValue: 2,
      );
    });

    test('S16 APK 에셋이 없으면 릴리스 페이지 URL로 폴백한다', () async {
      stub.githubResponse = (status: 200, body: _githubReleaseNoApkJson);

      final info = await withStub(() => UpdateService().checkForUpdate());

      expect(info, isNotNull);
      expect(info!.downloadUrl, 'https://example.com/release/v9.9.9');

      await BoogleHook.metric(
        'e2e/update.branches',
        value: 3,
        unit: 'count',
        thresholdValue: 3,
      );
    });
  });
}
