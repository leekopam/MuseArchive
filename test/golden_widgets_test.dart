import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_album_app/utils/theme.dart';
import 'package:my_album_app/widgets/common_widgets.dart';

import 'boogle_hook.dart';

// 시각 회귀: 안정적인 공용 위젯의 golden 비교.
// 실패 시 flutter_test가 failures/에 diff PNG를 생성하며, 그걸 Boogle artifact로 제출한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// golden 비교 + 실패 diff를 Boogle artifact로 제출
  Future<void> expectGolden(
    WidgetTester tester,
    Finder finder,
    String name,
  ) async {
    try {
      await expectLater(finder, matchesGoldenFile('goldens/$name.png'));
    } catch (_) {
      final failuresDir = Directory('test/goldens/failures');
      if (await failuresDir.exists()) {
        await for (final entry in failuresDir.list()) {
          if (entry is File && entry.path.endsWith('.png')) {
            final fileName = entry.uri.pathSegments.last;
            await BoogleHook.artifact(
              entry.path,
              fileName: 'golden-$fileName',
              kind: 'capture',
            );
          }
        }
      }
      rethrow;
    }
  }

  testWidgets('EmptyState 기본', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: EmptyState(icon: Icons.inbox, message: '비어 있습니다'),
        ),
      ),
    );
    await expectGolden(tester, find.byType(EmptyState), 'empty_state_basic');
  });

  testWidgets('EmptyState 액션 버튼 포함', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: EmptyState(
            icon: CupertinoIcons.music_albums,
            message: '앨범을 추가하세요',
            actionLabel: '추가',
            onAction: () {},
          ),
        ),
      ),
    );
    await expectGolden(tester, find.byType(EmptyState), 'empty_state_action');
  });

  testWidgets('EmptyState 다크 테마', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: EmptyState(icon: Icons.inbox, message: '비어 있습니다'),
        ),
      ),
    );
    await expectGolden(tester, find.byType(EmptyState), 'empty_state_dark');
  });

  group('AlbumFormatBadges 별칭·미매칭', () {
    Future<void> pumpBadges(WidgetTester tester, List<String> formats) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AlbumFormatBadges(formats: formats)),
        ),
      );
    }

    testWidgets('Bluray 표기도 Blu-ray 배지로 통일된다', (tester) async {
      await pumpBadges(tester, ['Bluray']);
      expect(find.text('Blu-ray'), findsOneWidget);
      expect(find.text('Bluray'), findsNothing);
    });

    testWidgets('vinyl 별칭은 LP 배지를 만든다', (tester) async {
      await pumpBadges(tester, ['Vinyl, LP, Album']);
      expect(find.text('LP'), findsOneWidget);
    });

    testWidgets('알 수 없는 포맷은 원문 배지로 노출된다', (tester) async {
      await pumpBadges(tester, ['Cassette']);
      expect(find.text('Cassette'), findsOneWidget);
    });

    testWidgets('빈 목록이면 아무것도 렌더링하지 않는다', (tester) async {
      await pumpBadges(tester, const []);
      expect(find.byType(Container), findsNothing);
    });
  });

  group('ConfirmDialog', () {
    Future<void> pumpAndOpen(
      WidgetTester tester, {
      required bool isDestructive,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ConfirmDialog.show(
                  context,
                  title: '삭제',
                  content: '삭제하시겠습니까?',
                  confirmText: '삭제',
                  isDestructive: isDestructive,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('파괴적 액션은 확인 버튼이 에러 색을 쓴다', (tester) async {
      await pumpAndOpen(tester, isDestructive: true);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final bg = button.style?.backgroundColor?.resolve(<WidgetState>{});
      expect(bg, AppTheme.light.colorScheme.error);
    });

    testWidgets('일반 확인은 테마 기본 버튼 색을 유지한다', (tester) async {
      await pumpAndOpen(tester, isDestructive: false);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.style?.backgroundColor, isNull);
    });
  });
}
