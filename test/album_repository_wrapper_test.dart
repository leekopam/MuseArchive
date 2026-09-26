import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/services/album_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AlbumRepository backup wrappers', () {
    late Directory sandbox;
    late AlbumRepository repository;
    late PathProviderPlatform originalPathProvider;
    FilePicker? originalFilePicker;

    setUp(() async {
      originalPathProvider = PathProviderPlatform.instance;
      try {
        originalFilePicker = FilePicker.platform;
      } catch (_) {
        originalFilePicker = null;
      }

      await Hive.close();
      sandbox = await Directory.systemTemp.createTemp(
        'musearchive_backup_wrapper_test_',
      );

      final hiveDir = Directory(path.join(sandbox.path, 'hive'));
      await hiveDir.create(recursive: true);
      Hive.init(hiveDir.path);
      await Hive.openBox('albumBox');
      await Hive.openBox('artistBox');

      repository = AlbumRepository();
      repository.resetPlatformHooks();
    });

    tearDown(() async {
      repository.resetPlatformHooks();
      PathProviderPlatform.instance = originalPathProvider;
      if (originalFilePicker != null) {
        FilePicker.platform = originalFilePicker!;
      }

      await Hive.close();
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    test(
      'exportBackup returns null when temporary directory lookup fails',
      () async {
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          throwOnTemporaryPath: true,
        );

        final result = await repository.exportBackup();

        expect(result, isNull);
      },
    );

    test('importBackup returns false when file picker is cancelled', () async {
      FilePicker.platform = _FakeFilePicker();

      final result = await repository.importBackup();

      expect(result, isFalse);
    });

    test('importBackup returns false when picked file has no path', () async {
      FilePicker.platform = _FakeFilePicker(
        result: FilePickerResult(<PlatformFile>[
          PlatformFile(name: 'backup.zip', size: 0),
        ]),
      );

      final result = await repository.importBackup();

      expect(result, isFalse);
    });

    test(
      'importBackup returns false when application documents lookup fails',
      () async {
        final zipPath = path.join(sandbox.path, 'backup.zip');
        await File(zipPath).writeAsBytes(<int>[1, 2, 3]);

        FilePicker.platform = _FakeFilePicker(
          result: FilePickerResult(<PlatformFile>[
            PlatformFile(
              name: 'backup.zip',
              path: zipPath,
              size: File(zipPath).lengthSync(),
            ),
          ]),
        );

        PathProviderPlatform.instance = _FakePathProviderPlatform(
          temporaryPath: sandbox.path,
          throwOnApplicationDocumentsPath: true,
        );

        final result = await repository.importBackup();

        expect(result, isFalse);
      },
    );

    test(
      'exportBackup creates a zip in the provided temporary directory',
      () async {
        await _seedAlbumData();

        final tempDir = Directory(path.join(sandbox.path, 'temp'));
        await tempDir.create(recursive: true);

        PathProviderPlatform.instance = _FakePathProviderPlatform(
          temporaryPath: tempDir.path,
        );

        final zipPath = await repository.exportBackup();

        expect(zipPath, isNotNull);
        expect(zipPath, startsWith(tempDir.path));
        expect(await File(zipPath!).exists(), isTrue);
      },
    );

    test('shareBackup returns false when backup export fails', () async {
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        throwOnTemporaryPath: true,
      );

      final result = await repository.shareBackup();

      expect(result, isFalse);
    });

    test('shareBackup returns false when share action throws', () async {
      await _seedAlbumData();

      final tempDir = Directory(path.join(sandbox.path, 'share-temp'));
      await tempDir.create(recursive: true);
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        temporaryPath: tempDir.path,
      );

      repository.shareBackupFile = (_) async {
        throw Exception('share failed');
      };

      final result = await repository.shareBackup();

      expect(result, isFalse);
    });

    test('shareBackup shares the exported file when export succeeds', () async {
      await _seedAlbumData();

      final tempDir = Directory(path.join(sandbox.path, 'share-success'));
      await tempDir.create(recursive: true);
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        temporaryPath: tempDir.path,
      );

      String? sharedPath;
      repository.shareBackupFile = (backupPath) async {
        sharedPath = backupPath;
      };

      final result = await repository.shareBackup();

      expect(result, isTrue);
      expect(sharedPath, isNotNull);
      expect(sharedPath, startsWith(tempDir.path));
      expect(await File(sharedPath!).exists(), isTrue);
    });

    test('saveBackupToDevice returns false when save dialog throws', () async {
      await _seedAlbumData();

      final tempDir = Directory(path.join(sandbox.path, 'save-failure'));
      await tempDir.create(recursive: true);
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        temporaryPath: tempDir.path,
      );

      repository.saveBackupFile = (backupPath, fileName) async {
        expect(backupPath, isNotEmpty);
        expect(fileName, endsWith('.zip'));
        throw Exception('save failed');
      };

      final result = await repository.saveBackupToDevice();

      expect(result, isFalse);
    });

    test('saveBackupToDevice returns false when user cancels save', () async {
      await _seedAlbumData();

      final tempDir = Directory(path.join(sandbox.path, 'save-cancelled'));
      await tempDir.create(recursive: true);
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        temporaryPath: tempDir.path,
      );

      repository.saveBackupFile = (backupPath, fileName) async {
        expect(backupPath, isNotEmpty);
        expect(fileName, endsWith('.zip'));
        return null;
      };

      final result = await repository.saveBackupToDevice();

      expect(result, isFalse);
    });

    test('saveBackupToDevice returns true when file is saved', () async {
      await _seedAlbumData();

      final tempDir = Directory(path.join(sandbox.path, 'save-success'));
      await tempDir.create(recursive: true);
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        temporaryPath: tempDir.path,
      );

      String? sourcePath;
      String? fileName;
      repository.saveBackupFile = (backupPath, suggestedFileName) async {
        sourcePath = backupPath;
        fileName = suggestedFileName;
        return path.join(sandbox.path, 'exports', suggestedFileName);
      };

      final result = await repository.saveBackupToDevice();

      expect(result, isTrue);
      expect(sourcePath, isNotNull);
      expect(sourcePath, startsWith(tempDir.path));
      expect(await File(sourcePath!).exists(), isTrue);
      expect(fileName, isNotNull);
      expect(fileName, endsWith('.zip'));
    });
  });
}

Future<void> _seedAlbumData() async {
  await Hive.box('albumBox').add(
    Album(
      id: 'album-1',
      title: 'Backup Album',
      artists: const <String>['Backup Artist'],
    ).toMap(),
  );
}

class _FakeFilePicker extends FilePicker {
  _FakeFilePicker({this.result});

  final FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => result;
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform({
    this.temporaryPath,
    this.throwOnTemporaryPath = false,
    this.throwOnApplicationDocumentsPath = false,
  });

  final String? temporaryPath;
  final bool throwOnTemporaryPath;
  final bool throwOnApplicationDocumentsPath;

  @override
  Future<String?> getTemporaryPath() async {
    if (throwOnTemporaryPath) {
      throw Exception('temporary path lookup failed');
    }
    return temporaryPath;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    if (throwOnApplicationDocumentsPath) {
      throw Exception('application documents lookup failed');
    }
    return temporaryPath;
  }
}
