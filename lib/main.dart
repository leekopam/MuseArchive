import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/album_repository.dart';
import 'services/discogs_service.dart';
import 'services/i_album_repository.dart';
import 'screens/home_screen.dart';
import 'services/ocr_service.dart';
import 'services/theme_manager.dart';
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

        // ViewModels
        ChangeNotifierProvider(
          create: (context) => HomeViewModel(albumRepository),
        ),
        ChangeNotifierProxyProvider3<IAlbumRepository, DiscogsService, OcrService, AlbumFormViewModel>(
          create: (context) => AlbumFormViewModel(albumRepository, discogsService, ocrService),
          update: (context, repo, discogs, ocr, previous) => previous ?? AlbumFormViewModel(repo, discogs, ocr),
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
          home: const HomeScreen(),
        );
      },
    );
  }
}
