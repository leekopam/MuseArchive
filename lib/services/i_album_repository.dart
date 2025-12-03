import 'package:flutter/foundation.dart';
import '../models/album.dart';
import '../models/artist.dart';

abstract class IAlbumRepository {
  Future<void> init();
  ValueListenable get listenable;
  Future<List<Album>> getAll();
  Future<void> add(Album album);
  Future<void> update(String albumId, Album album);
  Future<void> delete(String albumId);
  Future<void> reorder(int oldIndex, int newIndex);
  List<String> getAllFormats();
  List<String> getAllGenres();
  List<String> getAllStyles();
  List<String> getAllLabels();
  List<String> getSmartArtistSuggestions(String query);
  List<Artist> getAllArtists();
  List<Album> getAlbumsByArtist(String artistName);
  Future<String?> exportBackup();
  Future<bool> shareBackup();
  Future<bool> saveBackupToDevice();
  Future<bool> importBackup();
}
