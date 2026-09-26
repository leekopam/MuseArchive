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
}
