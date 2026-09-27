import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path;

import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/services/album_repository.dart';

/// docs/REF에 보관된 실제 백업 zip을 대상으로 한 S11 복원/백업 E2E 검증.
/// 파일이 없으면 스킵한다(저장소에 커밋되지 않는 로컬 픽스처).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  File? findRealBackupZip() {
    final refDir = Directory('docs/REF');
    if (!refDir.existsSync()) return null;
    final candidates = refDir
        .listSync()
        .whereType<File>()
        .where((f) => path.basename(f.path).startsWith('muse_archive_backup_'))
        .where((f) => f.path.endsWith('.zip'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return candidates.isEmpty ? null : candidates.first;
  }

  group('S11 실제 백업 파일 복원/백업 왕복', () {
    late Directory sandbox;
    late Box albumBox;
    late Box artistBox;
    late AlbumRepository repository;
    late File? realZip;

    setUp(() async {
      await Hive.close();
      sandbox = await Directory.systemTemp.createTemp(
        'musearchive_real_backup_test_',
      );

      final hiveDir = Directory(path.join(sandbox.path, 'hive'));
      await hiveDir.create(recursive: true);
      Hive.init(hiveDir.path);

      albumBox = await Hive.openBox('albumBox');
      artistBox = await Hive.openBox('artistBox');
      repository = AlbumRepository();
      realZip = findRealBackupZip();
    });

    tearDown(() async {
      await Hive.close();
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    test('실제 백업 zip 복원 시 앨범·아티스트·이미지가 전수 재배치된다', () async {
      final zip = realZip;
      if (zip == null) {
        markTestSkipped('docs/REF에 muse_archive_backup_*.zip 없음');
        return;
      }

      final zipBytes = await zip.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);
      final expectedAlbums =
          jsonDecode(
                utf8.decode(
                  archive.files
                      .firstWhere((f) => f.name == 'albums.json')
                      .content as List<int>,
                ),
              )
              as List;
      final expectedArtists =
          jsonDecode(
                utf8.decode(
                  archive.files
                      .firstWhere((f) => f.name == 'artists.json')
                      .content as List<int>,
                ),
              )
              as List;

      // 기존 데이터가 있어도 복원으로 교체되는지 확인
      await albumBox.add(
        Album(
          id: 'stale-album',
          title: 'Stale',
          artists: const <String>['Stale Artist'],
        ).toMap(),
      );

      final tempDir = Directory(path.join(sandbox.path, 'temp'));
      await tempDir.create(recursive: true);
      final appDir = Directory(path.join(sandbox.path, 'app'));
      await appDir.create(recursive: true);

      final success = await repository.importBackupFromZipPath(
        zip.path,
        tempDir: tempDir,
        appDir: appDir,
        timestamp: 1000,
      );

      expect(success, isTrue, reason: '실제 백업 zip 복원 실패');
      expect(albumBox.length, expectedAlbums.length);
      expect(artistBox.length, expectedArtists.length);

      // id → 백업 내 원본 이미지 경로 맵
      final sourceImageById = <String, String>{};
      for (final raw in expectedAlbums) {
        final imagePath = (raw as Map)['imagePath'] as String?;
        if (imagePath != null && imagePath.isNotEmpty) {
          sourceImageById[raw['id'] as String] = imagePath;
        }
      }

      int albumsWithImage = 0;
      final albumImagesDir = Directory(path.join(appDir.path, 'album_images'));
      for (final value in albumBox.values) {
        final album = Album.fromMap(Map<String, dynamic>.from(value as Map));
        final sourceImagePath = sourceImageById[album.id];
        if (sourceImagePath == null) {
          expect(album.imagePath, isNull, reason: '이미지 없는 앨범 ${album.id}');
          continue;
        }
        albumsWithImage++;

        final storedPath = album.imagePath;
        expect(storedPath, isNotNull);
        expect(
          path.isWithin(albumImagesDir.path, storedPath!),
          isTrue,
          reason: '복원 이미지는 album_images 아래로 재배치되어야 함: $storedPath',
        );

        // 바이트 단위로 원본 zip 엔트리와 동일한지 확인
        final entry = archive.files.firstWhere(
          (f) => f.name == sourceImagePath,
          orElse: () => throw StateError('zip에 $sourceImagePath 없음'),
        );
        final storedBytes = await File(storedPath).readAsBytes();
        expect(
          storedBytes,
          equals(entry.content as List<int>),
          reason: '이미지 바이트 불일치: ${album.id}',
        );
      }
      expect(albumsWithImage, sourceImageById.length);

      // 임시 추출/스테이지 디렉터리 정리 확인
      expect(
        Directory(path.join(tempDir.path, 'restore_1000')).existsSync(),
        isFalse,
      );
      expect(
        Directory(path.join(tempDir.path, 'restore_stage_1000')).existsSync(),
        isFalse,
      );
    });

    test('복원 → 재export → 재import 왕복이 동일한 데이터를 유지한다', () async {
      final zip = realZip;
      if (zip == null) {
        markTestSkipped('docs/REF에 muse_archive_backup_*.zip 없음');
        return;
      }

      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
      final expectedAlbums =
          jsonDecode(
                utf8.decode(
                  archive.files
                      .firstWhere((f) => f.name == 'albums.json')
                      .content as List<int>,
                ),
              )
              as List;
      final expectedArtists =
          jsonDecode(
                utf8.decode(
                  archive.files
                      .firstWhere((f) => f.name == 'artists.json')
                      .content as List<int>,
                ),
              )
              as List;

      final tempDir = Directory(path.join(sandbox.path, 'temp'));
      await tempDir.create(recursive: true);
      final appDir = Directory(path.join(sandbox.path, 'app'));
      await appDir.create(recursive: true);

      expect(
        await repository.importBackupFromZipPath(
          zip.path,
          tempDir: tempDir,
          appDir: appDir,
        ),
        isTrue,
      );

      final exportTemp = Directory(path.join(sandbox.path, 'export_temp'));
      await exportTemp.create(recursive: true);
      final reexportZipPath = await repository.exportBackupFromTempDirectory(
        exportTemp,
        timestamp: 2000,
      );
      expect(reexportZipPath, isNotNull);

      final reexport = ZipDecoder().decodeBytes(
        await File(reexportZipPath!).readAsBytes(),
      );
      final reexportAlbums =
          jsonDecode(
                utf8.decode(
                  reexport.files
                          .firstWhere((f) => f.name == 'albums.json')
                          .content
                      as List<int>,
                ),
              )
              as List;
      final reexportArtists =
          jsonDecode(
                utf8.decode(
                  reexport.files
                          .firstWhere((f) => f.name == 'artists.json')
                          .content
                      as List<int>,
                ),
              )
              as List;
      final reexportImages = reexport.files
          .where((f) => f.isFile && f.name.startsWith('images/'))
          .length;

      expect(reexportAlbums.length, expectedAlbums.length);
      expect(reexportArtists.length, expectedArtists.length);
      expect(
        reexportImages,
        expectedAlbums
            .where((a) => ((a as Map)['imagePath'] as String?)?.isNotEmpty ?? false)
            .length,
        reason: '복원된 이미지가 재export에 모두 포함되어야 함',
      );

      // 두 번째 import도 동일 결과 — 멱등성
      await albumBox.clear();
      await artistBox.clear();
      expect(
        await repository.importBackupFromZipPath(
          reexportZipPath,
          tempDir: tempDir,
          appDir: appDir,
        ),
        isTrue,
      );
      expect(albumBox.length, expectedAlbums.length);
      expect(artistBox.length, expectedArtists.length);

      // 왕복 후에도 임의 앨범 필드 보존 확인
      final firstExpected = expectedAlbums.first as Map;
      final restored = albumBox.values
          .map((v) => Album.fromMap(Map<String, dynamic>.from(v as Map)))
          .firstWhere((a) => a.id == firstExpected['id']);
      expect(restored.title, firstExpected['title']);
      expect(restored.artists, firstExpected['artists']);
    });
  });
}
