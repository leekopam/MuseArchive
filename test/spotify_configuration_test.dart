import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/models/artist.dart';
import 'package:my_album_app/services/discogs_service.dart';
import 'package:my_album_app/services/i_album_repository.dart';
import 'package:my_album_app/services/musicbrainz_service.dart';
import 'package:my_album_app/services/spotify_service.dart';
import 'package:my_album_app/services/vocadb_service.dart';
import 'package:my_album_app/viewmodels/album_form_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spotify configuration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'SpotifyService.hasConfiguredCredentials reads both prefs keys',
      () async {
        SharedPreferences.setMockInitialValues({
          SpotifyService.clientIdPrefsKey: 'client-id',
          SpotifyService.clientSecretPrefsKey: 'client-secret',
        });

        final service = SpotifyService();

        expect(await service.hasConfiguredCredentials(), isTrue);
      },
    );

    test(
      'SpotifyService.hasConfiguredCredentials returns false when a key is missing',
      () async {
        SharedPreferences.setMockInitialValues({
          SpotifyService.clientIdPrefsKey: 'client-id',
          SpotifyService.clientSecretPrefsKey: '   ',
        });

        final service = SpotifyService();

        expect(await service.hasConfiguredCredentials(), isFalse);
      },
    );

    test(
      'AlbumFormViewModel.isSpotifyConfigured follows the same SharedPreferences mock',
      () async {
        SharedPreferences.setMockInitialValues({
          SpotifyService.clientIdPrefsKey: 'client-id',
          SpotifyService.clientSecretPrefsKey: 'client-secret',
        });

        final viewModel = AlbumFormViewModel(
          _FakeAlbumRepository(),
          DiscogsService(),
          SpotifyService(),
          VocadbService(),
          MusicBrainzService(),
        );

        expect(await viewModel.isSpotifyConfigured(), isTrue);
      },
    );

    test(
      'AlbumFormViewModel.isSpotifyConfigured returns false when prefs are blank',
      () async {
        SharedPreferences.setMockInitialValues({
          SpotifyService.clientIdPrefsKey: 'client-id',
          SpotifyService.clientSecretPrefsKey: '',
        });

        final viewModel = AlbumFormViewModel(
          _FakeAlbumRepository(),
          DiscogsService(),
          SpotifyService(),
          VocadbService(),
          MusicBrainzService(),
        );

        expect(await viewModel.isSpotifyConfigured(), isFalse);
      },
    );
  });
}

class _FakeAlbumRepository implements IAlbumRepository {
  final ValueNotifier<Object?> _listenable = ValueNotifier<Object?>(null);

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
  Future<bool> shareBackup() async => false;

  @override
  Future<bool> saveBackupToDevice() async => false;

  @override
  Future<bool> importBackup() async => false;
}
