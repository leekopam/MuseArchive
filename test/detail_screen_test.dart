import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/screens/detail_screen.dart';
import 'package:my_album_app/services/i_album_repository.dart';
import 'package:my_album_app/utils/file_utils.dart';
import 'package:my_album_app/utils/theme.dart';

import 'fakes.dart';

void main() {
  test('Detail app bar uses readable foreground when expanded', () {
    final style = DetailAppBarStyle.fromTheme(
      AppTheme.light,
      isCollapsed: false,
    );

    expect(style.foregroundColor, Colors.white);
    expect(style.systemOverlayStyle.statusBarIconBrightness, Brightness.light);
  });

  test(
    'Detail app bar uses surface foreground when collapsed in light mode',
    () {
      final theme = AppTheme.light;
      final style = DetailAppBarStyle.fromTheme(theme, isCollapsed: true);

      expect(style.foregroundColor, theme.colorScheme.onSurface);
      expect(style.systemOverlayStyle.statusBarIconBrightness, Brightness.dark);
    },
  );

  test('Detail app bar keeps light system chrome in dark mode', () {
    final theme = AppTheme.dark;
    final style = DetailAppBarStyle.fromTheme(theme, isCollapsed: true);

    expect(style.foregroundColor, theme.colorScheme.onSurface);
    expect(style.systemOverlayStyle.statusBarIconBrightness, Brightness.light);
  });

  // S07: 상세 화면 액션 — 위시리스트 토글·삭제 후 pop(true)
  group('S07 DetailScreen actions', () {
    late FakeAlbumRepository repository;

    Future<void> openDetail(
      WidgetTester tester,
      Album album, {
      void Function(Object?)? onResult,
    }) async {
      await tester.pumpWidget(
        Provider<IAlbumRepository>.value(
          value: repository,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailScreen(album: album),
                      ),
                    );
                    onResult?.call(result);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('위시리스트 토글이 저장소에 반영된다', (tester) async {
      final album = Album(
        id: 'd1',
        title: 'Detail Album',
        artists: const ['Detail Artist'],
      );
      repository = FakeAlbumRepository(albums: [album]);
      await openDetail(tester, album);

      await tester.tap(find.byTooltip('위시리스트에 추가'));
      await tester.pumpAndSettle();

      final stored = (await repository.getAll()).single;
      expect(stored.isWishlist, isTrue);
      expect(find.byTooltip('위시리스트에서 제거'), findsOneWidget);
      expect(find.text('앨범을 위시리스트로 옮겼습니다.'), findsOneWidget);
    });

    testWidgets('삭제 확인 시 앨범이 삭제되고 true로 pop된다', (tester) async {
      final album = Album(
        id: 'd2',
        title: 'Delete Album',
        artists: const ['Delete Artist'],
      );
      repository = FakeAlbumRepository(albums: [album]);

      bool? popResult;
      await openDetail(tester, album, onResult: (r) => popResult = r as bool?);

      await tester.tap(find.byTooltip('앨범 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();

      expect(popResult, isTrue);
      expect(await repository.getAll(), isEmpty);
      expect(find.byType(DetailScreen), findsNothing);
    });

    testWidgets('삭제 취소 시 앨범이 유지된다', (tester) async {
      final album = Album(
        id: 'd3',
        title: 'Keep Album',
        artists: const ['Keep Artist'],
      );
      repository = FakeAlbumRepository(albums: [album]);
      await openDetail(tester, album);

      await tester.tap(find.byTooltip('앨범 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '취소'));
      await tester.pumpAndSettle();

      expect(await repository.getAll(), hasLength(1));
      expect(find.byType(DetailScreen), findsOneWidget);
    });

    testWidgets('커버 탭 시 풀스크린 뷰어가 열리고 탭으로 닫힌다', (tester) async {
      // testWidgets의 fakeAsync 존에서는 실제 dart:io Future의 완료 콜백이
      // pump 없이 전달되지 않아 교착되므로, 파일 준비는 runAsync 안에서 수행한다.
      final tempDir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('cover-viewer-test'),
      );
      final imagePath = '${tempDir!.path}/cover.png';
      await tester.runAsync(
        () => File(imagePath).writeAsBytes(_onePixelPngBytes),
      );
      addTearDown(() async {
        clearFileExistsCache();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final album = Album(
        id: 'd4',
        title: 'Cover Album',
        artists: const ['Cover Artist'],
        imagePath: imagePath,
      );
      repository = FakeAlbumRepository(albums: [album]);
      await openDetail(tester, album);

      // Hero로 감싼 커버 이미지를 탭하면 풀스크린 뷰어가 열린다
      await tester.tap(find.byType(Hero));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);

      // 뷰어를 탭하면 닫히고 상세 화면으로 돌아간다
      await tester.tapAt(tester.getCenter(find.byType(Scaffold).last));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.byType(DetailScreen), findsOneWidget);
    });
  });
}

// 디코딩 가능한 1x1 PNG (Image.file 실제 디코드 경로를 타게 하기 위해 필요)
final List<int> _onePixelPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
);
