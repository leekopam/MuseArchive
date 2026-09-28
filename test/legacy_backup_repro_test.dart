import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path;

import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/services/album_repository.dart';

/// 구버전(Prototype_1 시대) 앱이 생성한 백업 포맷 호환 테스트.
/// 당시 포맷: 'artist' 단수 문자열 필드, artists.json에 imagePath 없음,
/// 앨범 imagePath는 기기 절대경로, 이미지는 images/ 폴더에 원본 파일명으로 저장.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('구버전 백업 zip 복원 호환', () {
    late Directory sandbox;
    late Box albumBox;
    late Box artistBox;
    late AlbumRepository repository;

    setUp(() async {
      await Hive.close();
      sandbox = await Directory.systemTemp.createTemp('legacy_backup_repro_');

      final hiveDir = Directory(path.join(sandbox.path, 'hive'));
      await hiveDir.create(recursive: true);
      Hive.init(hiveDir.path);

      albumBox = await Hive.openBox('albumBox');
      artistBox = await Hive.openBox('artistBox');
      repository = AlbumRepository();
    });

    tearDown(() async {
      await Hive.close();
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    Future<Directory> makeDirs() async {
      final tempDir = Directory(path.join(sandbox.path, 'temp'));
      await tempDir.create(recursive: true);
      final appDir = Directory(path.join(sandbox.path, 'app'));
      await appDir.create(recursive: true);
      return tempDir;
    }

    Future<String> buildLegacyZip(
      Directory Function(Directory dir) layout, {
      required String name,
    }) async {
      final src = Directory(path.join(sandbox.path, 'src_$name'));
      await src.create(recursive: true);
      layout(src);
      final zipPath = path.join(sandbox.path, '$name.zip');
      ZipFileEncoder().zipDirectory(src, filename: zipPath);
      return zipPath;
    }

    test('artist 단수 필드 + 절대경로 imagePath의 구버전 백업이 복원된다', () async {
      final zipPath = await buildLegacyZip((src) {
        File(path.join(src.path, 'albums.json')).writeAsStringSync(
          jsonEncode([
            {
              'id': 'legacy-1',
              'title': '옛날 앨범',
              'artist': '옛날 가수',
              'description': '',
              'labels': <String>['Label A'],
              'imagePath': '/data/user/0/com.old/files/album_images/cover.jpg',
              'formats': <String>['CD'],
              'releaseDate': '2020.01.01',
              'genres': <String>['Rock'],
              'styles': <String>[],
              'linkUrl': null,
              'tracks': <Map<String, dynamic>>[],
              'isLimited': false,
              'isSpecial': false,
              'isWishlist': false,
            },
          ]),
        );
        File(path.join(src.path, 'artists.json')).writeAsStringSync(
          jsonEncode([
            {
              'id': 'a-1',
              'name': '옛날 가수',
              'albumIds': <String>['legacy-1'],
            },
          ]),
        );
        final imageFile = File(path.join(src.path, 'images', 'cover.jpg'));
        imageFile.parent.createSync(recursive: true);
        imageFile.writeAsBytesSync(<int>[1, 2, 3]);
        return src;
      }, name: 'legacy');

      final tempDir = await makeDirs();
      final appDir = Directory(path.join(sandbox.path, 'app'));

      final success = await repository.importBackupFromZipPath(
        zipPath,
        tempDir: tempDir,
        appDir: appDir,
        timestamp: 1,
      );

      expect(success, isTrue);
      expect(albumBox.length, 1);
      expect(artistBox.length, 1);
      final restored = Album.fromMap(
        Map<String, dynamic>.from(albumBox.getAt(0) as Map),
      );
      expect(restored.title, '옛날 앨범');
      expect(restored.artists, contains('옛날 가수'));
      expect(restored.imagePath, isNotNull);
    });

    test('zip 루트에 폴더가 중첩된 백업도 albums.json을 찾아 복원된다', () async {
      final zipPath = await buildLegacyZip((src) {
        final inner = Directory(path.join(src.path, 'backup_123'));
        inner.createSync(recursive: true);
        File(path.join(inner.path, 'albums.json')).writeAsStringSync(
          jsonEncode([
            {'id': 'nested-1', 'title': '중첩 앨범', 'artist': '가수'},
          ]),
        );
        return src;
      }, name: 'nested');

      final tempDir = await makeDirs();
      final appDir = Directory(path.join(sandbox.path, 'app'));

      final success = await repository.importBackupFromZipPath(
        zipPath,
        tempDir: tempDir,
        appDir: appDir,
        timestamp: 2,
      );

      expect(success, isTrue);
      expect(albumBox.length, 1);
      final restored = Album.fromMap(
        Map<String, dynamic>.from(albumBox.getAt(0) as Map),
      );
      expect(restored.title, '중첩 앨범');
    });

    test('리스트 필드가 문자열인 구버전 항목도 정규화해 복원된다', () async {
      final zipPath = await buildLegacyZip((src) {
        File(path.join(src.path, 'albums.json')).writeAsStringSync(
          jsonEncode([
            {
              'id': 'weird-1',
              'title': '이상한 앨범',
              'artist': '가수',
              'labels': 'Single Label',
              'formats': 'CD, LP',
              'genres': 'Rock',
              'styles': '',
            },
            {'id': 'ok-2', 'title': '정상 앨범', 'artist': '가수2'},
          ]),
        );
        return src;
      }, name: 'stringlist');

      final tempDir = await makeDirs();
      final appDir = Directory(path.join(sandbox.path, 'app'));

      final success = await repository.importBackupFromZipPath(
        zipPath,
        tempDir: tempDir,
        appDir: appDir,
        timestamp: 3,
      );

      expect(success, isTrue);
      expect(albumBox.length, 2);
      final restored = Album.fromMap(
        Map<String, dynamic>.from(albumBox.getAt(0) as Map),
      );
      expect(restored.labels, contains('Single Label'));
      expect(restored.formats, containsAll(<String>['CD', 'LP']));
    });

    test('albums.json이 Map 래퍼 형태여도 내부 리스트로 복원된다', () async {
      final zipPath = await buildLegacyZip((src) {
        File(path.join(src.path, 'albums.json')).writeAsStringSync(
          jsonEncode({
            'albums': [
              {'id': 'w1', 'title': '래퍼 앨범', 'artist': '가수'},
            ],
          }),
        );
        return src;
      }, name: 'wrapped');

      final tempDir = await makeDirs();
      final appDir = Directory(path.join(sandbox.path, 'app'));

      final success = await repository.importBackupFromZipPath(
        zipPath,
        tempDir: tempDir,
        appDir: appDir,
        timestamp: 4,
      );

      expect(success, isTrue);
      expect(albumBox.length, 1);
    });

    test('파싱 불가 항목은 건너뛰고 건전한 항목만 복원한다', () async {
      final zipPath = await buildLegacyZip((src) {
        File(path.join(src.path, 'albums.json')).writeAsStringSync(
          jsonEncode([
            'not-a-map-entry',
            42,
            {'id': 'ok-1', 'title': '살아남은 앨범', 'artist': '가수'},
          ]),
        );
        return src;
      }, name: 'mixed');

      final tempDir = await makeDirs();
      final appDir = Directory(path.join(sandbox.path, 'app'));

      final success = await repository.importBackupFromZipPath(
        zipPath,
        tempDir: tempDir,
        appDir: appDir,
        timestamp: 5,
      );

      expect(success, isTrue);
      expect(albumBox.length, 1);
      expect(repository.lastBackupSkippedCount, 2);
    });

    test('전 항목이 파싱 불가면 기존 데이터를 지우지 않고 실패한다', () async {
      await albumBox.add(
        Album(
          id: 'keep-1',
          title: '기존 앨범',
          artists: const <String>['기존'],
        ).toMap(),
      );

      final zipPath = await buildLegacyZip((src) {
        File(
          path.join(src.path, 'albums.json'),
        ).writeAsStringSync(jsonEncode(['bad-entry']));
        return src;
      }, name: 'allbad');

      final tempDir = await makeDirs();
      final appDir = Directory(path.join(sandbox.path, 'app'));

      final success = await repository.importBackupFromZipPath(
        zipPath,
        tempDir: tempDir,
        appDir: appDir,
        timestamp: 6,
      );

      expect(success, isFalse);
      expect(albumBox.length, 1);
      expect(repository.lastBackupRestoreError, isNotNull);
    });
  });
}
