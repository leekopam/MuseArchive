import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:my_album_app/utils/file_utils.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('file-utils-test');
    clearFileExistsCache();
  });

  tearDown(() async {
    clearFileExistsCache();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('fileExistsSync reflects real file presence', () async {
    final file = File(path.join(tempDir.path, 'cover.jpg'));
    await file.writeAsBytes(<int>[1, 2, 3]);

    expect(fileExistsSync(file.path), isTrue);
    expect(fileExistsSync(path.join(tempDir.path, 'missing.jpg')), isFalse);
  });

  test('fileExistsSync caches result until cleared', () async {
    final file = File(path.join(tempDir.path, 'cover.jpg'));
    await file.writeAsBytes(<int>[1]);

    expect(fileExistsSync(file.path), isTrue);

    // 캐시된 동안 파일이 지워져도 캐시 값이 유지된다 (의도된 메모이즈 동작)
    await file.delete();
    expect(fileExistsSync(file.path), isTrue);

    clearFileExistsCache();
    expect(fileExistsSync(file.path), isFalse);
  });

  test('invalidateFileExists drops the cached entry', () async {
    final file = File(path.join(tempDir.path, 'cover.jpg'));
    await file.writeAsBytes(<int>[1]);

    expect(fileExistsSync(file.path), isTrue);

    // 파일 삭제 후 무효화하면 캐시가 실제 상태를 다시 반영한다
    await file.delete();
    invalidateFileExists(file.path);
    expect(fileExistsSync(file.path), isFalse);
  });
}
