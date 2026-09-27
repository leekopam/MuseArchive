import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/models/track.dart';
import 'package:my_album_app/screens/all_songs_screen.dart';

import 'fakes.dart';

// S09: 곡 목록 평탄화·검색·위시리스트 필터·그룹화
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('S09 AllSongsScreen', () {
    late FakeAlbumRepository repository;

    Future<void> pumpSongs(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AllSongsScreen(repository: repository)),
      );
      // 로딩 shimmer가 무한 애니메이션이라 pumpAndSettle 대신 고정 프레임 사용
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('헤더 트랙은 제외하고 곡만 평탄화된다', (tester) async {
      repository = FakeAlbumRepository(
        albums: [
          Album(
            id: 'a1',
            title: 'Album One',
            artists: const ['Artist One'],
            tracks: [
              Track(id: 't1', title: 'First Song'),
              Track(id: 'h1', title: 'Disc 2', isHeader: true),
              Track(id: 't2', title: 'Second Song'),
            ],
          ),
        ],
      );
      await pumpSongs(tester);

      expect(find.text('First Song'), findsOneWidget);
      expect(find.text('Second Song'), findsOneWidget);
      expect(find.text('Disc 2'), findsNothing);
    });

    testWidgets('위시리스트 곡은 토글을 켜야 표시된다', (tester) async {
      repository = FakeAlbumRepository(
        albums: [
          Album(
            id: 'a2',
            title: 'Wish Album',
            artists: const ['Wish Artist'],
            isWishlist: true,
            tracks: [Track(id: 'w1', title: 'Wish Song')],
          ),
          Album(
            id: 'a3',
            title: 'Owned Album',
            artists: const ['Owned Artist'],
            tracks: [Track(id: 'o1', title: 'Owned Song')],
          ),
        ],
      );
      await pumpSongs(tester);

      expect(find.text('Wish Song'), findsNothing);
      expect(find.text('Owned Song'), findsOneWidget);

      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Wish Song'), findsOneWidget);
      expect(find.text('Owned Song'), findsOneWidget);
    });

    testWidgets('검색어로 곡 제목과 아티스트를 필터링한다', (tester) async {
      repository = FakeAlbumRepository(
        albums: [
          Album(
            id: 'a4',
            title: 'Search Album',
            artists: const ['Search Artist'],
            tracks: [
              Track(id: 's1', title: 'Morning Light'),
              Track(id: 's2', title: 'Evening Rain'),
            ],
          ),
        ],
      );
      await pumpSongs(tester);

      await tester.enterText(find.byType(CupertinoSearchTextField), 'morning');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Morning Light'), findsOneWidget);
      expect(find.text('Evening Rain'), findsNothing);

      await tester.enterText(
        find.byType(CupertinoSearchTextField),
        'search artist',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Morning Light'), findsOneWidget);
      expect(find.text('Evening Rain'), findsOneWidget);
    });

    testWidgets('같은 곡이 여러 앨범에 있으면 그룹으로 표시된다', (tester) async {
      repository = FakeAlbumRepository(
        albums: [
          Album(
            id: 'g1',
            title: 'Single Edition',
            artists: const ['Same Artist'],
            tracks: [Track(id: 'g1t', title: 'Duplicate Song')],
          ),
          Album(
            id: 'g2',
            title: 'Deluxe Edition',
            artists: const ['Same Artist'],
            tracks: [Track(id: 'g2t', title: 'Duplicate Song')],
          ),
        ],
      );
      await pumpSongs(tester);

      expect(find.text('Same Artist · 2개 앨범 수록'), findsOneWidget);
      // 그룹 항목은 하나 — 곡이 두 줄로 나열되지 않는다
      expect(find.text('Duplicate Song'), findsOneWidget);
    });

    testWidgets('곡 항목은 라벨 없는 중복 버튼 노드를 노출하지 않는다', (tester) async {
      repository = FakeAlbumRepository(
        albums: [
          Album(
            id: 'a1',
            title: 'Album One',
            artists: const ['Artist One'],
            tracks: [Track(id: 't1', title: 'First Song')],
          ),
          Album(
            id: 'g1',
            title: 'Single Edition',
            artists: const ['Same Artist'],
            tracks: [Track(id: 'g1t', title: 'Duplicate Song')],
          ),
          Album(
            id: 'g2',
            title: 'Deluxe Edition',
            artists: const ['Same Artist'],
            tracks: [Track(id: 'g2t', title: 'Duplicate Song')],
          ),
        ],
      );
      await pumpSongs(tester);
      final handle = tester.ensureSemantics();
      await tester.pump();

      // 라벨이 붙은 노드는 각각 하나씩 존재해야 한다
      expect(find.bySemanticsLabel('First Song, Artist One'), findsOneWidget);
      expect(find.bySemanticsLabel('곡 옵션 열기'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Duplicate Song, Same Artist, 2개 앨범 수록'),
        findsOneWidget,
      );

      // 중첩된 시각 버튼이 라벨 없는 중복 포커스 노드를 만들면 안 된다
      var unlabeledButtons = 0;
      void walk(SemanticsNode node) {
        final data = node.getSemanticsData();
        if (data.flagsCollection.isButton && data.label.isEmpty) {
          unlabeledButtons++;
        }
        node.visitChildren((SemanticsNode child) {
          walk(child);
          return true;
        });
      }

      for (final label in [
        'First Song, Artist One',
        '곡 옵션 열기',
        'Duplicate Song, Same Artist, 2개 앨범 수록',
      ]) {
        walk(tester.getSemantics(find.bySemanticsLabel(label)));
      }
      expect(unlabeledButtons, 0);
      handle.dispose();
    });
  });
}
