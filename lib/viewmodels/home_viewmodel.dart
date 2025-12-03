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
  List<Album> get filteredAlbums => _getFilteredAndSortedAlbums();

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

  Future<void> loadAlbums() async {
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

  Future<void> toggleWishlistStatus(String albumId) async {
    final album = _allAlbums.firstWhere((a) => a.id == albumId);
    final updatedAlbum = album.copyWith(isWishlist: !album.isWishlist);
    await _repository.update(albumId, updatedAlbum);
    // The listener on the repository will trigger loadAlbums, but we can call it
    // manually to ensure the UI updates as quickly as possible.
    await loadAlbums();
  }

  List<Album> _getFilteredAndSortedAlbums() {
    var filtered = _allAlbums.toList();

    if (_currentView == AlbumView.collection) {
      filtered = filtered.where((album) => !album.isWishlist).toList();
    } else {
      filtered = filtered.where((album) => album.isWishlist).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      filtered = filtered.where((album) =>
        album.title.toLowerCase().contains(lowerQuery) ||
        album.artist.toLowerCase().contains(lowerQuery) ||
        album.genres.any((g) => g.toLowerCase().contains(lowerQuery)) ||
        album.styles.any((s) => s.toLowerCase().contains(lowerQuery)) ||
        album.formats.any((f) => f.toLowerCase().contains(lowerQuery))
      ).toList();
    }

    switch (_sortOption) {
      case SortOption.artist:
        filtered.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case SortOption.title:
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortOption.dateDescending:
        filtered.sort((a, b) {
          if (a.releaseDate.date == null && b.releaseDate.date == null) return 0;
          if (a.releaseDate.date == null) return 1;
          if (b.releaseDate.date == null) return -1;
          return b.releaseDate.date!.compareTo(a.releaseDate.date!);
        });
        break;
      case SortOption.dateAscending:
        filtered.sort((a, b) {
          if (a.releaseDate.date == null && b.releaseDate.date == null) return 0;
          if (a.releaseDate.date == null) return 1;
          if (b.releaseDate.date == null) return -1;
          return a.releaseDate.date!.compareTo(b.releaseDate.date!);
        });
        break;
      case SortOption.custom:
        // For custom sort, we rely on the order from the repository
        break;
    }
    return filtered;
  }
}
