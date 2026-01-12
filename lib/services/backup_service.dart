import 'album_repository.dart';

/// 백업 서비스 (Wrapper for AlbumRepository backup methods)
class BackupService {
  // region 싱글톤 패턴
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();
  //endregion

  // endregion

  // region 의존성
  final AlbumRepository _repository = AlbumRepository();
  //endregion

  // endregion

  // region 백업 작업
  /// 백업 파일 생성
  Future<String?> createBackup() async {
    return await _repository.exportBackup();
  }

  /// 백업 파일 공유
  Future<bool> shareBackup() async {
    return await _repository.shareBackup();
  }

  /// 백업 파일을 기기에 저장
  Future<bool> saveBackupToDevice() async {
    return await _repository.saveBackupToDevice();
  }

  /// 백업에서 복원
  Future<bool> restoreFromBackup() async {
    return await _repository.importBackup();
  }

  // endregion
}
