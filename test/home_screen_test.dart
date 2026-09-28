import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/screens/home_screen.dart';
import 'package:my_album_app/services/i_album_repository.dart';
import 'package:my_album_app/viewmodels/home_viewmodel.dart';

import 'fakes.dart';

void main() {
  // S01: 홈 컬렉션/위시리스트 전환·검색·정렬 / S02: 보기 모드 순환·재정렬
  group('S01·S02 HomeScreen', () {
    late FakeAlbumRepository repository;
    late HomeViewModel viewModel;

    Future<void> openHome(WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<IAlbumRepository>.value(value: repository),
            ChangeNotifierProvider<HomeViewModel>.value(value: viewModel),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    Offset topLeftOf(WidgetTester tester, String title) =>
        tester.getTopLeft(find.text(title));

    testWidgets('S01 세그먼트 전환으로 컬렉션/위시리스트 목록이 교체된다', (tester) async {
      repository = FakeAlbumRepository(
        albums: [
          Album(id: 'c1', title: 'Coll Album', artists: const ['A']),
          Album(
            id: 'w1',
            title: 'Wish Album',
            artists: const ['B'],
            isWishlist: true,
          ),
        ],
      );
      viewModel = HomeViewModel(repository);
      await openHome(tester);

      expect(viewModel.currentView, AlbumView.collection);
      expect(find.text('Coll Album'), findsOneWidget);
      expect(find.text('Wish Album'), findsNothing);

      await tester.tap(find.text('위시리스트'));
      await tester.pumpAndSettle();

      expect(viewModel.currentView, AlbumView.wishlist);
      expect(find.text('Wish Album'), findsOneWidget);
      expect(find.text('Coll Album'), findsNothing);
    });

    testWidgets('S01 검색어 입력이 앨범 카드를 필터링한다', (tester) async {
      repository = FakeAlbumRepository(
        albums: [
          Album(id: 's1', title: 'Alpha Song', artists: const ['A']),
          Album(id: 's2', title: 'Beta Beat', artists: const ['B']),
        ],
      );
      viewModel = HomeViewModel(repository);
      await openHome(tester);

      await tester.tap(find.byTooltip('검색'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoSearchTextField), findsOneWidget);

      await tester.enterText(find.byType(CupertinoSearchTextField), 'alpha');
      await tester.pumpAndSettle();

      expect(find.text('Alpha Song'), findsOneWidget);
      expect(find.text('Beta Beat'), findsNothing);
    });

    testWidgets('S01 한국어 제목(titleKr)으로도 검색된다', (tester) async {
      repository = FakeAlbumRepository(
        albums: [
          Album(id: 's1', title: 'Neon', titleKr: '네온', artists: const ['A']),
          Album(id: 's2', title: 'Beta Beat', artists: const ['B']),
        ],
      );
      viewModel = HomeViewModel(repository);
      await openHome(tester);

      await tester.tap(find.byTooltip('검색'));
      await tester.pumpAndSettle();

      // 표시 문자열은 영문 title이지만 검색은 titleKr로도 매칭되어야 한다
      await tester.enterText(find.byType(CupertinoSearchTextField), '네온');
      await tester.pumpAndSettle();

      expect(find.text('Neon'), findsOneWidget);
      expect(find.text('Beta Beat'), findsNothing);
    });

    testWidgets('S01 정렬 옵션 변경이 그리드 내 앨범 순서를 바꾼다', (tester) async {
      // 작은 휴대폰에서도 정렬 시트의 마지막 항목까지 접근 가능해야 한다.
      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      repository = FakeAlbumRepository(
        albums: [
          Album(id: 'z', title: 'Zebra', artists: const ['A']),
          Album(id: 'a', title: 'Apple', artists: const ['B']),
        ],
      );
      viewModel = HomeViewModel(repository);
      await openHome(tester);

      // 사용자 지정(입력 순서) 상태에서는 Zebra가 Apple보다 왼쪽에 있다
      expect(viewModel.sortOption, SortOption.custom);
      expect(
        topLeftOf(tester, 'Zebra').dx < topLeftOf(tester, 'Apple').dx,
        isTrue,
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('정렬'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('앨범명'));
      await tester.tap(find.text('앨범명'));
      await tester.pumpAndSettle();

      expect(viewModel.sortOption, SortOption.title);
      expect(
        topLeftOf(tester, 'Apple').dx < topLeftOf(tester, 'Zebra').dx,
        isTrue,
      );
    });

    testWidgets('S02 보기 모드 버튼이 grid2→grid3→artists로 순환한다', (tester) async {
      repository = FakeAlbumRepository(
        albums: [
          Album(id: 'v1', title: 'View One', artists: const ['Singer A']),
          Album(id: 'v2', title: 'View Two', artists: const ['Singer B']),
        ],
      );
      viewModel = HomeViewModel(repository);
      await openHome(tester);

      expect(viewModel.viewMode, ViewMode.grid2);
      expect(find.byType(GridView), findsWidgets);

      await tester.tap(find.byTooltip('3열 그리드로 보기'));
      await tester.pumpAndSettle();
      expect(viewModel.viewMode, ViewMode.grid3);

      await tester.tap(find.byTooltip('아티스트 목록으로 보기'));
      await tester.pumpAndSettle();
      expect(viewModel.viewMode, ViewMode.artists);
      // 아티스트 뷰는 이름순 ListTile 목록이다
      expect(find.text('Singer A'), findsOneWidget);
      expect(find.text('앨범 1장'), findsNWidgets(2));

      await tester.tap(find.byTooltip('2열 그리드로 보기'));
      await tester.pumpAndSettle();
      expect(viewModel.viewMode, ViewMode.grid2);
      expect(find.text('View One'), findsOneWidget);
    });

    testWidgets('S02 앨범 카드가 스크린리더에 탭·롱프레스 가능한 버튼으로 노출된다', (tester) async {
      // _endOfTestVerifications이 addTearDown보다 먼저 실행되므로 본문에서 해제한다
      final semanticsHandle = tester.ensureSemantics();

      repository = FakeAlbumRepository(
        albums: [
          Album(id: 's1', title: 'Alpha Song', artists: const ['Singer A']),
        ],
      );
      viewModel = HomeViewModel(repository);
      await openHome(tester);

      // 버튼 역할만 선언하고 액션이 없으면 TalkBack 활성화가 동작하지 않는다
      expect(
        tester.getSemantics(find.bySemanticsLabel('Alpha Song, Singer A 앨범')),
        matchesSemantics(
          label: 'Alpha Song, Singer A 앨범',
          isButton: true,
          hasTapAction: true,
          hasLongPressAction: true,
        ),
      );

      semanticsHandle.dispose();
    });

    testWidgets('S02 재정렬 모드 진입 시 사용자 지정 정렬이 강제된다', (tester) async {
      repository = FakeAlbumRepository(
        albums: [
          Album(id: 'r1', title: 'Reorder A', artists: const ['A']),
          Album(id: 'r2', title: 'Reorder B', artists: const ['B']),
        ],
      );
      viewModel = HomeViewModel(repository)..setSortOption(SortOption.title);
      await openHome(tester);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('순서 변경'));
      await tester.pumpAndSettle();

      expect(viewModel.isReorderMode, isTrue);
      expect(viewModel.sortOption, SortOption.custom);
      expect(find.byType(ReorderableGridView), findsOneWidget);
    });

    test('S02 필터된 보기의 재정렬이 저장소의 실제 인덱스로 매핑된다', () async {
      final repo = FakeAlbumRepository(
        albums: [
          Album(id: 'a', title: 'Match A', artists: const ['X']),
          Album(id: 'b', title: 'Other B', artists: const ['X']),
          Album(id: 'c', title: 'Match C', artists: const ['X']),
          Album(id: 'd', title: 'Other D', artists: const ['X']),
        ],
      );
      final vm = HomeViewModel(repo);
      await vm.loadAlbums();

      // 검색 필터로 보이는 목록이 [Match A, Match C]로 좁혀진 상태
      vm.setSearchQuery('match');
      vm.reorderInView(0, 1, AlbumView.collection);
      // repository.reorder가 완료되면 낙관적 순서와 저장소 순서가 일치해야 한다
      await vm.loadAlbums();

      expect(repo.albums.map((a) => a.id), <String>['b', 'c', 'a', 'd']);
      expect(
        vm.getAlbumsForView(AlbumView.collection).map((a) => a.id),
        <String>['c', 'a'],
      );
    });
  });
}
