import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/album_repository.dart';
import 'services/discogs_service.dart';
import 'services/i_album_repository.dart';
import 'screens/home_screen.dart';
import 'services/theme_manager.dart';
import 'services/spotify_service.dart';
import 'services/vocadb_service.dart';
import 'services/musicbrainz_service.dart';
import 'services/update_service.dart';
import 'utils/theme.dart';
import 'viewmodels/album_form_viewmodel.dart';
import 'viewmodels/home_viewmodel.dart';
import 'viewmodels/global_artist_settings.dart';

// region 앱 초기화
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 서비스 인스턴스화
  final IAlbumRepository albumRepository = AlbumRepository();
  final DiscogsService discogsService = DiscogsService();
  final VocadbService vocadbService = VocadbService();
  final MusicBrainzService musicBrainzService = MusicBrainzService();
  final SpotifyService spotifyService = SpotifyService();
  final UpdateService updateService = UpdateService();

  // 서비스 초기화
  await albumRepository.init();
  await loadTheme();

  runApp(
    MultiProvider(
      providers: [
        // 서비스 프로바이더
        Provider<IAlbumRepository>.value(value: albumRepository),
        Provider<DiscogsService>.value(value: discogsService),
        Provider<VocadbService>.value(value: vocadbService),
        Provider<MusicBrainzService>.value(value: musicBrainzService),
        Provider<SpotifyService>.value(value: spotifyService),
        Provider<UpdateService>.value(value: updateService),

        // 뷰모델 프로바이더
        ChangeNotifierProvider(
          create: (context) => HomeViewModel(albumRepository),
        ),
        ChangeNotifierProvider(create: (context) => GlobalArtistSettings()),
        ChangeNotifierProxyProvider5<
          IAlbumRepository,
          DiscogsService,
          SpotifyService,
          VocadbService,
          MusicBrainzService,
          AlbumFormViewModel
        >(
          create: (context) => AlbumFormViewModel(
            albumRepository,
            discogsService,
            spotifyService,
            vocadbService,
            musicBrainzService,
          ),
          update:
              (
                context,
                repo,
                discogs,
                spotify,
                vocadb,
                musicBrainz,
                previous,
              ) =>
                  previous ??
                  AlbumFormViewModel(
                    repo,
                    discogs,
                    spotify,
                    vocadb,
                    musicBrainz,
                  ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
// endregion

// region 메인 앱 위젯
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

          // 테마 설정
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: currentMode,

          // 로컬라이제이션 설정
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
          localeResolutionCallback: (locale, supportedLocales) {
            if (locale == null) return supportedLocales.first;

            // 완전 일치 확인
            for (var supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == locale.languageCode &&
                  supportedLocale.countryCode == locale.countryCode) {
                return supportedLocale;
              }
            }

            // 언어 일치 확인
            for (var supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == locale.languageCode) {
                return supportedLocale;
              }
            }

            return supportedLocales.first;
          },

          home: const HomeScreen(),
        );
      },
    );
  }
}

// endregion
