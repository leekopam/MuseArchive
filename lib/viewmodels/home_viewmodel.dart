import 'package:flutter/material.dart';
import '../models/album.dart';
import '../services/i_album_repository.dart';

enum SortOption { custom, artist, title, dateDescending, dateAscending }

enum AlbumView { collection, wishlist }

class HomeViewModel extends ChangeNotifier {
  final IAlbumRepository _repository;
  final TextEditingController searchController = TextEditingController();

  HomeViewModel(this._repository) {
    _repository.listenable.addListener(loadAlbums);
    loadAlbums();
    searchController.addListener(() {
      if (_searchQuery != searchController.text) {
        setSearchQuery(searchController.text);
      }
    });
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Album> _allAlbums = [];

  String _searchQuery = "";
  String get searchQuery => _searchQuery;

  bool isSearching = false;

  SortOption _sortOption = SortOption.custom;
  SortOption get sortOption => _sortOption;

  AlbumView _currentView = AlbumView.collection;
  AlbumView get currentView => _currentView;

  bool isReorderMode = false;

  @override
  void dispose() {
    _repository.listenable.removeListener(loadAlbums);
    searchController.dispose();
    super.dispose();
  }

  void toggleSearch() {
    isSearching = !isSearching;
    if (!isSearching) {
      searchController.clear();
    }
    notifyListeners();
  }

  bool _isPerformingReorder = false;

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

  Future<void> deleteAlbum(String albumId) async {
    await _repository.delete(albumId);
    // The listener will call loadAlbums automatically
  }

  Future<void> reorderAlbums(int oldIndex, int newIndex) async {
    await _repository.reorder(oldIndex, newIndex);
    // The listener will call loadAlbums automatically
  }

  void reorderInView(int oldIndex, int newIndex, AlbumView view) {
    if (oldIndex == newIndex) return;

    final visible = getAlbumsForView(view);
    // Safety check
    if (oldIndex < 0 || oldIndex >= visible.length) return;

    final movingItem = visible[oldIndex];
    final realOldIndex = _allAlbums.indexOf(movingItem);
    if (realOldIndex == -1) return;

    int realNewIndex;
    if (newIndex >= visible.length) {
      // Insert after the last visible item
      final lastVisible = visible.last;
      final realLastIndex = _allAlbums.indexOf(lastVisible);
      realNewIndex = realLastIndex + 1;
    } else {
      final targetItem = visible[newIndex];
      realNewIndex = _allAlbums.indexOf(targetItem);
    }

    if (realNewIndex == -1) return;

    // Optimistic Update
    int insertIndex = realNewIndex;

    // NOTE: Removed (realOldIndex < realNewIndex) decrement logic to fix
    // "Left to Right" reorder bug.
    // ReorderableGridView provides the destination index such that we should
    // insert exactly there (capped by length).

    // We must clamp BEFORE insertion, considering the list size changes after removal.
    // But calculate clamp against current size for safety or just handle post-removal size.

    _allAlbums.removeAt(realOldIndex);

    // After removal, valid indices are 0 to length (inclusive for append).
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

  Future<void> toggleWishlistStatus(String albumId) async {
    final album = _allAlbums.firstWhere((a) => a.id == albumId);
    final updatedAlbum = album.copyWith(isWishlist: !album.isWishlist);
    await _repository.update(albumId, updatedAlbum);
    // The listener on the repository will trigger loadAlbums, but we can call it
    // manually to ensure the UI updates as quickly as possible.
    await loadAlbums();
  }

  // Modified to return albums for a SPECIFIC view, allowing both to be displayed in a PageView.
  List<Album> getAlbumsForView(AlbumView view) {
    // 1. Filter by View Type
    var filtered = _allAlbums.where((album) {
      if (view == AlbumView.collection) {
        return !album.isWishlist;
      } else {
        return album.isWishlist;
      }
    }).toList();

    // 2. Filter by Search Query (Applies to both)
    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (album) =>
                album.title.toLowerCase().contains(lowerQuery) ||
                album.artist.toLowerCase().contains(lowerQuery) ||
                album.genres.any((g) => g.toLowerCase().contains(lowerQuery)) ||
                album.styles.any((s) => s.toLowerCase().contains(lowerQuery)) ||
                album.formats.any((f) => f.toLowerCase().contains(lowerQuery)),
          )
          .toList();
    }

    // 3. Sort (Applies to both)
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
          if (a.releaseDate.date == null && b.releaseDate.date == null)
            return 0;
          if (a.releaseDate.date == null) return 1;
          if (b.releaseDate.date == null) return -1;
          return b.releaseDate.date!.compareTo(a.releaseDate.date!);
        });
        break;
      case SortOption.dateAscending:
        filtered.sort((a, b) {
          if (a.releaseDate.date == null && b.releaseDate.date == null)
            return 0;
          if (a.releaseDate.date == null) return 1;
          if (b.releaseDate.date == null) return -1;
          return a.releaseDate.date!.compareTo(b.releaseDate.date!);
        });
        break;
      case SortOption.custom:
        // For custom sort, we rely on the order from the repository (which we preserve implicitly by using toList() on _allAlbums first)
        break;
    }
    return filtered;
  }

  // Legacy getter if needed, but UI should ideally use getAlbumsForView
  List<Album> get filteredAlbums => getAlbumsForView(_currentView);
}
