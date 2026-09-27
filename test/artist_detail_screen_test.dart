import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:provider/provider.dart';

import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/models/artist.dart';
import 'package:my_album_app/models/value_objects/release_date.dart';
import 'package:my_album_app/screens/artist_detail_screen.dart';
import 'package:my_album_app/screens/detail_screen.dart';
import 'package:my_album_app/services/i_album_repository.dart';
import 'package:my_album_app/viewmodels/artist_viewmodel.dart';
import 'package:my_album_app/viewmodels/global_artist_settings.dart';
import 'package:my_album_app/utils/theme.dart';

import 'fakes.dart';

void main() {
  // S08: 아티스트 화면 — alias/groups 저장, 이미지 변경, 발매일 정렬 토글, source album 강조
  group('S08 ArtistDetailScreen', () {
    late FakeAlbumRepository repository;
    late GlobalArtistSettings settings;
    ImagePickerPlatform? originalImagePicker;

    setUp(() {
      settings = GlobalArtistSettings();
      originalImagePicker = ImagePickerPlatform.instance;
    });

    tearDown(() {
      if (originalImagePicker != null) {
        ImagePickerPlatform.instance = originalImagePicker!;
      }
    });

    Future<void> openArtist(
      WidgetTester tester, {
      required String artistName,
      String? sourceAlbumId,
      ThemeData? theme,
    }) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<IAlbumRepository>.value(value: repository),
            ChangeNotifierProvider<GlobalArtistSettings>.value(
              value: settings,
            ),
          ],
          child: MaterialApp(
            theme: theme,
            home: ArtistDetailScreen(
              artistName: artistName,
              sourceAlbumId: sourceAlbumId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('다크 아티스트 화면은 공통 회색 배경을 사용한다', (tester) async {
      repository = FakeAlbumRepository(artists: [Artist(name: 'Artist Gray')]);
      await openArtist(tester, artistName: 'Artist Gray', theme: AppTheme.dark);

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppTheme.dark.scaffoldBackgroundColor,
      );
      expect(
        tester.widget<SliverAppBar>(find.byType(SliverAppBar)).backgroundColor,
        AppTheme.dark.scaffoldBackgroundColor,
      );
    });

    testWidgets('S08 편집 다이얼로그에서 별명과 그룹을 저장해 정보 섹션에 반영한다', (
      tester,
    ) async {
      repository = FakeAlbumRepository(
        artists: [Artist(name: 'Yorushika')],
        albums: [
          Album(id: 'a1', title: 'That Sound', artists: const ['Yorushika']),
        ],
      );
      await openArtist(tester, artistName: 'Yorushika');

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      expect(find.text('아티스트 정보 편집'), findsOneWidget);

      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == '배리에이션 (별명)',
        ),
        'ヨルシカ, Yorushika JP',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == '그룹 추가',
        ),
        'Suis',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
      await tester.pumpAndSettle();

      final saved = repository.getArtistByName('Yorushika');
      expect(saved?.aliases, <String>['ヨルシカ', 'Yorushika JP']);
      expect(saved?.groups, <String>['Suis']);

      // 정보 섹션에 별명·그룹이 표시된다
      expect(find.text('배리에이션'), findsOneWidget);
      expect(find.text('그룹 내'), findsOneWidget);
      expect(find.text('ヨルシカ'), findsOneWidget);
      expect(find.text('Suis'), findsOneWidget);
    });

    testWidgets('S08 발매일 정렬 토글이 앨범 나열 순서를 뒤집는다', (tester) async {
      repository = FakeAlbumRepository(
        artists: [Artist(name: 'Artist A')],
        albums: [
          Album(
            id: 'old',
            title: 'Old Album',
            artists: const ['Artist A'],
            releaseDate: ReleaseDate(DateTime(2015, 3, 1)),
          ),
          Album(
            id: 'new',
            title: 'New Album',
            artists: const ['Artist A'],
            releaseDate: ReleaseDate(DateTime(2023, 7, 15)),
          ),
        ],
      );
      await openArtist(tester, artistName: 'Artist A');

      // 기본값은 최신순(desc): New가 Old보다 위에 있다
      expect(settings.sortOrder, SortOrder.desc);
      expect(
        tester.getTopLeft(find.text('New Album')).dy <
            tester.getTopLeft(find.text('Old Album')).dy,
        isTrue,
      );

      await tester.tap(find.byIcon(Icons.arrow_downward));
      await tester.pumpAndSettle();

      expect(settings.sortOrder, SortOrder.asc);
      expect(
        tester.getTopLeft(find.text('Old Album')).dy <
            tester.getTopLeft(find.text('New Album')).dy,
        isTrue,
      );
    });

    testWidgets('S08 출처 앨범에 배지가 붙고 탭해도 이동하지 않는다', (tester) async {
      repository = FakeAlbumRepository(
        artists: [Artist(name: 'Artist B')],
        albums: [
          Album(id: 'src', title: 'Source Album', artists: const ['Artist B']),
          Album(id: 'other', title: 'Other Album', artists: const ['Artist B']),
        ],
      );
      await openArtist(tester, artistName: 'Artist B', sourceAlbumId: 'src');

      expect(find.text('현재 보고 있는 앨범'), findsOneWidget);

      await tester.tap(find.text('Source Album'));
      await tester.pumpAndSettle();

      expect(find.byType(ArtistDetailScreen), findsOneWidget);
      expect(find.byType(DetailScreen), findsNothing);
    });

    testWidgets('S08 갤러리에서 고른 이미지 경로가 아티스트에 저장된다', (tester) async {
      const pickedPath = 'C:/tmp/artist_pick.png';
      ImagePickerPlatform.instance = FakeImagePickerPlatform(
        result: XFile(pickedPath),
      );
      repository = FakeAlbumRepository(artists: [Artist(name: 'Artist C')]);
      await openArtist(tester, artistName: 'Artist C');

      await tester.tap(find.text('이미지 변경'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('갤러리에서 선택'));
      await tester.pumpAndSettle();

      expect(repository.getArtistByName('Artist C')?.imagePath, pickedPath);
    });

    testWidgets('S08 이미지 삭제 시 저장된 경로가 지워진다', (tester) async {
      repository = FakeAlbumRepository(
        artists: [
          Artist(name: 'Artist D', imagePath: 'C:/tmp/existing.png'),
        ],
      );
      await openArtist(tester, artistName: 'Artist D');

      await tester.tap(find.text('이미지 변경'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이미지 삭제'));
      await tester.pumpAndSettle();

      expect(repository.getArtistByName('Artist D')?.imagePath, isNull);
    });
  });
}
