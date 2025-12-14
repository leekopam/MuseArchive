import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/album_repository.dart';
import 'services/discogs_service.dart';
import 'services/i_album_repository.dart';
import 'screens/home_screen.dart';
import 'services/ocr_service.dart';
import 'services/theme_manager.dart';
import 'services/spotify_service.dart';
import 'utils/theme.dart';
import 'viewmodels/album_form_viewmodel.dart';
import 'viewmodels/home_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Instantiate services
  final IAlbumRepository albumRepository = AlbumRepository();
  final DiscogsService discogsService = DiscogsService();
  final OcrService ocrService = OcrService();

  // Initialize services
  await albumRepository.init();
  await loadTheme();

  runApp(
    MultiProvider(
      providers: [
        // Services
        Provider<IAlbumRepository>.value(value: albumRepository),
        Provider<DiscogsService>.value(value: discogsService),
        Provider<OcrService>.value(value: ocrService),
        Provider<SpotifyService>(create: (_) => SpotifyService()),

        // ViewModels
        ChangeNotifierProvider(
          create: (context) => HomeViewModel(albumRepository),
        ),
        ChangeNotifierProxyProvider4<
          IAlbumRepository,
          DiscogsService,
          OcrService,
          SpotifyService,
          AlbumFormViewModel
        >(
          create: (context) => AlbumFormViewModel(
            albumRepository,
            discogsService,
            ocrService,
            SpotifyService(),
          ),
          update: (context, repo, discogs, ocr, spotify, previous) =>
              previous ?? AlbumFormViewModel(repo, discogs, ocr, spotify),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'MuseArchive',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: currentMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
          localeResolutionCallback: (locale, supportedLocales) {
            if (locale == null) return supportedLocales.first;

            // Iterate supported locales and check for matches
            for (var supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == locale.languageCode &&
                  supportedLocale.countryCode == locale.countryCode) {
                return supportedLocale;
              }
            }
            // If no country match, try language match
            for (var supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == locale.languageCode) {
                return supportedLocale;
              }
            }

            // Default to supportedLocales.first (Korean) if no match
            return supportedLocales.first;
          },
          home: const HomeScreen(),
        );
      },
    );
  }
}
