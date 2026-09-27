import 'package:flutter_test/flutter_test.dart';
import 'package:my_album_app/models/album.dart';
import 'package:my_album_app/utils/korean_search_utils.dart';
import 'package:my_album_app/viewmodels/home_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  group('초성 검색 유틸', () {
    test('isChoseongQuery는 초성 전용 쿼리만 인정한다', () {
      expect(isChoseongQuery('ㅂㅌㅅ'), isTrue);
      expect(isChoseongQuery('ㄱㄴ'), isTrue);
      expect(isChoseongQuery('방탄'), isFalse); // 완성형 음절
      expect(isChoseongQuery('bts'), isFalse);
      expect(isChoseongQuery('ㅂtㅅ'), isFalse); // 혼합
      expect(isChoseongQuery(''), isFalse);
    });

    test('toChoseong은 한글 음절을 초성으로 변환한다', () {
      expect(toChoseong('방탄소년단'), 'ㅂㅌㅅㄴㄷ');
      expect(toChoseong('뉴진스'), 'ㄴㅈㅅ');
      expect(toChoseong('AB6IX'), 'AB6IX'); // 비한글은 그대로
      expect(toChoseong('아이유 IU'), 'ㅇㅇㅇ IU');
    });

    test('matchesChoseong은 공백을 무시하고 부분 매칭한다', () {
      expect(matchesChoseong('ㅂㅌㅅ', '방탄소년단'), isTrue);
      expect(matchesChoseong('ㅂㅌㅅ', '방 탄 소 년 단'), isTrue);
      expect(matchesChoseong('ㅈㅅ', '뉴진스'), isTrue); // 부분 매칭
      expect(matchesChoseong('ㅍㅌㅅ', '방탄소년단'), isFalse);
      expect(matchesChoseong('ㅂㅌㅅ', ''), isFalse);
    });
  });

  group('HomeViewModel 초성 검색', () {
    test('초성 쿼리가 제목·한국어제목·아티스트에 매칭된다', () async {
      final repo = FakeAlbumRepository(
        albums: [
          Album(id: '1', title: 'Dynamite', artists: const ['방탄소년단']),
          Album(
            id: '2',
            title: 'Hype Boy',
            titleKr: '하입 보이',
            artists: const ['뉴진스'],
          ),
          Album(id: '3', title: 'Love Dive', artists: const ['IVE']),
        ],
      );
      final vm = HomeViewModel(repo);
      await Future.delayed(Duration.zero);

      vm.setSearchQuery('ㅂㅌㅅ');
      expect(vm.filteredAlbums.map((a) => a.id), ['1']);

      vm.setSearchQuery('ㅎㅇㅂ');
      expect(vm.filteredAlbums.map((a) => a.id), ['2']);

      vm.setSearchQuery('ㄴㅈㅅ');
      expect(vm.filteredAlbums.map((a) => a.id), ['2']);
    });

    test('완성형 한글 쿼리는 기존 부분 문자열 매칭을 유지한다', () async {
      final repo = FakeAlbumRepository(
        albums: [
          Album(id: '1', title: 'Dynamite', artists: const ['방탄소년단']),
          Album(id: '2', title: 'Love Dive', artists: const ['IVE']),
        ],
      );
      final vm = HomeViewModel(repo);
      await Future.delayed(Duration.zero);

      vm.setSearchQuery('방탄');
      expect(vm.filteredAlbums.map((a) => a.id), ['1']);
    });
  });

  group('HomeViewModel 지속성', () {
    test('보기 모드와 정렬 옵션이 SharedPreferences에 저장·복원된다', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = FakeAlbumRepository();

      final vm = HomeViewModel(repo);
      await Future.delayed(Duration.zero);
      vm.setViewMode(ViewMode.grid3);
      vm.setSortOption(SortOption.artist);
      await Future.delayed(Duration.zero);

      final restored = HomeViewModel(repo);
      await Future.delayed(Duration.zero);
      expect(restored.viewMode, ViewMode.grid3);
      expect(restored.sortOption, SortOption.artist);
    });

    test('최근 검색어가 중복 제거·최대 8개로 유지되고 복원된다', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = FakeAlbumRepository();
      final vm = HomeViewModel(repo);
      await Future.delayed(Duration.zero);

      vm.recordSearch('  BTS  ');
      vm.recordSearch('뉴진스');
      vm.recordSearch('BTS'); // 공백 제거 후 같은 항목은 맨 앞으로
      await Future.delayed(Duration.zero);

      expect(vm.recentSearches, ['BTS', '뉴진스']);

      vm.removeRecentSearch('뉴진스');
      expect(vm.recentSearches, ['BTS']);

      for (var i = 0; i < 10; i++) {
        vm.recordSearch('term$i');
      }
      expect(vm.recentSearches.length, 8);

      final restored = HomeViewModel(repo);
      await Future.delayed(Duration.zero);
      expect(restored.recentSearches, vm.recentSearches);
    });

    test('applyRecentSearch는 검색 컨트롤러와 쿼리를 함께 갱신한다', () {
      SharedPreferences.setMockInitialValues({});
      final vm = HomeViewModel(FakeAlbumRepository());
      vm.applyRecentSearch('방탄소년단');
      expect(vm.searchController.text, '방탄소년단');
      expect(vm.searchQuery, '방탄소년단');
    });
  });
}
