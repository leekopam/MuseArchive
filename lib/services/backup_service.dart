import 'album_repository.dart';

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final AlbumRepository _repository = AlbumRepository();

  Future<String?> createBackup() async {
    return await _repository.exportBackup();
  }

  Future<bool> shareBackup() async {
    return await _repository.shareBackup();
  }

  Future<bool> saveBackupToDevice() async {
    return await _repository.saveBackupToDevice();
  }

  Future<bool> restoreFromBackup() async {
    return await _repository.importBackup();
  }
}
