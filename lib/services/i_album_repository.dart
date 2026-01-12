import 'package:flutter/foundation.dart';
import '../models/album.dart';
import '../models/artist.dart';

/// 앨범 저장소 인터페이스
abstract class IAlbumRepository {
  // region 초기화 및 리스너
  Future<void> init();
  ValueListenable get listenable;
  //endregion

  // endregion

  // region CRUD 작업
  Future<List<Album>> getAll();
  Future<void> add(Album album);
  Future<void> update(String albumId, Album album);
  Future<void> delete(String albumId);
  Future<void> reorder(int oldIndex, int newIndex);
  //endregion

  // endregion

  // region 쿼리 메서드
  List<String> getAllFormats();
  List<String> getAllGenres();
  List<String> getAllStyles();
  List<String> getAllLabels();
  List<String> getSmartArtistSuggestions(String query);
  //endregion

  // endregion

  // region 아티스트 관리
  List<Artist> getAllArtists();
  List<Album> getAlbumsByArtist(String artistName);
  Artist? getArtistByName(String artistName);
  Future<void> updateArtistImage(String artistName, String? imagePath);
  Future<void> updateArtistMetadata(
    String artistName,
    List<String> aliases,
    List<String> groups,
  );
  List<String> getArtistNamesMatching(String query);
  //endregion

  // endregion

  // region 백업 및 복원
  Future<String?> exportBackup();
  Future<bool> shareBackup();
  Future<bool> saveBackupToDevice();
  Future<bool> importBackup();
  //endregion
}
