import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path;

import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/models/artist.dart';
import 'package:my_album_app/services/album_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AlbumRepository backup core methods', () {
    late Directory sandbox;
    late Box albumBox;
    late Box artistBox;
    late AlbumRepository repository;

    setUp(() async {
      await Hive.close();
      sandbox = await Directory.systemTemp.createTemp(
        'musearchive_backup_test_',
      );

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

    test(
      'exportBackupFromTempDirectory includes album and artist assets',
      () async {
        final sourceDir = Directory(path.join(sandbox.path, 'source'));
        await sourceDir.create(recursive: true);

        final albumImage = File(path.join(sourceDir.path, 'cover.jpg'));
        await albumImage.writeAsBytes(<int>[1, 2, 3]);

        final artistImage = File(path.join(sourceDir.path, 'artist.png'));
        await artistImage.writeAsBytes(<int>[4, 5, 6]);

        final album = Album(
          id: 'album-1',
          title: 'Restored Album',
          artists: const <String>['Restored Artist'],
          imagePath: albumImage.path,
        );
        final artist = Artist(
          id: 'artist-1',
          name: 'Restored Artist',
          imagePath: artistImage.path,
          albumIds: const <String>['album-1'],
        );

        await albumBox.add(album.toMap());
        await artistBox.add(artist.toMap());

        final tempDir = Directory(path.join(sandbox.path, 'temp'));
        await tempDir.create(recursive: true);

        final zipPath = await repository.exportBackupFromTempDirectory(
          tempDir,
          timestamp: 123,
        );

        expect(zipPath, isNotNull);

        final archive = ZipDecoder().decodeBytes(
          await File(zipPath!).readAsBytes(),
        );
        final fileNames = archive.files.map((file) => file.name).toSet();

        expect(fileNames, contains('albums.json'));
        expect(fileNames, contains('artists.json'));
        expect(fileNames, contains('images/album_album-1_cover.jpg'));
        expect(fileNames, contains('artist_images/artist_artist-1_artist.png'));
      },
    );

    test(
      'importBackupFromZipPath returns false when albums.json is missing',
      () async {
        final zipPath = path.join(sandbox.path, 'invalid_backup.zip');
        final noteFile = File(path.join(sandbox.path, 'note.txt'));
        await noteFile.writeAsString('missing albums file');

        final encoder = ZipFileEncoder();
        encoder.create(zipPath);
        await encoder.addFile(noteFile);
        encoder.close();

        final tempDir = Directory(path.join(sandbox.path, 'temp'));
        await tempDir.create(recursive: true);
        final appDir = Directory(path.join(sandbox.path, 'app'));
        await appDir.create(recursive: true);

        final success = await repository.importBackupFromZipPath(
          zipPath,
          tempDir: tempDir,
          appDir: appDir,
          timestamp: 456,
        );

        expect(success, isFalse);
        expect(albumBox.isEmpty, isTrue);
        expect(artistBox.isEmpty, isTrue);
      },
    );

    test(
      'importBackupFromZipPath restores albums, artists, and staged images',
      () async {
        await albumBox.add(
          Album(
            id: 'old-album',
            title: 'Old Album',
            artists: const <String>['Old Artist'],
          ).toMap(),
        );
        await artistBox.add(
          Artist(
            id: 'old-artist',
            name: 'Old Artist',
            albumIds: const <String>['old-album'],
          ).toMap(),
        );

        final backupSource = Directory(
          path.join(sandbox.path, 'backup_source'),
        );
        final imageDir = Directory(path.join(backupSource.path, 'images'));
        final artistImageDir = Directory(
          path.join(backupSource.path, 'artist_images'),
        );
        await imageDir.create(recursive: true);
        await artistImageDir.create(recursive: true);

        final coverImage = File(path.join(imageDir.path, 'cover.jpg'));
        await coverImage.writeAsBytes(<int>[7, 8, 9]);
        final artistImage = File(path.join(artistImageDir.path, 'artist.png'));
        await artistImage.writeAsBytes(<int>[10, 11, 12]);

        final restoredAlbum = Album(
          id: 'album-1',
          title: 'Restored Album',
          artists: const <String>['Restored Artist'],
          imagePath: 'images/cover.jpg',
        );
        final restoredArtist = Artist(
          id: 'artist-1',
          name: 'Restored Artist',
          imagePath: 'artist_images/artist.png',
          albumIds: const <String>['album-1'],
        );

        await File(path.join(backupSource.path, 'albums.json')).writeAsString(
          jsonEncode(<Map<String, dynamic>>[restoredAlbum.toMap()]),
        );
        await File(path.join(backupSource.path, 'artists.json')).writeAsString(
          jsonEncode(<Map<String, dynamic>>[restoredArtist.toMap()]),
        );

        final zipPath = path.join(sandbox.path, 'restore_backup.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipPath);
        await encoder.addFile(
          File(path.join(backupSource.path, 'albums.json')),
        );
        await encoder.addFile(
          File(path.join(backupSource.path, 'artists.json')),
        );
        await encoder.addFile(coverImage, 'images/cover.jpg');
        await encoder.addFile(artistImage, 'artist_images/artist.png');
        encoder.close();

        final tempDir = Directory(path.join(sandbox.path, 'temp'));
        await tempDir.create(recursive: true);
        final appDir = Directory(path.join(sandbox.path, 'app'));
        await appDir.create(recursive: true);

        final staleAlbumImagesDir = Directory(
          path.join(appDir.path, 'album_images'),
        );
        await staleAlbumImagesDir.create(recursive: true);
        final staleImage = File(
          path.join(staleAlbumImagesDir.path, 'stale.txt'),
        );
        await staleImage.writeAsString('stale');

        final success = await repository.importBackupFromZipPath(
          zipPath,
          tempDir: tempDir,
          appDir: appDir,
          timestamp: 789,
        );

        expect(success, isTrue);
        expect(albumBox.length, 1);
        expect(artistBox.length, 1);
        expect(await staleImage.exists(), isFalse);

        final restoredAlbumMap = Map<String, dynamic>.from(
          albumBox.getAt(0) as Map,
        );
        final restoredArtistMap = Map<String, dynamic>.from(
          artistBox.getAt(0) as Map,
        );

        final storedAlbum = Album.fromMap(restoredAlbumMap);
        final storedArtist = Artist.fromMap(restoredArtistMap);

        final expectedAlbumImagePath = path.join(
          appDir.path,
          'album_images',
          'album_album-1.jpg',
        );
        final expectedArtistImagePath = path.join(
          appDir.path,
          'artist_images',
          'artist_artist-1.png',
        );

        expect(storedAlbum.title, 'Restored Album');
        expect(storedAlbum.imagePath, expectedAlbumImagePath);
        expect(await File(expectedAlbumImagePath).exists(), isTrue);

        expect(storedArtist.name, 'Restored Artist');
        expect(storedArtist.imagePath, expectedArtistImagePath);
        expect(await File(expectedArtistImagePath).exists(), isTrue);
      },
    );
  });
}
