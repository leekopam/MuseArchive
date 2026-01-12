import 'package:flutter/foundation.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../services/i_album_repository.dart';
import 'global_artist_settings.dart';

enum SortOrder { asc, desc }

/// 아티스트 뷰모델
class ArtistViewModel extends ChangeNotifier {
  // region 의존성
  final IAlbumRepository _repository;
  final GlobalArtistSettings _settings;
  //endregion

  // endregion

  // region 상태 필드
  List<Artist> _artists = [];
  List<Album> _artistAlbums = [];
  Artist? _currentArtist;
  bool _isLoading = false;
  String? _errorMessage;
  //endregion

  // endregion

  // region Getter 메서드
  List<Artist> get artists => _artists;
  List<Album> get artistAlbums => _artistAlbums;
  Artist? get currentArtist => _currentArtist;
  SortOrder get sortOrder => _settings.sortOrder;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  //endregion

  // endregion

  // region 생성자
  ArtistViewModel(this._repository, this._settings) {
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (_artistAlbums.isNotEmpty) {
      _artistAlbums = _sortAlbums(_artistAlbums);
      notifyListeners();
    }
  }
  //endregion

  // endregion

  // region 데이터 로딩
  Future<void> loadAllArtists() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _artists = _repository.getAllArtists();
      _artists.sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      _errorMessage = '아티스트 목록을 불러오는데 실패했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadArtistData(String artistName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_artists.isEmpty) {
        _artists = _repository.getAllArtists();
      }
      _currentArtist =
          _repository.getArtistByName(artistName) ?? Artist(name: artistName);
      final albums = _repository.getAlbumsByArtist(artistName);
      _artistAlbums = _sortAlbums(albums);
    } catch (e) {
      _errorMessage = '아티스트 데이터를 불러오는데 실패했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateArtistImage(String? imagePath) async {
    if (_currentArtist == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _repository.updateArtistImage(_currentArtist!.name, imagePath);
      // 업데이트된 데이터 다시 로드
      _currentArtist = _repository.getArtistByName(_currentArtist!.name);
    } catch (e) {
      _errorMessage = '이미지 업데이트 실패: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateArtistMetadata(
    List<String> aliases,
    List<String> groups,
  ) async {
    if (_currentArtist == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _repository.updateArtistMetadata(
        _currentArtist!.name,
        aliases,
        groups,
      );
      // 업데이트된 데이터 다시 로드
      _currentArtist = _repository.getArtistByName(_currentArtist!.name);
    } catch (e) {
      _errorMessage = '메타데이터 업데이트 실패: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleSortOrder() {
    _settings.toggleSortOrder();
  }

  List<Album> _sortAlbums(List<Album> albums) {
    if (albums.isEmpty) return [];

    final sorted = List<Album>.from(albums);
    sorted.sort((a, b) {
      final dateA = a.releaseDate.date;
      final dateB = b.releaseDate.date;

      // 날짜 없는 경우 처리 (항상 뒤로 보냄)
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return _settings.sortOrder == SortOrder.asc
          ? dateA.compareTo(dateB)
          : dateB.compareTo(dateA);
    });
    return sorted;
  }
  //endregion

  // endregion

  // region 유틸리티 메서드
  int getArtistAlbumCount(String artistName) {
    final artist = _artists.firstWhere(
      (a) => a.name == artistName,
      orElse: () => Artist(name: artistName),
    );
    return artist.albumCount;
  }

  /// 아티스트 검색 (이름 또는 별명)
  List<Artist> searchArtists(String query) {
    if (query.isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();

    return _artists.where((artist) {
      final nameMatch = artist.name.toLowerCase().contains(normalizedQuery);
      final aliasMatch = artist.aliases.any(
        (alias) => alias.toLowerCase().contains(normalizedQuery),
      );
      return nameMatch || aliasMatch;
    }).toList();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  //endregion
}
