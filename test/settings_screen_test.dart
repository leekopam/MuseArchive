import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/models/artist.dart';
import 'package:my_album_app/screens/settings_screen.dart';
import 'package:my_album_app/services/discogs_service.dart';
import 'package:my_album_app/services/i_album_repository.dart';
import 'package:my_album_app/services/spotify_service.dart';
import 'package:my_album_app/services/theme_manager.dart';
import 'package:my_album_app/services/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      themeNotifier.value = ThemeMode.light;
    });

    tearDown(() {
      themeNotifier.value = ThemeMode.light;
    });

    testWidgets('loads stored credentials and version on init', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'discogs_api_token': 'discogs-token',
        SpotifyService.clientIdPrefsKey: 'spotify-client-id',
        SpotifyService.clientSecretPrefsKey: 'spotify-client-secret',
      });

      final repository = _FakeAlbumRepository();
      final updateService = _FakeUpdateService(currentVersion: '9.9.9');

      await tester.pumpWidget(
        _buildTestApp(repository: repository, updateService: updateService),
      );
      await tester.pumpAndSettle();

      final texts = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.controller?.text ?? '')
          .toList();

      expect(texts, contains('discogs-token'));
      expect(texts, contains('spotify-client-id'));
      expect(texts, contains('spotify-client-secret'));
      expect(updateService.getCurrentVersionCalls, 1);
    });

    testWidgets('theme switch persists dark mode preference', (
      WidgetTester tester,
    ) async {
      final repository = _FakeAlbumRepository();
      final updateService = _FakeUpdateService(currentVersion: '1.2.3');

      await tester.pumpWidget(
        _buildTestApp(repository: repository, updateService: updateService),
      );
      await tester.pumpAndSettle();

      expect(themeNotifier.value, ThemeMode.light);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(themeNotifier.value, ThemeMode.dark);
      expect(prefs.getBool('is_dark_mode'), isTrue);
    });

    testWidgets('backup and restore actions use repository callbacks', (
      WidgetTester tester,
    ) async {
      final repository = _FakeAlbumRepository();
      final updateService = _FakeUpdateService(currentVersion: '1.2.3');

      await tester.pumpWidget(
        _buildTestApp(repository: repository, updateService: updateService),
      );
      await tester.pumpAndSettle();

      await _scrollUntilVisible(tester, find.byIcon(Icons.backup));
      await tester.tap(find.byIcon(Icons.backup));
      await tester.pumpAndSettle();

      expect(repository.saveBackupCalls, 1);

      await _scrollUntilVisible(tester, find.byIcon(Icons.share));
      await tester.tap(find.byIcon(Icons.share));
      await tester.pumpAndSettle();

      expect(repository.shareBackupCalls, 1);

      await _scrollUntilVisible(tester, find.byIcon(Icons.restore));
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();

      final confirmButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      );

      expect(confirmButton, findsOneWidget);

      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(repository.importBackupCalls, 1);
    });

    testWidgets('restore cancel leaves repository untouched', (
      WidgetTester tester,
    ) async {
      final repository = _FakeAlbumRepository();
      final updateService = _FakeUpdateService(currentVersion: '1.2.3');

      await tester.pumpWidget(
        _buildTestApp(repository: repository, updateService: updateService),
      );
      await tester.pumpAndSettle();

      await _scrollUntilVisible(tester, find.byIcon(Icons.restore));
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();

      final cancelButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      );

      expect(cancelButton, findsOneWidget);

      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(repository.importBackupCalls, 0);
    });

    testWidgets('update button checks for updates and shows the dialog', (
      WidgetTester tester,
    ) async {
      final repository = _FakeAlbumRepository();
      final updateService = _FakeUpdateService(
        currentVersion: '1.0.0',
        updateInfo: UpdateInfo(
          latestVersion: '1.1.0',
          releaseNotes: 'Bug fixes',
          downloadUrl: 'https://example.com/app.apk',
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(repository: repository, updateService: updateService),
      );
      await tester.pumpAndSettle();

      await _scrollUntilVisible(tester, find.byIcon(Icons.refresh));
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(updateService.checkForUpdateCalls, 1);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('1.1.0'), findsOneWidget);
    });

    testWidgets('update button with no update shows feedback without dialog', (
      WidgetTester tester,
    ) async {
      final repository = _FakeAlbumRepository();
      final updateService = _FakeUpdateService(currentVersion: '1.0.0');

      await tester.pumpWidget(
        _buildTestApp(repository: repository, updateService: updateService),
      );
      await tester.pumpAndSettle();

      await _scrollUntilVisible(tester, find.byIcon(Icons.refresh));
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(updateService.checkForUpdateCalls, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Widget _buildTestApp({
  required _FakeAlbumRepository repository,
  required _FakeUpdateService updateService,
}) {
  return MultiProvider(
    providers: [
      Provider<IAlbumRepository>.value(value: repository),
      Provider<SpotifyService>.value(value: SpotifyService()),
      Provider<DiscogsService>.value(value: DiscogsService()),
      Provider<UpdateService>.value(value: updateService),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

class _FakeUpdateService extends UpdateService {
  _FakeUpdateService({required this.currentVersion, this.updateInfo});

  final String currentVersion;
  final UpdateInfo? updateInfo;

  int getCurrentVersionCalls = 0;
  int checkForUpdateCalls = 0;

  @override
  Future<String> getCurrentVersion() async {
    getCurrentVersionCalls += 1;
    return currentVersion;
  }

  @override
  Future<UpdateInfo?> checkForUpdate() async {
    checkForUpdateCalls += 1;
    return updateInfo;
  }

  @override
  Future<void> downloadAndInstallApk(
    String url,
    void Function(double progress) onProgress,
  ) async {
    onProgress(1.0);
  }

  @override
  Future<void> saveInstalledVersion(String version) async {}
}

class _FakeAlbumRepository implements IAlbumRepository {
  final ValueNotifier<Object?> _listenable = ValueNotifier<Object?>(null);

  int saveBackupCalls = 0;
  int shareBackupCalls = 0;
  int importBackupCalls = 0;

  @override
  ValueListenable get listenable => _listenable;

  @override
  Future<void> init() async {}

  @override
  Future<List<Album>> getAll() async => <Album>[];

  @override
  Future<void> add(Album album) async {}

  @override
  Future<void> update(String albumId, Album album) async {}

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
  Future<bool> shareBackup() async {
    shareBackupCalls += 1;
    return true;
  }

  @override
  Future<bool> saveBackupToDevice() async {
    saveBackupCalls += 1;
    return true;
  }

  @override
  Future<bool> importBackup() async {
    importBackupCalls += 1;
    return true;
  }
}
