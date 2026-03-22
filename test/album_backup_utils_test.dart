import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:my_album_app/services/album_backup_utils.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('album-backup-utils-test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('buildBackupImageFileName prefixes the basename only', () {
    final fileName = buildBackupImageFileName(
      'album_123',
      path.join('nested', 'folder', 'cover.jpg'),
    );

    expect(fileName, 'album_123_cover.jpg');
  });

  test('parseBackupJsonMap converts a map-like value', () {
    final result = parseBackupJsonMap({'id': '1', 'title': 'Album'}, 'album');

    expect(result, {'id': '1', 'title': 'Album'});
  });

  test('parseBackupJsonMap throws for non-map values', () {
    expect(
      () => parseBackupJsonMap(<dynamic>['invalid'], 'album'),
      throwsException,
    );
  });

  test(
    'resolveBackupImageFile finds an explicitly referenced relative file',
    () {
      final imagesDir = Directory(path.join(tempDir.path, 'images'))
        ..createSync(recursive: true);
      final imageFile = File(path.join(imagesDir.path, 'cover.jpg'))
        ..writeAsStringSync('image');

      final result = resolveBackupImageFile(
        tempDir,
        'images/cover.jpg',
        searchFolders: const ['images'],
      );

      expect(result?.path, imageFile.path);
    },
  );

  test('resolveBackupImageFile falls back to a search folder by basename', () {
    final imagesDir = Directory(path.join(tempDir.path, 'images'))
      ..createSync(recursive: true);
    final imageFile = File(path.join(imagesDir.path, 'cover.jpg'))
      ..writeAsStringSync('image');

    final result = resolveBackupImageFile(
      tempDir,
      path.join(tempDir.path, 'old', 'album_images', 'cover.jpg'),
      searchFolders: const ['images'],
    );

    expect(result?.path, imageFile.path);
  });

  test(
    'resolveBackupImageFile rejects path traversal outside the extract dir',
    () {
      final result = resolveBackupImageFile(
        tempDir,
        '../outside.jpg',
        searchFolders: const ['images'],
      );

      expect(result, isNull);
    },
  );
}
