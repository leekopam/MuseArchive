import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:my_album_app/main.dart' as app;
import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/screens/add_screen.dart';
import 'package:my_album_app/screens/detail_screen.dart';
import 'package:my_album_app/screens/home_screen.dart';
import 'package:my_album_app/screens/settings_screen.dart';
import 'package:my_album_app/services/album_repository.dart';
import 'package:my_album_app/services/i_album_repository.dart';
import 'package:my_album_app/widgets/animation_widgets.dart';

// 실기 L3: 앱 기동 → 시드 앨범 표시 → 상세 진입 → 삭제까지의 사용자 흐름.
// 실제 Hive 저장소와 실제 화면 탐색을 사용한다.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const seedId = 'e2e-seed-0001';
  const seedTitle = 'E2E Seed Album';

  /// 무한 애니메이션(스켈레톤 등)이 있어도 30초 안에 실패로 종료한다
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 200),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 30),
    );
  }

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
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await settle(tester);

    final albums = await repository.getAll();
    expect(albums.any((a) => a.id == seedId), isFalse);
    expect(find.text(seedTitle), findsNothing);
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
    await tester.enterText(
      find.byType(TextFormField).first,
      editedTitle,
    );
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
    expect(
      albums.firstWhere((a) => a.id == seedId).title,
      editedTitle,
    );

    // 다음 실행을 위해 시드 데이터를 정리한다
    await repository.delete(seedId);
    await settle(tester);
  });

  testWidgets('S11 백업 파일 생성 → 삭제 → zip 복원 왕복', (tester) async {
    // 시스템 파일·저장 다이얼로그(FilePicker/FlutterFileDialog)는 자동 탭이
    // 불가능해 M01 수동 범위로 남긴다. 여기서는 설정 화면 진입과 실제
    // export→import 왕복을 실기기 파일 시스템으로 검증한다.
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
}
