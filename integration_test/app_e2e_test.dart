import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:my_album_app/main.dart' as app;
import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/screens/home_screen.dart';
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
}
