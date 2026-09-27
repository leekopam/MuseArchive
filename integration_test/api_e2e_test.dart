import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_album_app/main.dart' as app;
import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/screens/add_screen.dart';
import 'package:my_album_app/screens/home_screen.dart';
import 'package:my_album_app/services/i_album_repository.dart';
import 'package:my_album_app/services/spotify_service.dart';

// 실 API 왕복 E2E — 읽기 전용 검색/상세 로드만 검증한다.
// 자격은 tools/boogle/setup-api-credentials.ps1이 만든
// api-credentials.local.json을 device-e2e.ps1이 --dart-define-from-file로 주입한다.
// 자격이 없으면 해당 시나리오는 skip하고, VocaDB/MusicBrainz는 자격 불필요라 항상 실행된다.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const discogsToken = String.fromEnvironment('E2E_DISCOGS_TOKEN');
  const spotifyClientId = String.fromEnvironment('E2E_SPOTIFY_CLIENT_ID');
  const spotifyClientSecret = String.fromEnvironment(
    'E2E_SPOTIFY_CLIENT_SECRET',
  );
  final hasSpotifyCreds =
      spotifyClientId.isNotEmpty && spotifyClientSecret.isNotEmpty;

  // 실 API 구간은 타임아웃(15s)+재시도까지 최악 30초 이상 걸릴 수 있어
  // live 검색·로드 대기에는 긴 상한을 쓴다.
  Future<void> settle(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 200),
      EnginePhase.sendSemanticsUpdate,
      timeout,
    );
  }

  // dart-define 자격을 앱이 읽는 SharedPreferences 경로에 주입한다.
  // 테스트 시작 전 값을 백업해 종료 후 복원해 실기 설정을 오염시키지 않는다.
  Future<Map<String, String?>> seedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final backup = <String, String?>{
      'discogs_api_token': prefs.getString('discogs_api_token'),
      SpotifyService.clientIdPrefsKey: prefs.getString(
        SpotifyService.clientIdPrefsKey,
      ),
      SpotifyService.clientSecretPrefsKey: prefs.getString(
        SpotifyService.clientSecretPrefsKey,
      ),
    };
    if (discogsToken.isNotEmpty) {
      await prefs.setString('discogs_api_token', discogsToken);
    }
    if (hasSpotifyCreds) {
      await prefs.setString(SpotifyService.clientIdPrefsKey, spotifyClientId);
      await prefs.setString(
        SpotifyService.clientSecretPrefsKey,
        spotifyClientSecret,
      );
    }
    return backup;
  }

  Future<void> restoreCredentials(Map<String, String?> backup) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in backup.entries) {
      final value = entry.value;
      if (value == null) {
        await prefs.remove(entry.key);
      } else {
        await prefs.setString(entry.key, value);
      }
    }
  }

  Future<IAlbumRepository> openAddScreen(WidgetTester tester) async {
    app.main();
    await settle(tester);
    final context = tester.element(find.byType(HomeScreen));
    final repository = context.read<IAlbumRepository>();

    await tester.tap(find.byTooltip('앨범 추가'));
    await settle(tester);
    expect(find.byType(AddScreen), findsOneWidget);
    return repository;
  }

  // 앨범 검색 다이얼로그 공통 흐름: 다이얼로그 열기 → 검색 → 첫 결과 선택 →
  // 병합·자동저장까지 수행하고 생성된 앨범을 반환한다.
  // 실 네트워크 스톨(이 기기는 vocadb.net IPv6 경로가 죽어 Cloudflare
  // 듀얼스택 호스트가 간헐적으로 멈춤)은 사용자가 하듯 재시도로 흡수한다.
  Future<Album> searchPickAndMerge(
    WidgetTester tester,
    IAlbumRepository repository,
    Set<String> beforeIds, {
    required String buttonTooltip,
    required String dialogTitle,
    required String resultsTitle,
    String? artist,
    String? title,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.byTooltip(buttonTooltip));
      await settle(tester);
      final dialog = find.widgetWithText(AlertDialog, dialogTitle);
      expect(dialog, findsOneWidget);

      if (artist != null) {
        await tester.enterText(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(TextField, '아티스트 (선택 사항)'),
          ),
          artist,
        );
      }
      if (title != null) {
        await tester.enterText(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(TextField, '앨범 제목'),
          ),
          title,
        );
      }

      // 검색 요청이 스톨하면 같은 다이얼로그에서 한 번 더 시도한다
      var results = find.widgetWithText(AlertDialog, resultsTitle);
      for (var searchAttempt = 0; searchAttempt < 2; searchAttempt++) {
        await tester.tap(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(ElevatedButton, '검색'),
          ),
        );
        await settle(tester, timeout: const Duration(seconds: 90));
        results = find.widgetWithText(AlertDialog, resultsTitle);
        if (results.evaluate().isNotEmpty) break;
      }
      if (results.evaluate().isEmpty) {
        await tester.tap(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(TextButton, '취소'),
          ),
        );
        await settle(tester);
        continue;
      }

      await tester.tap(
        find.descendant(of: results, matching: find.byType(InkWell)).first,
      );
      await settle(tester, timeout: const Duration(seconds: 90));
      // 자동 저장 debounce(1s) 경과 대기
      await tester.pump(const Duration(milliseconds: 1300));
      await settle(tester);

      // 결과 선택 후 상세 로드가 스톨하면 다이얼로그가 닫힌 채 에러만 뜬다.
      // 병합된 앨범이 없으면 다이얼로그 재진입부터 재시도한다.
      final created = (await repository.getAll())
          .where((a) => !beforeIds.contains(a.id))
          .toList();
      if (created.isNotEmpty) return created.single;
    }
    fail('실 API 검색·병합이 재시도 후에도 실패했습니다: $resultsTitle');
  }

  // 기존 앨범 ID 스냅샷 — 기기에 남아 있을 수 있는 다른 데이터와
  // 이번 테스트가 만든 레코드를 구분해 정리 범위를 테스트 생성분으로 한정한다.
  Future<Set<String>> snapshotAlbumIds(IAlbumRepository repository) async =>
      (await repository.getAll()).map((a) => a.id).toSet();

  // 자동 저장으로 생긴 신규 앨범을 조회한다 (제목은 실데이터라 비어있지 않음만 본다)
  Future<Album> findNewAlbum(
    IAlbumRepository repository,
    Set<String> beforeIds,
  ) async {
    final created = (await repository.getAll())
        .where((a) => !beforeIds.contains(a.id))
        .toList();
    expect(created, hasLength(1));
    return created.single;
  }

  Future<void> deleteNewAlbums(
    IAlbumRepository repository,
    Set<String> beforeIds,
  ) async {
    for (final album in await repository.getAll()) {
      if (!beforeIds.contains(album.id)) {
        await repository.delete(album.id);
      }
    }
  }

  testWidgets('S04·S15 VocaDB 실 API 검색 → 선택 → 병합 → 저장', (tester) async {
    final backup = await seedCredentials();
    final repository = await openAddScreen(tester);
    final beforeIds = await snapshotAlbumIds(repository);

    try {
      final album = await searchPickAndMerge(
        tester,
        repository,
        beforeIds,
        buttonTooltip: 'VocaDB에서 검색',
        dialogTitle: 'VocaDB 앨범 검색',
        resultsTitle: 'VocaDB 검색 결과',
        artist: 'wowaka',
      );
      expect(album.title, isNotEmpty);
      expect(album.artists, isNotEmpty);
    } finally {
      await deleteNewAlbums(repository, beforeIds);
      await restoreCredentials(backup);
    }
  });

  testWidgets('S04·S15 MusicBrainz 실 API 검색 → 선택 → 병합 → 저장', (tester) async {
    final backup = await seedCredentials();
    final repository = await openAddScreen(tester);
    final beforeIds = await snapshotAlbumIds(repository);

    try {
      final album = await searchPickAndMerge(
        tester,
        repository,
        beforeIds,
        buttonTooltip: 'MusicBrainz에서 검색',
        dialogTitle: 'MusicBrainz 앨범 검색',
        resultsTitle: 'MusicBrainz 검색 결과',
        artist: 'Radiohead',
        title: 'OK Computer',
      );
      expect(album.title, isNotEmpty);
      expect(album.artists, isNotEmpty);
    } finally {
      await deleteNewAlbums(repository, beforeIds);
      await restoreCredentials(backup);
    }
  });

  testWidgets('S04·S10·S15 Discogs 실 API 검색 → 선택 → 병합 → 저장', (tester) async {
    final backup = await seedCredentials();
    final repository = await openAddScreen(tester);
    final beforeIds = await snapshotAlbumIds(repository);

    try {
      final album = await searchPickAndMerge(
        tester,
        repository,
        beforeIds,
        buttonTooltip: 'Discogs에서 검색',
        dialogTitle: 'Discogs 앨범 검색',
        resultsTitle: '앨범 검색 결과',
        artist: 'Radiohead',
        title: 'OK Computer',
      );
      expect(album.title, isNotEmpty);
      expect(album.artists, isNotEmpty);
    } finally {
      await deleteNewAlbums(repository, beforeIds);
      await restoreCredentials(backup);
    }
  }, skip: discogsToken.isEmpty);

  testWidgets('S04·S10 Spotify 실 API 링크 검색 → 이미지·링크 병합 → 저장', (tester) async {
    final backup = await seedCredentials();
    final repository = await openAddScreen(tester);
    final beforeIds = await snapshotAlbumIds(repository);

    try {
      // Spotify 병합은 커버 이미지와 링크만 채우므로 제목·아티스트는 직접 입력한다
      await tester.enterText(
        find.widgetWithText(TextFormField, '앨범 제목'),
        'E2E Spotify Album',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '아티스트 (쉼표로 구분)'),
        'E2E Artist',
      );

      final spotifyButton = find.byTooltip('Spotify에서 링크 검색');
      await tester.scrollUntilVisible(
        spotifyButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
      await tester.tap(spotifyButton);
      await settle(tester);

      final dialog = find.widgetWithText(AlertDialog, 'Spotify 이미지 검색');
      expect(dialog, findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(TextField, '검색어 (앨범명/아티스트)'),
        ),
        'OK Computer',
      );
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(ElevatedButton, '검색'),
        ),
      );
      await settle(tester, timeout: const Duration(seconds: 90));

      final results = find.widgetWithText(AlertDialog, 'Spotify 검색 결과');
      expect(results, findsOneWidget);
      await tester.tap(
        find.descendant(of: results, matching: find.byType(ListTile)).first,
      );
      // 이미지 다운로드(30초 상한)까지 포함해 기다린다
      await settle(tester, timeout: const Duration(seconds: 90));
      await tester.pump(const Duration(milliseconds: 1300));
      await settle(tester);

      final album = await findNewAlbum(repository, beforeIds);
      expect(album.title, 'E2E Spotify Album');
      expect(album.linkUrl, contains('open.spotify.com'));
      expect(album.imagePath, isNotNull);
      expect(await File(album.imagePath!).exists(), isTrue);
    } finally {
      await deleteNewAlbums(repository, beforeIds);
      await restoreCredentials(backup);
    }
  }, skip: !hasSpotifyCreds);
}
