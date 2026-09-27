import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/models/track.dart';
import 'package:my_album_app/models/value_objects/release_date.dart';
import 'package:my_album_app/screens/all_songs_screen.dart';
import 'package:my_album_app/screens/detail_screen.dart';
import 'package:my_album_app/screens/home_screen.dart';
import 'package:my_album_app/services/i_album_repository.dart';
import 'package:my_album_app/viewmodels/home_viewmodel.dart';

import 'fakes.dart';

// 텍스트 확대(textScaler 2.0x)에서 주요 화면이 오버플로우 없이 렌더링되는지 점검한다.
// RenderFlex 오버플로우는 테스트에서 FlutterError로 보고되어 실패로 드러난다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAlbumRepository repository;

  Album stressAlbum() => Album(
    id: 'a1',
    title: 'A Deliberately Very Long Album Title Used To Stress Text Layout',
    artists: const ['An Equally Long Artist Name For Layout Stress Testing'],
    genres: const ['Progressive Rock'],
    releaseDate: ReleaseDate(DateTime(2024)),
    tracks: [
      Track(
        id: 't1',
        title: 'A Long Song Title That Should Ellipsize Cleanly In Rows',
      ),
      Track(id: 't2', title: 'Another Long Song Title For The List Rows'),
    ],
  );

  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  // builder의 MediaQuery는 Navigator 상위를 감싸므로 화면 전체에 적용된다
  Widget app(Widget home, {HomeViewModel? viewModel}) {
    return MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2.0)),
        child: child!,
      ),
      home: MultiProvider(
        providers: [
          Provider<IAlbumRepository>.value(value: repository),
          if (viewModel != null)
            ChangeNotifierProvider<HomeViewModel>.value(value: viewModel),
        ],
        child: home,
      ),
    );
  }

  testWidgets('홈 그리드가 텍스트 2.0x에서 오버플로우 없이 렌더링된다', (tester) async {
    repository = FakeAlbumRepository(albums: [stressAlbum()]);
    final viewModel = HomeViewModel(repository);
    addTearDown(viewModel.dispose);
    usePhoneViewport(tester);

    await tester.pumpWidget(app(const HomeScreen(), viewModel: viewModel));
    await tester.pumpAndSettle();

    expect(find.text('MuseArchive'), findsOneWidget);
    expect(
      find.textContaining('A Deliberately Very Long Album Title'),
      findsOneWidget,
    );
  });

  testWidgets('홈 아티스트 목록이 텍스트 2.0x에서 오버플로우 없다', (tester) async {
    repository = FakeAlbumRepository(albums: [stressAlbum()]);
    final viewModel = HomeViewModel(repository);
    addTearDown(viewModel.dispose);
    viewModel.setViewMode(ViewMode.artists);
    usePhoneViewport(tester);

    await tester.pumpWidget(app(const HomeScreen(), viewModel: viewModel));
    await tester.pumpAndSettle();

    expect(
      find.text('An Equally Long Artist Name For Layout Stress Testing'),
      findsOneWidget,
    );
    expect(find.text('앨범 1장'), findsOneWidget);
  });

  testWidgets('모든 곡 목록이 텍스트 2.0x에서 오버플로우 없다', (tester) async {
    repository = FakeAlbumRepository(albums: [stressAlbum()]);
    usePhoneViewport(tester);

    await tester.pumpWidget(app(AllSongsScreen(repository: repository)));
    // 로딩 shimmer가 무한 애니메이션이라 고정 프레임으로 대기한다
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('A Long Song Title'), findsWidgets);
  });

  testWidgets('상세 화면이 텍스트 2.0x에서 오버플로우 없다', (tester) async {
    final album = stressAlbum();
    repository = FakeAlbumRepository(albums: [album]);
    usePhoneViewport(tester);

    await tester.pumpWidget(app(DetailScreen(album: album)));
    await tester.pumpAndSettle();

    expect(find.byType(DetailScreen), findsOneWidget);
  });
}
