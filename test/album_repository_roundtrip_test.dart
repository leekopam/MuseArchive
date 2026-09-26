import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/models/track.dart';
import 'package:my_album_app/services/album_repository.dart';

import 'boogle_hook.dart';
import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AlbumRepository E2E 왕복', () {
    late Directory sandbox;
    late Box albumBox;
    late Box artistBox;
    late AlbumRepository repository;
    late PathProviderPlatform originalPathProvider;

    setUp(() async {
      originalPathProvider = PathProviderPlatform.instance;

      await Hive.close();
      sandbox = await Directory.systemTemp.createTemp(
        'musearchive_roundtrip_test_',
      );

      final hiveDir = Directory(path.join(sandbox.path, 'hive'));
      await hiveDir.create(recursive: true);
      Hive.init(hiveDir.path);

      albumBox = await Hive.openBox('albumBox');
      artistBox = await Hive.openBox('artistBox');
      repository = AlbumRepository();
    });

    tearDown(() async {
      PathProviderPlatform.instance = originalPathProvider;
      await Hive.close();
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    // S01·S02 데이터 측: 결정적 시드의 CRUD·정렬 동작
    test('S01·S02 시드 앨범 CRUD와 reorder 순서가 유지된다', () async {
      await _seedAlbums(repository);

      var albums = await repository.getAll();
      await BoogleHook.metric(
        'e2e/seed.albums',
        value: albums.length,
        unit: 'count',
        thresholdValue: 1,
      );
      expect(albums.map((a) => a.id), ['seed-1', 'seed-2', 'seed-3']);

      await repository.reorder(0, 1);
      albums = await repository.getAll();
      expect(albums.map((a) => a.id), ['seed-2', 'seed-1', 'seed-3']);

      await repository.update(
        'seed-1',
        albums[1].copyWith(title: 'Updated Title', isWishlist: true),
      );
      albums = await repository.getAll();
      expect(albums[1].title, 'Updated Title');
      expect(albums[1].isWishlist, isTrue);

      await repository.delete('seed-3');
      albums = await repository.getAll();
      expect(albums.map((a) => a.id), ['seed-2', 'seed-1']);
    });

    // S05: add()는 커버 이미지를 앱 문서 폴더로 복사한다
    test('S05 커버 이미지가 문서 폴더로 복사되고 경로가 재기록된다', () async {
      final docsDir = Directory(path.join(sandbox.path, 'docs'));
      await docsDir.create(recursive: true);
      PathProviderPlatform.instance = FakePathProviderPlatform(
        applicationDocumentsPath: docsDir.path,
      );

      final sourceImage = File(path.join(sandbox.path, 'source_cover.jpg'));
      await sourceImage.writeAsBytes(<int>[1, 2, 3, 4]);

      await repository.add(
        Album(
          id: 'img-1',
          title: 'Cover Album',
          artists: const ['Cover Artist'],
          imagePath: sourceImage.path,
        ),
      );

      final stored = (await repository.getAll()).single;
      expect(stored.imagePath, isNotNull);
      expect(
        stored.imagePath,
        startsWith('${docsDir.path}/album_images'),
      );
      expect(stored.imagePath, contains('img-1'));
      expect(stored.imagePath, endsWith('.jpg'));
      expect(await File(stored.imagePath!).exists(), isTrue);
    });

    // S06: 디스크 헤더를 포함한 트랙 편집의 저장·재조회
    test('S06 트랙 편집(순서·삭제·헤더)이 저장 후 재조회에 유지된다', () async {
      await repository.add(
        Album(
          id: 'trk-1',
          title: 'Track Album',
          artists: const ['Track Artist'],
          tracks: [
            Track(id: 't1', title: 'Song A'),
            Track(id: 'h1', title: 'Disc 2', isHeader: true),
            Track(id: 't2', title: 'Song B'),
          ],
        ),
      );

      final original = (await repository.getAll()).single;
      final edited = original.copyWith(
        tracks: [
          original.tracks[1], // Disc 2 헤더를 앞으로
          original.tracks[2], // Song B
          Track(id: 't3', title: 'Song C'),
        ],
      );
      await repository.update('trk-1', edited);

      final stored = (await repository.getAll()).single;
      expect(stored.tracks.map((t) => t.id), ['h1', 't2', 't3']);
      expect(stored.tracks[0].isHeader, isTrue);
      expect(stored.tracks[2].title, 'Song C');
    });

    // S11: export→초기화→import 왕복 데이터 동일성
    test('S11 백업 왕복 후 앨범·아티스트 데이터가 동일하다', () async {
      await _seedAlbums(repository);
      final beforeExport = await repository.getAll();

      final tempDir = Directory(path.join(sandbox.path, 'temp'));
      await tempDir.create(recursive: true);
      final zipPath = await repository.exportBackupFromTempDirectory(
        tempDir,
        timestamp: 1000,
      );
      expect(zipPath, isNotNull);

      final zipFile = File(zipPath!);
      final zipSize = await zipFile.length();
      await BoogleHook.metric(
        'e2e/backup.sizeBytes',
        value: zipSize,
        unit: 'bytes',
        direction: 'lower',
      );
      await BoogleHook.artifact(
        zipPath,
        fileName: 'roundtrip-backup.zip',
        kind: 'output',
      );

      await albumBox.clear();
      await artistBox.clear();

      final restoreTemp = Directory(path.join(sandbox.path, 'restore-temp'));
      await restoreTemp.create(recursive: true);
      final appDir = Directory(path.join(sandbox.path, 'app'));
      await appDir.create(recursive: true);

      final success = await repository.importBackupFromZipPath(
        zipPath,
        tempDir: restoreTemp,
        appDir: appDir,
        timestamp: 2000,
      );
      expect(success, isTrue);

      final afterImport = await repository.getAll();
      final equal = _sameAlbumSet(beforeExport, afterImport);
      await BoogleHook.metric(
        'e2e/roundtrip.equal',
        value: equal ? 1 : 0,
        unit: 'bool',
        thresholdValue: 1,
      );
      expect(equal, isTrue);

      final artists = repository.getAllArtists();
      expect(artists.length, 2);
      expect(artists.map((a) => a.name).toSet(), {'Artist One', 'Artist Two'});
    });
  });
}

/// 결정적 시드 — id·제목 고정, imagePath 없음(문서 폴더 접근 회피)
Future<void> _seedAlbums(AlbumRepository repository) async {
  await repository.add(
    Album(
      id: 'seed-1',
      title: 'Alpha Album',
      artists: const ['Artist One'],
      formats: const ['LP'],
      genres: const ['Rock'],
      tracks: [Track(id: 's1-t1', title: 'Alpha Song')],
    ),
  );
  await repository.add(
    Album(
      id: 'seed-2',
      title: 'Beta Album',
      artists: const ['Artist One', 'Artist Two'],
      formats: const ['CD'],
      isLimited: true,
    ),
  );
  await repository.add(
    Album(
      id: 'seed-3',
      title: 'Gamma Album',
      artists: const ['Artist Two'],
      isWishlist: true,
    ),
  );
}

/// imagePath는 복원 시 재기록되므로 비교에서 제외한다
bool _sameAlbumSet(List<Album> before, List<Album> after) {
  if (before.length != after.length) return false;
  String normalize(Album album) {
    final map = album.toMap()..remove('imagePath');
    return jsonEncode(map);
  }

  final beforeSet = before.map(normalize).toSet();
  return after.every((album) => beforeSet.contains(normalize(album)));
}

