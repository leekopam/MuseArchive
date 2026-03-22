import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/models/artist.dart';
import 'package:my_album_app/screens/add_screen.dart';
import 'package:my_album_app/services/discogs_service.dart';
import 'package:my_album_app/services/i_album_repository.dart';
import 'package:my_album_app/services/musicbrainz_service.dart';
import 'package:my_album_app/services/spotify_service.dart';
import 'package:my_album_app/services/vocadb_service.dart';
import 'package:my_album_app/viewmodels/album_form_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AddScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('autosaves a new album after title and artist are entered', (
      WidgetTester tester,
    ) async {
      final repository = _FakeAlbumRepository();

      await tester.pumpWidget(
        _buildAddScreenApp(repository: repository, child: const AddScreen()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Unhappy Refrain',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'wowaka');
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(repository.addCalls, 1);
      expect(repository.lastAddedAlbum?.title, 'Unhappy Refrain');
      expect(repository.lastAddedAlbum?.artists, <String>['wowaka']);
    });

    testWidgets('does not autosave while required artist is missing', (
      WidgetTester tester,
    ) async {
      final repository = _FakeAlbumRepository();

      await tester.pumpWidget(
        _buildAddScreenApp(repository: repository, child: const AddScreen()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Only Title');
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(repository.addCalls, 0);
      expect(repository.updateCalls, 0);
    });

    testWidgets(
      'autosaves edits through repository.update for existing albums',
      (WidgetTester tester) async {
        final repository = _FakeAlbumRepository();
        final existingAlbum = Album(
          id: 'album-1',
          title: 'Old Title',
          artists: const <String>['wowaka'],
        );

        await tester.pumpWidget(
          _buildAddScreenApp(
            repository: repository,
            child: AddScreen(albumToEdit: existingAlbum),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).at(0), 'New Title');
        await tester.pump(const Duration(milliseconds: 1100));
        await tester.pumpAndSettle();

        expect(repository.updateCalls, 1);
        expect(repository.lastUpdatedAlbumId, 'album-1');
        expect(repository.lastUpdatedAlbum?.title, 'New Title');
        expect(repository.addCalls, 0);
      },
    );

    testWidgets('back navigation saves pending valid input before popping', (
      WidgetTester tester,
    ) async {
      final repository = _FakeAlbumRepository();

      await tester.pumpWidget(
        _buildAddScreenLauncherApp(
          repository: repository,
          child: const AddScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open AddScreen'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'World 0123456789',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'sasakure.UK');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(repository.addCalls, 1);
      expect(find.text('Open AddScreen'), findsOneWidget);
    });

    testWidgets(
      'back navigation skips saving when required fields are missing',
      (WidgetTester tester) async {
        final repository = _FakeAlbumRepository();

        await tester.pumpWidget(
          _buildAddScreenLauncherApp(
            repository: repository,
            child: const AddScreen(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open AddScreen'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).at(0), 'Only Title');

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(repository.addCalls, 0);
        expect(repository.updateCalls, 0);
        expect(find.text('Open AddScreen'), findsOneWidget);
      },
    );

    testWidgets('searches and autosaves when barcode scan returns a value', (
      WidgetTester tester,
    ) async {
      final repository = _FakeAlbumRepository();
      final viewModel = _FakeAlbumFormViewModel(
        repository: repository,
        barcodeAlbumResult: Album(
          title: 'Barcode Album',
          artists: const <String>['Barcode Artist'],
        ),
      );

      await tester.pumpWidget(
        _buildAddScreenApp(
          repository: repository,
          viewModel: viewModel,
          child: AddScreen(barcodeScan: () async => '8801234567890'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(viewModel.barcodeSearchCalls, 1);
      expect(viewModel.lastBarcodeQuery, '8801234567890');
      expect(repository.addCalls, 1);
      expect(repository.lastAddedAlbum?.title, 'Barcode Album');
      expect(repository.lastAddedAlbum?.artists, const <String>[
        'Barcode Artist',
      ]);
    });

    testWidgets('does nothing when barcode scan is cancelled', (
      WidgetTester tester,
    ) async {
      final repository = _FakeAlbumRepository();
      final viewModel = _FakeAlbumFormViewModel(repository: repository);

      await tester.pumpWidget(
        _buildAddScreenApp(
          repository: repository,
          viewModel: viewModel,
          child: AddScreen(barcodeScan: () async => null),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pumpAndSettle();

      expect(viewModel.barcodeSearchCalls, 0);
      expect(repository.addCalls, 0);
      expect(repository.updateCalls, 0);
    });

    testWidgets('shows guidance when Spotify link search is not configured', (
      WidgetTester tester,
    ) async {
      final repository = _FakeAlbumRepository();
      final viewModel = _FakeAlbumFormViewModel(
        repository: repository,
        spotifyConfigured: false,
      );

      await tester.pumpWidget(
        _buildAddScreenApp(
          repository: repository,
          viewModel: viewModel,
          child: const AddScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final spotifyLinkSearch = find.byTooltip('Spotify에서 링크 검색');
      await tester.scrollUntilVisible(
        spotifyLinkSearch.first,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(spotifyLinkSearch.first);
      await tester.pumpAndSettle();

      expect(find.text('설정에서 Spotify 키를 입력해주세요.'), findsOneWidget);
      expect(viewModel.spotifySearchCalls, 0);
    });

    testWidgets('applies a Spotify link from search results and autosaves it', (
      WidgetTester tester,
    ) async {
      final repository = _FakeAlbumRepository();
      final existingAlbum = Album(
        id: 'album-spotify',
        title: 'Unhappy Refrain',
        artists: const <String>['wowaka'],
      );
      final viewModel = _FakeAlbumFormViewModel(
        repository: repository,
        spotifyConfigured: true,
        spotifyResults: <Map<String, String>>[
          <String, String>{
            'title': 'Unhappy Refrain',
            'artist': 'wowaka',
            'release_date': '2011-05-18',
            'external_url': 'https://open.spotify.com/album/unhappy-refrain',
            'image_url': '',
          },
        ],
      );

      await tester.pumpWidget(
        _buildAddScreenApp(
          repository: repository,
          viewModel: viewModel,
          child: AddScreen(albumToEdit: existingAlbum),
        ),
      );
      await tester.pumpAndSettle();

      final spotifyLinkSearch = find.byTooltip('Spotify에서 링크 검색');
      await tester.scrollUntilVisible(
        spotifyLinkSearch.first,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(spotifyLinkSearch.first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, '검색'));
      await tester.pumpAndSettle();

      expect(viewModel.lastSpotifyQuery, 'Unhappy Refrain');
      expect(find.text('Spotify 링크 검색 결과'), findsOneWidget);

      final spotifyResultTitle = find.text('Unhappy Refrain').last;
      await tester.ensureVisible(spotifyResultTitle);
      await tester.tap(spotifyResultTitle);
      await tester.pump();

      expect(find.text('Spotify 링크가 적용되었습니다.'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);
      expect(
        repository.lastUpdatedAlbum?.linkUrl,
        'https://open.spotify.com/album/unhappy-refrain',
      );
    });

    testWidgets('saves a picked gallery image for an existing album', (
      WidgetTester tester,
    ) async {
      final repository = _FakeAlbumRepository();
      final existingAlbum = Album(
        id: 'album-image',
        title: 'Sandbox',
        artists: const <String>['DECO*27'],
      );
      final viewModel = _FakeAlbumFormViewModel(
        repository: repository,
        pickedImagePath: r'C:\tmp\picked_cover.png',
      );

      await tester.pumpWidget(
        _buildAddScreenApp(
          repository: repository,
          viewModel: viewModel,
          child: AddScreen(albumToEdit: existingAlbum),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 보관함에서 선택'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(viewModel.pickImageCalls, 1);
      expect(repository.updateCalls, 1);
      expect(
        repository.lastUpdatedAlbum?.imagePath,
        r'C:\tmp\picked_cover.png',
      );
    });

    testWidgets(
      'prefills the Discogs search dialog and trims submitted query values',
      (WidgetTester tester) async {
        final repository = _FakeAlbumRepository();
        final existingAlbum = Album(
          id: 'album-discogs-prefill',
          title: '  Unhappy Refrain  ',
          artists: const <String>['  wowaka  '],
        );
        final viewModel = _FakeAlbumFormViewModel(
          repository: repository,
          discogsSearchResults: const <Map<String, dynamic>>[],
        );

        await tester.pumpWidget(
          _buildAddScreenApp(
            repository: repository,
            viewModel: viewModel,
            child: AddScreen(albumToEdit: existingAlbum),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Discogs에서 검색'));
        await tester.pumpAndSettle();

        final discogsFields = tester
            .widgetList<TextField>(find.byType(TextField))
            .toList();
        final prefilledTexts = discogsFields
            .map((field) => field.controller?.text ?? '')
            .toList();
        expect(prefilledTexts, contains('  wowaka  '));
        expect(prefilledTexts, contains('  Unhappy Refrain  '));

        await tester.tap(find.widgetWithText(ElevatedButton, '검색'));
        await tester.pumpAndSettle();

        expect(viewModel.discogsSearchCalls, 1);
        expect(viewModel.lastDiscogsArtist, 'wowaka');
        expect(viewModel.lastDiscogsTitle, 'Unhappy Refrain');
        expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
      },
    );

    testWidgets('loads and autosaves the selected Discogs search result', (
      WidgetTester tester,
    ) async {
      final repository = _FakeAlbumRepository();
      final existingAlbum = Album(
        id: 'album-discogs-load',
        title: 'Before Search',
        artists: const <String>['Before Artist'],
      );
      final loadedAlbum = existingAlbum.copyWith(
        title: 'Loaded Album',
        artists: const <String>['Loaded Artist'],
      );
      final viewModel = _FakeAlbumFormViewModel(
        repository: repository,
        discogsSearchResults: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 123,
            'title': 'Loaded Album',
            'artist': 'Loaded Artist',
            'year': '2024',
            'format': 'CD',
            'thumb': '',
          },
        ],
        loadedAlbumResult: loadedAlbum,
      );

      await tester.pumpWidget(
        _buildAddScreenApp(
          repository: repository,
          viewModel: viewModel,
          child: AddScreen(albumToEdit: existingAlbum),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Discogs에서 검색'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '검색'));
      await tester.pumpAndSettle();

      expect(viewModel.discogsSearchCalls, 1);
      expect(find.text('Loaded Album'), findsWidgets);

      final loadedResultTitle = find.text('Loaded Album').last;
      await tester.ensureVisible(loadedResultTitle);
      await tester.tap(loadedResultTitle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(viewModel.loadAlbumByIdCalls, 1);
      expect(viewModel.lastLoadedReleaseId, 123);
      expect(repository.updateCalls, 1);
      expect(repository.lastUpdatedAlbum?.title, 'Loaded Album');
      expect(repository.lastUpdatedAlbum?.artists, const <String>[
        'Loaded Artist',
      ]);
    });

    testWidgets('applies a Discogs image search result and autosaves it', (
      WidgetTester tester,
    ) async {
      final repository = _FakeAlbumRepository();
      final existingAlbum = Album(
        id: 'album-discogs-image',
        title: 'Sand Planet',
        artists: const <String>['hachi'],
      );
      final viewModel = _FakeAlbumFormViewModel(
        repository: repository,
        discogsSearchResults: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 77,
            'title': 'Sand Planet',
            'artist': 'hachi',
            'year': '2017',
            'format': 'CD',
            'thumb': 'https://example.com/discogs-cover.jpg',
          },
        ],
        discogsCoverResultPath: r'C:\tmp\discogs_cover.png',
      );

      await tester.pumpWidget(
        _buildAddScreenApp(
          repository: repository,
          viewModel: viewModel,
          child: AddScreen(albumToEdit: existingAlbum),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discogs에서 검색').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '검색'));
      await tester.pump();

      expect(find.text('이미지 선택'), findsOneWidget);

      final imageChoice = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(InkWell),
      );
      await tester.tap(imageChoice.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(viewModel.discogsSearchCalls, 1);
      expect(viewModel.lastDiscogsTitle, 'Sand Planet');
      expect(viewModel.updateCoverFromUrlCalls, 1);
      expect(viewModel.lastCoverUrl, 'https://example.com/discogs-cover.jpg');
      expect(repository.updateCalls, 1);
      expect(
        repository.lastUpdatedAlbum?.imagePath,
        r'C:\tmp\discogs_cover.png',
      );
    });

    testWidgets('builds a trimmed VocaDB query from the dialog fields', (
      WidgetTester tester,
    ) async {
      final repository = _FakeAlbumRepository();
      final existingAlbum = Album(
        id: 'album-vocadb-query',
        title: '  World End Umbrella  ',
        artists: const <String>['  wowaka  '],
      );
      final viewModel = _FakeAlbumFormViewModel(
        repository: repository,
        vocadbSearchResults: const <Map<String, dynamic>>[],
      );

      await tester.pumpWidget(
        _buildAddScreenApp(
          repository: repository,
          viewModel: viewModel,
          child: AddScreen(albumToEdit: existingAlbum),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('VocaDB에서 검색'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '검색'));
      await tester.pumpAndSettle();

      expect(viewModel.vocadbSearchCalls, 1);
      expect(viewModel.lastVocadbQuery, 'wowaka World End Umbrella');
      expect(find.text('VocaDB 검색 결과가 없습니다.'), findsOneWidget);
    });

    testWidgets('loads and autosaves the selected VocaDB search result', (
      WidgetTester tester,
    ) async {
      final repository = _FakeAlbumRepository();
      final existingAlbum = Album(
        id: 'album-vocadb-load',
        title: 'Miku Symphony',
        artists: const <String>['Tokyo Philharmonic Orchestra'],
      );
      final loadedAlbum = existingAlbum.copyWith(
        title: 'Miku Symphony 2024',
        artists: const <String>['Tokyo Philharmonic Orchestra'],
      );
      final viewModel = _FakeAlbumFormViewModel(
        repository: repository,
        vocadbSearchResults: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 501,
            'title': 'Miku Symphony 2024',
            'artist': 'Tokyo Philharmonic Orchestra',
            'year': '2024',
            'format': 'Album',
            'thumb': '',
          },
        ],
        loadedVocadbAlbumResult: loadedAlbum,
      );

      await tester.pumpWidget(
        _buildAddScreenApp(
          repository: repository,
          viewModel: viewModel,
          child: AddScreen(albumToEdit: existingAlbum),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('VocaDB에서 검색'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '검색'));
      await tester.pumpAndSettle();

      final vocadbResultTitle = find.text('Miku Symphony 2024').last;
      await tester.ensureVisible(vocadbResultTitle);
      await tester.tap(vocadbResultTitle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(viewModel.vocadbSearchCalls, 1);
      expect(viewModel.loadVocadbAlbumByIdCalls, 1);
      expect(viewModel.lastVocadbAlbumId, 501);
      expect(repository.updateCalls, 1);
      expect(repository.lastUpdatedAlbum?.title, 'Miku Symphony 2024');
    });

    testWidgets(
      'builds the MusicBrainz query and autosaves the selected result',
      (WidgetTester tester) async {
        final repository = _FakeAlbumRepository();
        final existingAlbum = Album(
          id: 'album-musicbrainz-load',
          title: '  Black Album  ',
          artists: const <String>['  Metallica  '],
        );
        final loadedAlbum = existingAlbum.copyWith(
          title: 'Metallica',
          artists: const <String>['Metallica'],
        );
        final viewModel = _FakeAlbumFormViewModel(
          repository: repository,
          musicBrainzSearchResults: const <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'mbid-123',
              'title': 'Metallica',
              'artist': 'Metallica',
              'year': '1991',
              'format': 'CD',
            },
          ],
          loadedMusicBrainzAlbumResult: loadedAlbum,
        );

        await tester.pumpWidget(
          _buildAddScreenApp(
            repository: repository,
            viewModel: viewModel,
            child: AddScreen(albumToEdit: existingAlbum),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('MusicBrainz에서 검색'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, '검색'));
        await tester.pumpAndSettle();

        expect(
          viewModel.lastMusicBrainzQuery,
          'artist:"Metallica" AND release:"Black Album"',
        );

        final musicBrainzResultTitle = find.text('Metallica').last;
        await tester.ensureVisible(musicBrainzResultTitle);
        await tester.tap(musicBrainzResultTitle);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1100));
        await tester.pumpAndSettle();

        expect(viewModel.musicBrainzSearchCalls, 1);
        expect(viewModel.loadMusicBrainzAlbumByIdCalls, 1);
        expect(viewModel.lastMusicBrainzAlbumId, 'mbid-123');
        expect(repository.updateCalls, 1);
        expect(repository.lastUpdatedAlbum?.title, 'Metallica');
      },
    );
  });
}

Widget _buildAddScreenApp({
  required _FakeAlbumRepository repository,
  AlbumFormViewModel? viewModel,
  required Widget child,
}) {
  final effectiveViewModel =
      viewModel ??
      AlbumFormViewModel(
        repository,
        DiscogsService(),
        SpotifyService(),
        VocadbService(),
        MusicBrainzService(),
      );

  return ChangeNotifierProvider<AlbumFormViewModel>.value(
    value: effectiveViewModel,
    child: MaterialApp(home: child),
  );
}

Widget _buildAddScreenLauncherApp({
  required _FakeAlbumRepository repository,
  AlbumFormViewModel? viewModel,
  required AddScreen child,
}) {
  final effectiveViewModel =
      viewModel ??
      AlbumFormViewModel(
        repository,
        DiscogsService(),
        SpotifyService(),
        VocadbService(),
        MusicBrainzService(),
      );

  return ChangeNotifierProvider<AlbumFormViewModel>.value(
    value: effectiveViewModel,
    child: MaterialApp(home: _AddScreenLauncher(child: child)),
  );
}

class _AddScreenLauncher extends StatelessWidget {
  const _AddScreenLauncher({required this.child});

  final AddScreen child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => child));
          },
          child: const Text('Open AddScreen'),
        ),
      ),
    );
  }
}

class _FakeAlbumRepository implements IAlbumRepository {
  final ValueNotifier<Object?> _listenable = ValueNotifier<Object?>(null);

  int addCalls = 0;
  int updateCalls = 0;
  Album? lastAddedAlbum;
  String? lastUpdatedAlbumId;
  Album? lastUpdatedAlbum;

  @override
  ValueListenable get listenable => _listenable;

  @override
  Future<void> init() async {}

  @override
  Future<List<Album>> getAll() async => <Album>[];

  @override
  Future<void> add(Album album) async {
    addCalls += 1;
    lastAddedAlbum = album;
  }

  @override
  Future<void> update(String albumId, Album album) async {
    updateCalls += 1;
    lastUpdatedAlbumId = albumId;
    lastUpdatedAlbum = album;
  }

  @override
  Future<void> delete(String albumId) async {}

  @override
  Future<void> reorder(int oldIndex, int newIndex) async {}

  @override
  List<String> getAllFormats() => <String>[];

  @override
  List<String> getAllGenres() => <String>[];

  @override
  List<String> getAllStyles() => <String>[];

  @override
  List<String> getAllLabels() => <String>[];

  @override
  List<String> getSmartArtistSuggestions(String query) => <String>[];

  @override
  List<Artist> getAllArtists() => <Artist>[];

  @override
  List<Album> getAlbumsByArtist(String artistName) => <Album>[];

  @override
  Artist? getArtistByName(String artistName) => null;

  @override
  Future<void> updateArtistImage(String artistName, String? imagePath) async {}

  @override
  Future<void> updateArtistMetadata(
    String artistName,
    List<String> aliases,
    List<String> groups,
  ) async {}

  @override
  List<String> getArtistNamesMatching(String query) => <String>[];

  @override
  Future<String?> exportBackup() async => null;

  @override
  Future<bool> shareBackup() async => false;

  @override
  Future<bool> saveBackupToDevice() async => false;

  @override
  Future<bool> importBackup() async => false;
}

class _FakeAlbumFormViewModel extends AlbumFormViewModel {
  _FakeAlbumFormViewModel({
    required this.repository,
    this.spotifyConfigured = true,
    this.spotifyResults = const <Map<String, String>>[],
    this.pickedImagePath,
    this.discogsSearchResults = const <Map<String, dynamic>>[],
    this.loadedAlbumResult,
    this.discogsCoverResultPath,
    this.vocadbSearchResults = const <Map<String, dynamic>>[],
    this.loadedVocadbAlbumResult,
    this.musicBrainzSearchResults = const <Map<String, dynamic>>[],
    this.loadedMusicBrainzAlbumResult,
    this.barcodeAlbumResult,
  }) : super(
         repository,
         DiscogsService(),
         SpotifyService(),
         VocadbService(),
         MusicBrainzService(),
       );

  final _FakeAlbumRepository repository;
  final bool spotifyConfigured;
  final List<Map<String, String>> spotifyResults;
  final String? pickedImagePath;
  final List<Map<String, dynamic>> discogsSearchResults;
  final Album? loadedAlbumResult;
  final String? discogsCoverResultPath;
  final List<Map<String, dynamic>> vocadbSearchResults;
  final Album? loadedVocadbAlbumResult;
  final List<Map<String, dynamic>> musicBrainzSearchResults;
  final Album? loadedMusicBrainzAlbumResult;
  final Album? barcodeAlbumResult;

  int spotifySearchCalls = 0;
  String? lastSpotifyQuery;
  int pickImageCalls = 0;
  int discogsSearchCalls = 0;
  String? lastDiscogsArtist;
  String? lastDiscogsTitle;
  int loadAlbumByIdCalls = 0;
  int? lastLoadedReleaseId;
  int updateCoverFromUrlCalls = 0;
  String? lastCoverUrl;
  int vocadbSearchCalls = 0;
  String? lastVocadbQuery;
  int loadVocadbAlbumByIdCalls = 0;
  int? lastVocadbAlbumId;
  int musicBrainzSearchCalls = 0;
  String? lastMusicBrainzQuery;
  int loadMusicBrainzAlbumByIdCalls = 0;
  String? lastMusicBrainzAlbumId;
  int barcodeSearchCalls = 0;
  String? lastBarcodeQuery;

  @override
  Future<bool> isSpotifyConfigured() async => spotifyConfigured;

  @override
  Future<List<Map<String, String>>> searchSpotifyForConnect(
    String query,
  ) async {
    spotifySearchCalls += 1;
    lastSpotifyQuery = query;
    return spotifyResults;
  }

  @override
  Future<String?> pickImage() async {
    pickImageCalls += 1;
    return pickedImagePath;
  }

  @override
  Future<List<Map<String, dynamic>>> searchByTitleArtist({
    String? artist,
    String? title,
  }) async {
    discogsSearchCalls += 1;
    lastDiscogsArtist = artist;
    lastDiscogsTitle = title;
    return discogsSearchResults;
  }

  @override
  Future<void> loadAlbumById(int releaseId) async {
    loadAlbumByIdCalls += 1;
    lastLoadedReleaseId = releaseId;
    final albumToApply =
        loadedAlbumResult ??
        currentAlbum?.copyWith(
          title: 'Loaded Album',
          artists: const <String>['Loaded Artist'],
        );
    if (albumToApply != null) {
      updateCurrentAlbum(albumToApply);
    }
  }

  @override
  Future<void> updateCoverFromUrl(String imageUrl) async {
    updateCoverFromUrlCalls += 1;
    lastCoverUrl = imageUrl;

    if (currentAlbum == null) {
      return;
    }

    updateCurrentAlbum(
      currentAlbum!.copyWith(
        imagePath: discogsCoverResultPath ?? r'C:\tmp\discogs_cover.png',
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> searchVocadb(String query) async {
    vocadbSearchCalls += 1;
    lastVocadbQuery = query;
    return vocadbSearchResults;
  }

  @override
  Future<void> loadVocadbAlbumById(int id) async {
    loadVocadbAlbumByIdCalls += 1;
    lastVocadbAlbumId = id;
    final albumToApply =
        loadedVocadbAlbumResult ??
        currentAlbum?.copyWith(
          title: 'Loaded VocaDB Album',
          artists: const <String>['Loaded VocaDB Artist'],
        );
    if (albumToApply != null) {
      updateCurrentAlbum(albumToApply);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> searchMusicBrainz(String query) async {
    musicBrainzSearchCalls += 1;
    lastMusicBrainzQuery = query;
    return musicBrainzSearchResults;
  }

  @override
  Future<void> loadMusicBrainzAlbumById(String mbid) async {
    loadMusicBrainzAlbumByIdCalls += 1;
    lastMusicBrainzAlbumId = mbid;
    final albumToApply =
        loadedMusicBrainzAlbumResult ??
        currentAlbum?.copyWith(
          title: 'Loaded MusicBrainz Album',
          artists: const <String>['Loaded MusicBrainz Artist'],
        );
    if (albumToApply != null) {
      updateCurrentAlbum(albumToApply);
    }
  }

  @override
  Future<void> searchByBarcode(String barcode) async {
    barcodeSearchCalls += 1;
    lastBarcodeQuery = barcode;
    if (barcodeAlbumResult != null) {
      updateCurrentAlbum(barcodeAlbumResult!);
    }
  }
}
