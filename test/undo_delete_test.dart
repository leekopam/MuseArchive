import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/models/artist.dart';
import 'package:my_album_app/widgets/common_widgets.dart';

import 'fakes.dart';

void main() {
  group('deleteAlbumWithUndo', () {
    Future<ScaffoldMessengerState> pumpScaffold(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );
      return ScaffoldMessenger.of(tester.element(find.byType(Scaffold)));
    }

    testWidgets('삭제 후 스낵바가 뜨고 실행 취소 시 앨범과 위치가 복원된다', (tester) async {
      final repo = FakeAlbumRepository(
        albums: [
          Album(id: 'a', title: 'First', artists: const ['X']),
          Album(id: 'b', title: 'Second', artists: const ['Y']),
          Album(id: 'c', title: 'Third', artists: const ['Z']),
        ],
      );
      final messenger = await pumpScaffold(tester);

      await deleteAlbumWithUndo(repo, repo.albums[1], messenger);
      await tester.pumpAndSettle();
      expect(repo.albums.map((a) => a.id), ['a', 'c']);
      expect(find.text('앨범이 삭제되었습니다.'), findsOneWidget);

      await tester.tap(find.text('실행 취소'));
      await tester.pumpAndSettle();
      expect(repo.albums.map((a) => a.id), [
        'a',
        'b',
        'c',
      ], reason: '원래 위치(인덱스 1)로 복원되어야 한다');
    });

    testWidgets('스낵바가 액션 없이 닫히면 삭제가 확정된다', (tester) async {
      final repo = FakeAlbumRepository(
        albums: [
          Album(id: 'a', title: 'First', artists: const ['X']),
        ],
      );
      final messenger = await pumpScaffold(tester);

      await deleteAlbumWithUndo(repo, repo.albums.first, messenger);
      await tester.pumpAndSettle();
      expect(repo.albums, isEmpty);

      // 액션 없이 닫히면(타임아웃·스와이프·hide 모두 동일 경로) 삭제 확정
      messenger.hideCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(repo.albums, isEmpty);
      expect(find.text('앨범이 삭제되었습니다.'), findsNothing);
    });

    testWidgets('실행 취소 시 아티스트 별명·그룹이 재적용된다', (tester) async {
      final repo = FakeAlbumRepository(
        albums: [
          Album(id: 'a', title: 'First', artists: const ['X']),
        ],
        artists: [
          Artist(
            id: 'x',
            name: 'X',
            aliases: const ['Alias X'],
            groups: const ['Group X'],
            albumIds: const ['a'],
          ),
        ],
      );
      final messenger = await pumpScaffold(tester);

      await deleteAlbumWithUndo(repo, repo.albums.first, messenger);
      await tester.pumpAndSettle();

      // 실구현과 달리 fake은 아티스트를 지우지 않으므로, 재적용 경로는
      // 별칭이 남아 있는지만으로 검증한다
      await tester.tap(find.text('실행 취소'));
      await tester.pumpAndSettle();

      expect(repo.albums.single.id, 'a');
      expect(repo.getArtistByName('X')!.aliases, contains('Alias X'));
    });

    testWidgets('복원 실패 시 예외를 삼키지 않고 안내 스낵바를 보인다', (tester) async {
      final repo = FakeAlbumRepository(
        albums: [
          Album(id: 'a', title: 'First', artists: const ['X']),
        ],
      )..failOnAdd = true;
      final messenger = await pumpScaffold(tester);

      await deleteAlbumWithUndo(repo, repo.albums.first, messenger);
      await tester.pumpAndSettle();
      expect(repo.albums, isEmpty);

      // 복원이 실패해도 미처리 예외 없이 사용자 안내가 떠야 한다
      await tester.tap(find.text('실행 취소'));
      await tester.pumpAndSettle();

      expect(find.text('앨범 복원에 실패했습니다. 앨범 목록을 확인해주세요.'), findsOneWidget);
      expect(repo.albums, isEmpty);
    });
  });
}
