import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_album_app/widgets/animation_widgets.dart';

void main() {
  group('EntryAnimationLimiter', () {
    // FadeSlideIn 내부의 FadeTransition만 조회한다 (라우트 전환의 FadeTransition과 구분)
    double itemOpacity(WidgetTester tester) {
      return tester
          .widget<FadeTransition>(
            find.descendant(
              of: find.byType(FadeSlideIn),
              matching: find.byType(FadeTransition),
            ),
          )
          .opacity
          .value;
    }

    testWidgets('시간 창 안에 만든 아이템은 입장 애니메이션을 실행한다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EntryAnimationLimiter(child: FadeSlideIn(child: Text('hi'))),
        ),
      );

      expect(itemOpacity(tester), lessThan(1.0));

      await tester.pump(const Duration(milliseconds: 400));
      expect(itemOpacity(tester), 1.0);
    });

    testWidgets('시간 창이 지난 뒤 만든 아이템은 최종 상태로 바로 표시된다', (tester) async {
      bool showItem = false;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              outerSetState = setState;
              return EntryAnimationLimiter(
                child: Column(
                  children: [
                    if (showItem) const FadeSlideIn(child: Text('late')),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 900));
      outerSetState(() => showItem = true);
      await tester.pump();

      expect(itemOpacity(tester), 1.0);
    });

    testWidgets('부모 재빌드가 시간 창을 리셋하지 않는다', (tester) async {
      bool showItem = false;
      int version = 0;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              outerSetState = setState;
              return EntryAnimationLimiter(
                child: Column(
                  children: [
                    Text('v$version'),
                    if (showItem) const FadeSlideIn(child: Text('late')),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // 마운트 700ms 시점의 재빌드가 윈도를 리셋하면 아이템이 다시 애니메이션된다.
      // StatelessWidget 구현에서는 이 재빌드가 _startTime을 갱신해 회귀가 발생했다.
      await tester.pump(const Duration(milliseconds: 700));
      outerSetState(() => version = 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      outerSetState(() => showItem = true);
      await tester.pump();

      // 최초 마운트 기준으로는 950ms가 지났으므로 애니메이션 없이 표시돼야 한다
      expect(itemOpacity(tester), 1.0);
    });
  });
}
