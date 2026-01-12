import 'package:flutter/material.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../services/i_album_repository.dart';

// region 열거형 정의
enum SortOption { custom, artist, title, dateDescending, dateAscending }

enum AlbumView { collection, wishlist }

enum ViewMode { grid2, grid3, artists }
//endregion

/// 홈 화면 뷰모델
class HomeViewModel extends ChangeNotifier {
  // endregion

  // region 의존성
  final IAlbumRepository _repository;
  final TextEditingController searchController = TextEditingController();
  //endregion

  // endregion

  // region 상태 필드
  bool _isLoading = false;
  List<Album> _allAlbums = [];
  String _searchQuery = "";
  bool isSearching = false;
  SortOption _sortOption = SortOption.custom;
  AlbumView _currentView = AlbumView.collection;
  bool isReorderMode = false;
  bool _isPerformingReorder = false;
  ViewMode _viewMode = ViewMode.grid2;
  //endregion

  // endregion

  // region Getter 메서드
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  SortOption get sortOption => _sortOption;
  AlbumView get currentView => _currentView;
  ViewMode get viewMode => _viewMode;
  //endregion

  // endregion

  // region 생성자 및 생명주기
  HomeViewModel(this._repository) {
    _repository.listenable.addListener(loadAlbums);
    loadAlbums();
    searchController.addListener(() {
      if (_searchQuery != searchController.text) {
        setSearchQuery(searchController.text);
      }
    });
  }

  @override
  void dispose() {
    _repository.listenable.removeListener(loadAlbums);
    searchController.dispose();
    super.dispose();
  }
  //endregion

  // endregion

  // region 데이터 로딩
  Future<void> loadAlbums() async {
    if (_isPerformingReorder) return;

    _isLoading = true;
    notifyListeners();
    try {
      _allAlbums = await _repository.getAll();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  //endregion

  // endregion

  // region UI 상태 관리
  void toggleSearch() {
    isSearching = !isSearching;
    if (!isSearching) {
      searchController.clear();
    }
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortOption(SortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void setView(AlbumView view) {
    _currentView = view;
    notifyListeners();
  }

  void toggleReorderMode() {
    isReorderMode = !isReorderMode;
    if (isReorderMode) {
      setSortOption(SortOption.custom);
    }
    notifyListeners();
  }

  void setViewMode(ViewMode mode) {
    _viewMode = mode;
    notifyListeners();
  }

  void toggleViewMode() {
    if (_viewMode == ViewMode.grid2) {
      _viewMode = ViewMode.grid3;
    } else if (_viewMode == ViewMode.grid3) {
      _viewMode = ViewMode.artists;
    } else {
      _viewMode = ViewMode.grid2;
    }
    notifyListeners();
  }
  //endregion

  // endregion

  // region 앨범 작업
  Future<void> deleteAlbum(String albumId) async {
    await _repository.delete(albumId);
  }

  Future<void> toggleWishlistStatus(String albumId) async {
    final album = _allAlbums.firstWhere((a) => a.id == albumId);
    final updatedAlbum = album.copyWith(isWishlist: !album.isWishlist);
    await _repository.update(albumId, updatedAlbum);
    await loadAlbums();
  }
  //endregion

  // endregion

  // region 재정렬 로직
  Future<void> reorderAlbums(int oldIndex, int newIndex) async {
    await _repository.reorder(oldIndex, newIndex);
  }

  void reorderInView(int oldIndex, int newIndex, AlbumView view) {
    if (oldIndex == newIndex) return;

    final visible = getAlbumsForView(view);

    // 안전성 검사
    if (oldIndex < 0 || oldIndex >= visible.length) return;

    final movingItem = visible[oldIndex];
    final realOldIndex = _allAlbums.indexOf(movingItem);
    if (realOldIndex == -1) return;

    int realNewIndex;
    if (newIndex >= visible.length) {
      final lastVisible = visible.last;
      final realLastIndex = _allAlbums.indexOf(lastVisible);
      realNewIndex = realLastIndex + 1;
    } else {
      final targetItem = visible[newIndex];
      realNewIndex = _allAlbums.indexOf(targetItem);
    }

    if (realNewIndex == -1) return;

    // 낙관적 업데이트
    int insertIndex = realNewIndex;
    _allAlbums.removeAt(realOldIndex);

    if (insertIndex < 0) insertIndex = 0;
    if (insertIndex > _allAlbums.length) insertIndex = _allAlbums.length;

    _allAlbums.insert(insertIndex, movingItem);
    notifyListeners();

    _isPerformingReorder = true;
    reorderAlbums(realOldIndex, realNewIndex)
        .then((_) {
          _isPerformingReorder = false;
          loadAlbums();
        })
        .catchError((e) {
          _isPerformingReorder = false;
          loadAlbums();
        });
  }
  //endregion

  // endregion

  // region 필터링 및 정렬
  List<Album> getAlbumsForView(AlbumView view) {
    // 1. 뷰 타입으로 필터링
    var filtered = _allAlbums.where((album) {
      if (view == AlbumView.collection) {
        return !album.isWishlist;
      } else {
        return album.isWishlist;
      }
    }).toList();

    // 2. 검색어로 필터링
    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      // 별명 포함한 아티스트 검색 결과 가져오기
      final matchedArtists = _repository.getArtistNamesMatching(_searchQuery);

      filtered = filtered
          .where(
            (album) =>
                album.title.toLowerCase().contains(lowerQuery) ||
                album.artist.toLowerCase().contains(lowerQuery) ||
                // 별명 매칭 추가
                matchedArtists.contains(album.artist) ||
                album.genres.any((g) => g.toLowerCase().contains(lowerQuery)) ||
                album.styles.any((s) => s.toLowerCase().contains(lowerQuery)) ||
                album.formats.any((f) => f.toLowerCase().contains(lowerQuery)),
          )
          .toList();
    }

    // 3. 정렬
    switch (_sortOption) {
      case SortOption.artist:
        filtered.sort(
          (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
        );
        break;
      case SortOption.title:
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case SortOption.dateDescending:
        filtered.sort((a, b) {
          if (a.releaseDate.date == null && b.releaseDate.date == null) {
            return 0;
          }
          if (a.releaseDate.date == null) return 1;
          if (b.releaseDate.date == null) return -1;
          return b.releaseDate.date!.compareTo(a.releaseDate.date!);
        });
        break;
      case SortOption.dateAscending:
        filtered.sort((a, b) {
          if (a.releaseDate.date == null && b.releaseDate.date == null) {
            return 0;
          }
          if (a.releaseDate.date == null) return 1;
          if (b.releaseDate.date == null) return -1;
          return a.releaseDate.date!.compareTo(b.releaseDate.date!);
        });
        break;
      case SortOption.custom:
        break;
    }
    return filtered;
  }

  /// 현재 뷰의 필터링된 앨범 (레거시 호환)
  List<Album> get filteredAlbums => getAlbumsForView(_currentView);

  // region 아티스트 작업
  List<Artist> getArtistsForCurrentView() {
    // 1. 현재 필터링된 앨범 목록 가져오기 (검색/뷰타입 적용됨)
    final albums = getAlbumsForView(_currentView);

    // 2. 유니크 아티스트 이름 추출
    final uniqueNames = albums.map((a) => a.artist).toSet();

    // 3. Artist 객체로 변환
    final artists = uniqueNames.map((name) {
      final existing = _repository.getArtistByName(name);
      if (existing != null) return existing;

      // 저장소에 아티스트 정보가 없는 경우 (단순 앨범 아티스트)
      // 임시 객체 생성 (ID는 이름으로 해시하거나 임의 생성)
      return Artist(id: 'temp_${name.hashCode}', name: name);
    }).toList();

    // 4. 이름순 정렬
    artists.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return artists;
  }

  //endregion
  //endregion
}
