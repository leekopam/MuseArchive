import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_album_app/main.dart' as app;
import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/models/track.dart';
import 'package:my_album_app/screens/add_screen.dart';
import 'package:my_album_app/screens/all_songs_screen.dart';
import 'package:my_album_app/screens/detail_screen.dart';
import 'package:my_album_app/screens/home_screen.dart';
import 'package:my_album_app/screens/settings_screen.dart';
import 'package:my_album_app/services/album_repository.dart';
import 'package:my_album_app/services/i_album_repository.dart';
import 'package:my_album_app/services/theme_manager.dart';
import 'package:my_album_app/viewmodels/home_viewmodel.dart';
import 'package:my_album_app/widgets/animation_widgets.dart';

// 실기 L3: 앱 기동 → 시드 앨범 표시 → 상세 진입 → 삭제까지의 사용자 흐름.
// 실제 Hive 저장소와 실제 화면 탐색을 사용한다.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const seedId = 'e2e-seed-0001';
  const seedId2 = 'e2e-seed-0002';
  const seedTitle = 'E2E Seed Album';
  const seedArtist = 'E2E Artist';
  const nativePickerSeedId = 'e2e-native-picker-0001';
  const nativePickerSeedTitle = 'E2E Native Picker Album';
  const nativeFileDialogsEnabled = bool.fromEnvironment(
    'E2E_NATIVE_FILE_DIALOGS',
  );

  /// 무한 애니메이션(스켈레톤 등)이 있어도 30초 안에 실패로 종료한다
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 200),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 30),
    );
  }

  Future<void> waitForText(WidgetTester tester, String value) async {
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump();
      if (find.text(value).evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
    }
    expect(find.text(value), findsOneWidget);
  }

  // 보기 모드·정렬·최근 검색어가 SharedPreferences에 지속되므로,
  // 이전 시나리오(또는 이전 실행)의 값이 다음 테스트를 오염시키지 않게 지운다.
  // 예: 이미지 시나리오가 아티스트 뷰에서 끝나면 검색 시나리오가 목록 뷰로 시작해 실패한다.
  setUp(HomeViewModel.debugClearPersistedState);

  testWidgets('S01·S07 홈 표시 → 상세 진입 → 삭제 왕복', (tester) async {
    app.main();
    await settle(tester);

    expect(find.text('MuseArchive'), findsOneWidget);

    // 앱이 올린 실제 저장소를 context에서 꺼내 시드 앨범을 심는다
    final context = tester.element(find.byType(HomeScreen));
    final repository = context.read<IAlbumRepository>();
    await repository.delete(seedId); // 이전 실패 잔재 정리
    await repository.add(
      Album(id: seedId, title: seedTitle, artists: const ['E2E Artist']),
    );
    await settle(tester);

    // 일반 그리드의 앨범 카드는 별도 키를 갖지 않으므로 제목 기준으로 찾는다
    expect(find.text(seedTitle), findsWidgets);
    final seedCard = find.widgetWithText(TapScaleWrapper, seedTitle);
    expect(seedCard, findsOneWidget);

    // 카드 롱프레스 → 삭제 → 확인 다이얼로그
    await tester.longPress(seedCard);
    await settle(tester);
    await tester.tap(find.text('앨범 삭제'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await settle(tester);

    final albums = await repository.getAll();
    expect(albums.any((a) => a.id == seedId), isFalse);
    expect(find.text(seedTitle), findsNothing);

    // 삭제 스낵바의 "실행 취소"로 복원된다
    await tester.tap(find.text('실행 취소'));
    await settle(tester);
    expect(find.text(seedTitle), findsWidgets);
    expect((await repository.getAll()).any((a) => a.id == seedId), isTrue);

    // 시드 데이터 정리
    await repository.delete(seedId);
    await settle(tester);
  });

  testWidgets('S01 컬렉션 → 위시리스트 → 컬렉션 이동 왕복', (tester) async {
    app.main();
    await settle(tester);

    final context = tester.element(find.byType(HomeScreen));
    final repository = context.read<IAlbumRepository>();
    await repository.delete(seedId);

    try {
      await repository.add(
        Album(id: seedId, title: seedTitle, artists: const [seedArtist]),
      );
      await settle(tester);

      await tester.longPress(find.widgetWithText(TapScaleWrapper, seedTitle));
      await settle(tester);
      await tester.tap(find.text('위시리스트로 이동'));
      await settle(tester);
      expect(find.text(seedTitle), findsNothing);

      await tester.tap(find.text('위시리스트'));
      await settle(tester);
      expect(find.text(seedTitle), findsWidgets);

      await tester.longPress(find.widgetWithText(TapScaleWrapper, seedTitle));
      await settle(tester);
      await tester.tap(find.text('컬렉션으로 이동'));
      await settle(tester);
      expect(find.text(seedTitle), findsNothing);

      await tester.tap(find.text('컬렉션'));
      await settle(tester);
      expect(find.text(seedTitle), findsWidgets);
      expect(
        (await repository.getAll())
            .firstWhere((a) => a.id == seedId)
            .isWishlist,
        isFalse,
      );
    } finally {
      await repository.delete(seedId);
    }
  });

  testWidgets('S01·S02 홈 정렬·보기 설정이 화면 이동 후 유지된다', (tester) async {
    app.main();
    await settle(tester);

    const zebraId = 'e2e-sort-zebra';
    const appleId = 'e2e-sort-apple';
    const zebraTitle = 'E2E Sort Zebra';
    const appleTitle = 'E2E Sort Apple';
    final context = tester.element(find.byType(HomeScreen));
    final repository = context.read<IAlbumRepository>();
    final viewModel = context.read<HomeViewModel>();
    final prefs = await SharedPreferences.getInstance();

    for (final id in [zebraId, appleId]) {
      if ((await repository.getAll()).any((album) => album.id == id)) {
        await repository.delete(id);
      }
    }

    try {
      await repository.add(
        Album(id: zebraId, title: zebraTitle, artists: const [seedArtist]),
      );
      await repository.add(
        Album(id: appleId, title: appleTitle, artists: const [seedArtist]),
      );
      await settle(tester);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await settle(tester);
      await tester.tap(find.text('정렬'));
      await settle(tester);
      await tester.tap(find.text('앨범명'));
      await settle(tester);

      final appleCard = find.widgetWithText(TapScaleWrapper, appleTitle);
      final zebraCard = find.widgetWithText(TapScaleWrapper, zebraTitle);
      expect(appleCard, findsOneWidget);
      expect(zebraCard, findsOneWidget);
      expect(
        tester.getTopLeft(appleCard).dx,
        lessThan(tester.getTopLeft(zebraCard).dx),
      );
      expect(viewModel.sortOption, SortOption.title);
      expect(prefs.getInt('home_sort_option'), SortOption.title.index);

      await tester.tap(find.byTooltip('3열 그리드로 보기'));
      await settle(tester);
      expect(viewModel.viewMode, ViewMode.grid3);
      expect(prefs.getInt('home_view_mode'), ViewMode.grid3.index);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await settle(tester);
      await tester.tap(find.text('설정'));
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(viewModel.sortOption, SortOption.title);
      expect(viewModel.viewMode, ViewMode.grid3);
      expect(
        tester.getTopLeft(appleCard).dx,
        lessThan(tester.getTopLeft(zebraCard).dx),
      );
    } finally {
      await repository.delete(zebraId);
      await repository.delete(appleId);
      await HomeViewModel.debugClearPersistedState();
    }
  });

  testWidgets('S12 설정 다크 모드 → 홈 회색 테마 → 저장값 복원', (tester) async {
    app.main();
    await settle(tester);

    final prefs = await SharedPreferences.getInstance();
    final originalPreference = prefs.getBool('is_dark_mode');
    final originalMode = themeNotifier.value;

    try {
      await saveTheme(false);
      await settle(tester);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await settle(tester);
      await tester.tap(find.text('설정'));
      await settle(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await settle(tester);
      expect(themeNotifier.value, ThemeMode.dark);
      expect(prefs.getBool('is_dark_mode'), isTrue);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        Theme.of(
          tester.element(find.byType(HomeScreen)),
        ).scaffoldBackgroundColor,
        const Color(0xFF292C30),
      );

      themeNotifier.value = ThemeMode.light;
      await loadTheme();
      expect(themeNotifier.value, ThemeMode.dark);
    } finally {
      if (originalPreference == null) {
        await prefs.remove('is_dark_mode');
      } else {
        await prefs.setBool('is_dark_mode', originalPreference);
      }
      themeNotifier.value = originalMode;
    }
  });

  testWidgets('S03·S07 홈 → 상세 → 제목 편집 → 복귀 왕복', (tester) async {
    app.main();
    await settle(tester);

    final context = tester.element(find.byType(HomeScreen));
    final repository = context.read<IAlbumRepository>();
    await repository.delete(seedId);
    await repository.add(
      Album(id: seedId, title: seedTitle, artists: const ['E2E Artist']),
    );
    await settle(tester);

    // 홈 카드 탭 → 상세 화면
    final seedCard = find.widgetWithText(TapScaleWrapper, seedTitle);
    expect(seedCard, findsOneWidget);
    await tester.tap(seedCard);
    await settle(tester);
    expect(find.byType(DetailScreen), findsOneWidget);

    // 상세 → 수정 화면 진입
    await tester.tap(find.byTooltip('앨범 수정'));
    await settle(tester);
    expect(find.byType(AddScreen), findsOneWidget);

    // 제목 필드 수정 → 자동 저장 디바운스 대기
    const editedTitle = 'E2E Edited Album';
    await tester.enterText(find.byType(TextFormField).first, editedTitle);
    await tester.pump(const Duration(milliseconds: 1300));
    await settle(tester);

    // AnimatedPageRoute는 앱바 뒤로 버튼을 만들지 않으므로 OS back 경로를
    // 그대로 재현한다. PopScope가 저장 후 pop을 완료한다
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(DetailScreen), findsOneWidget);
    expect(find.text(editedTitle), findsWidgets);

    // 상세 → 홈 복귀 후 그리드에도 수정된 제목이 보인다
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text(editedTitle), findsWidgets);

    final albums = await repository.getAll();
    expect(albums.firstWhere((a) => a.id == seedId).title, editedTitle);

    // 다음 실행을 위해 시드 데이터를 정리한다
    await repository.delete(seedId);
    await settle(tester);
  });

  testWidgets('S11 백업 파일 생성 → 삭제 → zip 복원 왕복', (tester) async {
    // 저장소 API의 zip 왕복을 확인한다. 시스템 파일 창은 아래 별도 테스트에서 검증한다.
    app.main();
    await settle(tester);

    final context = tester.element(find.byType(HomeScreen));
    final repository = context.read<IAlbumRepository>();
    await repository.delete(seedId);
    await repository.add(
      Album(id: seedId, title: seedTitle, artists: const ['E2E Artist']),
    );
    await settle(tester);

    // 홈 오버플로 메뉴 → 설정 화면 진입 확인
    await tester.tap(find.byType(PopupMenuButton<String>));
    await settle(tester);
    await tester.tap(find.text('설정'));
    await settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);

    // 백업 섹션은 리스트 아래쪽에 있어 스크롤로 노출시킨다
    await tester.scrollUntilVisible(
      find.text('백업 및 복원'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('백업 및 복원'), findsWidgets);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    // 실제 저장소 export → zip 파일 경로 획득
    final zipPath = await repository.exportBackup();
    expect(zipPath, isNotNull);

    // 앨범 삭제 후 zip 경로로 복원한다
    await repository.delete(seedId);
    await settle(tester);
    expect(find.text(seedTitle), findsNothing);

    final tempDir = await getTemporaryDirectory();
    final appDir = await getApplicationDocumentsDirectory();
    final restored = await (repository as AlbumRepository)
        .importBackupFromZipPath(zipPath!, tempDir: tempDir, appDir: appDir);
    expect(restored, isTrue);
    await settle(tester);

    final albums = await repository.getAll();
    expect(albums.any((a) => a.id == seedId), isTrue);
    expect(find.text(seedTitle), findsWidgets);

    // 시드 데이터 정리
    await repository.delete(seedId);
    await settle(tester);
  });

  testWidgets('S11 시스템 파일 창으로 백업 저장 → 파일 선택 → 복원', (tester) async {
    app.main();
    await settle(tester);

    final context = tester.element(find.byType(HomeScreen));
    final repository = context.read<IAlbumRepository>();
    expect(
      (await repository.getAll()).any((a) => a.id == nativePickerSeedId),
      isFalse,
      reason: '기존 앨범과 테스트 시드 ID가 겹치면 테스트를 중단한다',
    );

    try {
      await repository.add(
        Album(
          id: nativePickerSeedId,
          title: nativePickerSeedTitle,
          artists: const ['E2E Artist'],
        ),
      );
      await settle(tester);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await settle(tester);
      await tester.tap(find.text('설정'));
      await settle(tester);

      await tester.scrollUntilVisible(
        find.text('백업 생성'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('백업 생성'));
      await tester.pump();
      await waitForText(tester, '백업이 생성되었습니다.');

      await repository.delete(nativePickerSeedId);
      expect(
        (await repository.getAll()).any((a) => a.id == nativePickerSeedId),
        isFalse,
      );

      await tester.scrollUntilVisible(
        find.text('백업 복원'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('백업 복원'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, '복원'));
      await tester.pump();
      await waitForText(tester, '백업이 복원되었습니다.');

      expect(
        (await repository.getAll()).any(
          (a) => a.id == nativePickerSeedId && a.title == nativePickerSeedTitle,
        ),
        isTrue,
      );
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text(nativePickerSeedTitle), findsWidgets);
    } finally {
      await repository.delete(nativePickerSeedId);
    }
  }, skip: !nativeFileDialogsEnabled);

  testWidgets('S01·S05·S07 커버·아티스트 이미지가 저장되고 화면에 표시된다', (tester) async {
    app.main();
    await settle(tester);

    final context = tester.element(find.byType(HomeScreen));
    final repository = context.read<IAlbumRepository>();
    await repository.delete(seedId);

    // 기기 임시 폴더에 실제 PNG를 쓰고 시드 앨범의 커버로 연결한다.
    // repository.add가 원본을 album_images/로 복사해 imagePath를 재작성한다.
    final tempDir = await getTemporaryDirectory();
    final coverSource = '${tempDir.path}/e2e_cover.png';
    await File(coverSource).writeAsBytes(_onePixelPngBytes);
    await repository.add(
      Album(
        id: seedId,
        title: seedTitle,
        artists: const [seedArtist],
        imagePath: coverSource,
      ),
    );
    await settle(tester);

    // S05: 커버가 앱 문서 폴더의 album_images로 복사돼 경로가 재작성된다
    final stored = (await repository.getAll()).firstWhere(
      (a) => a.id == seedId,
    );
    expect(stored.imagePath, contains('album_images'));
    expect(stored.imagePath != coverSource, isTrue);
    expect(await File(stored.imagePath!).exists(), isTrue);

    // S01: 그리드 카드가 플레이스홀더 아이콘 대신 실제 Image를 렌더링한다
    final seedCard = find.widgetWithText(TapScaleWrapper, seedTitle);
    expect(seedCard, findsOneWidget);
    expect(
      find.descendant(of: seedCard, matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: seedCard, matching: find.byIcon(Icons.album)),
      findsNothing,
    );

    // S07: 상세 커버 탭 → 풀스크린 뷰어 → 탭으로 닫기
    await tester.tap(seedCard);
    await settle(tester);
    expect(find.byType(DetailScreen), findsOneWidget);

    // 홈 카드의 Hero가 아래 라우트에 남아 있으므로 상세 화면 범위로 좁힌다
    await tester.tap(
      find.descendant(
        of: find.byType(DetailScreen),
        matching: find.byType(Hero),
      ),
    );
    await settle(tester);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byType(Scaffold).last));
    await settle(tester);
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.byType(DetailScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    // 아티스트 이미지도 artist_images/로 복사되고 아티스트 뷰 아바타에 표시된다
    final artistSource = '${tempDir.path}/e2e_artist.png';
    await File(artistSource).writeAsBytes(_onePixelPngBytes);
    await repository.updateArtistImage(seedArtist, artistSource);

    final artist = repository.getArtistByName(seedArtist);
    expect(artist, isNotNull);
    expect(artist!.imagePath, contains('artist_images'));
    expect(await File(artist.imagePath!).exists(), isTrue);

    // 보기 모드 grid2 → grid3 → artists
    await tester.tap(find.byTooltip('3열 그리드로 보기'));
    await settle(tester);
    await tester.tap(find.byTooltip('아티스트 목록으로 보기'));
    await settle(tester);

    final artistTile = find.widgetWithText(ListTile, seedArtist);
    expect(artistTile, findsOneWidget);
    expect(
      find.descendant(of: artistTile, matching: find.byType(Image)),
      findsOneWidget,
    );

    // 앨범 삭제가 아티스트 레코드를 지우면 파일이 고아가 되므로 먼저 해제한다
    await repository.updateArtistImage(seedArtist, null);
    await repository.delete(seedId);
    await File(coverSource).delete();
    await File(artistSource).delete();
    await settle(tester);
  });

  testWidgets('S01·S09 홈·곡 목록 검색이 필터링하고 닫으면 복원된다', (tester) async {
    app.main();
    await settle(tester);

    final context = tester.element(find.byType(HomeScreen));
    final repository = context.read<IAlbumRepository>();
    await repository.delete(seedId);
    await repository.delete(seedId2);
    await repository.add(
      Album(
        id: seedId,
        title: 'E2E Alpha Album',
        titleKr: 'e2e한국어제목',
        artists: const ['E2E ArtistA'],
        genres: const ['e2e-genre-x'],
        tracks: [
          Track(title: 'E2E Track X'),
          Track(title: 'Interlude'),
        ],
      ),
    );
    await repository.add(
      Album(
        id: seedId2,
        title: 'E2E Beta Album',
        artists: const ['E2E ArtistB'],
        tracks: [Track(title: 'Other Song')],
      ),
    );
    // 별명 매칭은 아티스트 메타데이터에 의존한다 (add()가 아티스트 레코드를 만든 뒤 설정)
    await repository.updateArtistMetadata('E2E ArtistA', const [
      'e2e-alias-a',
    ], const []);
    await settle(tester);

    // 검색 필드 열기 → 제목 부분 문자열로 Beta가 숨겨진다
    await tester.tap(find.byTooltip('검색'));
    await settle(tester);
    expect(find.byType(CupertinoSearchTextField), findsOneWidget);

    void expectOnlyAlphaShown() {
      expect(find.text('E2E Alpha Album'), findsOneWidget);
      expect(find.text('E2E Beta Album'), findsNothing);
    }

    await tester.enterText(
      find.byType(CupertinoSearchTextField),
      'alpha album',
    );
    await settle(tester);
    expectOnlyAlphaShown();

    // 화면 표시는 영문 title이지만 한국어 제목(titleKr)으로도 매칭된다
    await tester.enterText(find.byType(CupertinoSearchTextField), 'e2e한국어');
    await settle(tester);
    expectOnlyAlphaShown();

    // 아티스트 별명·장르도 매칭 대상이다
    await tester.enterText(
      find.byType(CupertinoSearchTextField),
      'e2e-alias-a',
    );
    await settle(tester);
    expectOnlyAlphaShown();

    await tester.enterText(
      find.byType(CupertinoSearchTextField),
      'e2e-genre-x',
    );
    await settle(tester);
    expectOnlyAlphaShown();

    // 매칭 없는 검색어는 검색어를 포함한 빈 상태 문구를 보인다
    await tester.enterText(find.byType(CupertinoSearchTextField), '존재하지않는검색어');
    await settle(tester);
    expect(find.text("'존재하지않는검색어'에 대한 검색 결과가 없습니다."), findsOneWidget);

    // 검색 제출 시 최근 검색어에 기록되고, 입력이 비면 칩으로 노출된다
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    // 실기기에서는 submit이 필드 포커스를 해제하고, 그 뒤의 enterText('')가
    // 실 IME의 이전 값 되밀기로 되돌아간다. 사용자 경로인 X 지우기 버튼으로 지운다.
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoSearchTextField),
        matching: find.byIcon(CupertinoIcons.xmark_circle_fill),
      ),
    );
    await settle(tester);
    expect(find.text('최근 검색'), findsOneWidget);
    expect(find.text('존재하지않는검색어'), findsWidgets);

    // 검색을 닫으면 필터가 해제되고 목록이 복원된다
    await tester.tap(find.byTooltip('검색'));
    await settle(tester);
    expect(find.text('E2E Alpha Album'), findsOneWidget);
    expect(find.text('E2E Beta Album'), findsOneWidget);

    // S09: 모든 곡 목록의 검색은 트랙 제목을 필터링한다
    await tester.tap(find.byType(PopupMenuButton<String>));
    await settle(tester);
    await tester.tap(find.text('모든 곡 목록'));
    await settle(tester);
    expect(find.byType(AllSongsScreen), findsOneWidget);

    final songSearch = find.descendant(
      of: find.byType(AllSongsScreen),
      matching: find.byType(CupertinoSearchTextField),
    );
    expect(songSearch, findsOneWidget);

    await tester.enterText(songSearch, 'track x');
    await settle(tester);
    expect(find.text('E2E Track X'), findsOneWidget);
    expect(find.text('Interlude'), findsNothing);
    expect(find.text('Other Song'), findsNothing);

    await tester.enterText(songSearch, 'other');
    await settle(tester);
    expect(find.text('Other Song'), findsOneWidget);
    expect(find.text('E2E Track X'), findsNothing);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    // 시드 데이터 정리
    await repository.delete(seedId);
    await repository.delete(seedId2);
    await settle(tester);
  });
}

// 디코딩 가능한 1x1 PNG (Image.file 실제 디코드 경로를 타게 하기 위해 필요)
final List<int> _onePixelPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
);
