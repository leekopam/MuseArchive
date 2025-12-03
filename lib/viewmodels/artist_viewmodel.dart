import 'package:flutter/foundation.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../services/album_repository.dart';

class ArtistViewModel extends ChangeNotifier {
  final AlbumRepository _repository;

  ArtistViewModel(this._repository);

  List<Artist> _artists = [];
  List<Album> _artistAlbums = [];
  String? _currentArtistName;
  bool _isLoading = false;
  String? _errorMessage;

  List<Artist> get artists => _artists;
  List<Album> get artistAlbums => _artistAlbums;
  String? get currentArtistName => _currentArtistName;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  Future<void> loadArtistAlbums(String artistName) async {
    _isLoading = true;
    _errorMessage = null;
    _currentArtistName = artistName;
    notifyListeners();

    try {
      _artistAlbums = _repository.getAlbumsByArtist(artistName);
    } catch (e) {
      _errorMessage = '아티스트 앨범을 불러오는데 실패했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  int getArtistAlbumCount(String artistName) {
    final artist = _artists.firstWhere(
      (a) => a.name == artistName,
      orElse: () => Artist(name: artistName),
    );
    return artist.albumCount;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
