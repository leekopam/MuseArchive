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

  /// [preserveFiles]가 true면 커버 이미지 파일을 디스크에 남긴다.
  /// 삭제 실행취소(Undo) 흐름처럼 복원 가능성이 있는 경우에만 사용한다.
  Future<void> delete(String albumId, {bool preserveFiles = false});
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

  /// 마지막 복원 시도의 실패 사유(사용자 표시용). 실패한 적이 없으면 null.
  String? get lastBackupRestoreError => null;

  /// 마지막 복원에서 스키마 불일치로 건너뛴 항목 수.
  int get lastBackupSkippedCount => 0;
  //endregion
}
