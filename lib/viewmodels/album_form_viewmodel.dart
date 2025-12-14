import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/album.dart';
import '../models/track.dart';
import '../models/value_objects/release_date.dart';
import '../services/i_album_repository.dart';
import '../services/discogs_service.dart';
import '../services/ocr_service.dart';
import '../services/spotify_service.dart';

class AlbumFormViewModel extends ChangeNotifier {
  final IAlbumRepository _repository;
  final DiscogsService _discogsService;
  final OcrService _ocrService;
  final SpotifyService _spotifyService;

  AlbumFormViewModel(
    this._repository,
    this._discogsService,
    this._ocrService,
    this._spotifyService,
  );

  Album? _currentAlbum;
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasUnsavedChanges = false;

  Album? get currentAlbum => _currentAlbum;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  // ... (Initialization methods remain same)

  // ... (Other methods)

  Future<void> updateCoverFromUrl(String imageUrl) async {
    await updateFromSpotify(imageUrl: imageUrl);
  }

  Future<void> updateFromSpotify({
    required String imageUrl,
    String? linkUrl,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      // Create a temporary file path
      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}';
      final savedPath = await _discogsService.downloadAndSaveImage(
        imageUrl,
        fileName,
      ); // Reusing DiscogsService downloader for now or move to utilities

      if (savedPath != null) {
        _currentAlbum = _currentAlbum?.copyWith(
          imagePath: savedPath,
          linkUrl: (linkUrl != null && linkUrl.isNotEmpty)
              ? linkUrl
              : _currentAlbum?.linkUrl,
        );
        _hasUnsavedChanges = true;
      } else {
        _errorMessage = '이미지를 저장할 수 없습니다.';
      }
    } catch (e) {
      _errorMessage = '이미지 업데이트 실패: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, String>>> searchSpotifyForConnect(
    String query,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      return await _spotifyService.searchAlbums(query);
    } catch (e) {
      _errorMessage = 'Spotify 검색 실패: $e';
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Exposed for UI to check if we can use Spotify
  Future<bool> isSpotifyConfigured() async {
    // This check could actally be in SpotifyService but we can do a quick check via VM
    // Or just try specific call. For now, assuming UI handles keys check or service handles it.
    return true;
  }

  // ... (Rest existing methods)

  void initialize(Album? albumToEdit, bool isWishlist) {
    if (albumToEdit != null) {
      _currentAlbum = albumToEdit;
    } else {
      _currentAlbum = Album(
        title: '',
        artist: '',
        releaseDate: ReleaseDate(DateTime.now()),
        isWishlist: isWishlist,
        tracks: [],
        genres: [],
        styles: [],
        formats: [],
        labels: [],
      );
    }
    _hasUnsavedChanges = false;
    Future.microtask(notifyListeners);
  }

  void setAlbum(Album album) {
    _currentAlbum = album;
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  void updateCurrentAlbum(Album album) {
    _currentAlbum = album;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  Future<void> saveAlbum(String? albumId) async {
    if (_currentAlbum == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (albumId == null) {
        await _repository.add(_currentAlbum!);
      } else {
        await _repository.update(albumId, _currentAlbum!);
      }
      _hasUnsavedChanges = false;
    } catch (e) {
      _errorMessage = '앨범 저장에 실패했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchByBarcode(String barcode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final album = await _discogsService.fetchAlbumByBarcode(barcode);
      if (album != null) {
        _currentAlbum =
            _currentAlbum?.copyWith(
              title: album.title,
              artist: album.artist,
              releaseDate: album.releaseDate,
              imagePath: album.imagePath,
              tracks: album.tracks,
              genres: album.genres,
              styles: album.styles,
              formats: album.formats,
              labels: album.labels,
              description: album.description,
            ) ??
            album;
        _hasUnsavedChanges = true;
      } else {
        _errorMessage = '앨범을 찾을 수 없습니다.';
      }
    } catch (e) {
      _errorMessage = '검색 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> searchByTitleArtist({
    String? artist,
    String? title,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await _discogsService.searchAlbumsByTitleArtist(
        artist: artist,
        title: title,
      );
      return results;
    } catch (e) {
      _errorMessage = '검색 중 오류가 발생했습니다: $e';
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAlbumById(int releaseId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final album = await _discogsService.fetchAlbumById(releaseId);
      if (album != null) {
        _currentAlbum = album.copyWith(
          id: _currentAlbum?.id,
          isWishlist: _currentAlbum?.isWishlist,
          description:
              (album.description.isEmpty &&
                  _currentAlbum?.description.isNotEmpty == true)
              ? _currentAlbum!.description
              : album.description,
        );
        _hasUnsavedChanges = true;
      } else {
        _errorMessage = '앨범 정보를 불러올 수 없습니다.';
      }
    } catch (e) {
      _errorMessage = '앨범 로드 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> scanAlbumCover(String imagePath) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final extractedText = await _ocrService.extractTextFromImage(imagePath);
      if (extractedText.isEmpty) {
        _errorMessage = '텍스트를 찾을 수 없습니다.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final searchQuery = _ocrService.parseAlbumInfo(extractedText);
      if (searchQuery.isEmpty) {
        _errorMessage = '앨범 정보를 인식할 수 없습니다.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final results = await _discogsService.searchAlbumsByTitleArtist(
        title: searchQuery,
      );
      if (results.isNotEmpty) {
        await loadAlbumById(results.first['id']);
      } else {
        _errorMessage = '검색 결과가 없습니다.';
      }
    } catch (e) {
      _errorMessage = 'OCR 처리 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> pickImage() async {
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);
    return pickedFile?.path;
  }

  void addTrack(Track track) {
    if (_currentAlbum == null) return;
    final updatedTracks = [..._currentAlbum!.tracks, track];
    _currentAlbum = _currentAlbum!.copyWith(tracks: updatedTracks);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void updateTrack(int index, Track track) {
    if (_currentAlbum == null ||
        index < 0 ||
        index >= _currentAlbum!.tracks.length) {
      return;
    }

    final updatedTracks = List<Track>.from(_currentAlbum!.tracks);
    updatedTracks[index] = track;

    _currentAlbum = _currentAlbum!.copyWith(tracks: updatedTracks);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void removeTrack(int index) {
    if (_currentAlbum == null) return;
    final updatedTracks = List<Track>.from(_currentAlbum!.tracks);
    updatedTracks.removeAt(index);
    _currentAlbum = _currentAlbum!.copyWith(tracks: updatedTracks);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void reorderTracks(int oldIndex, int newIndex) {
    if (_currentAlbum == null) return;
    final updatedTracks = List<Track>.from(_currentAlbum!.tracks);
    if (oldIndex < newIndex) newIndex -= 1;
    final track = updatedTracks.removeAt(oldIndex);
    updatedTracks.insert(newIndex, track);
    _currentAlbum = _currentAlbum!.copyWith(tracks: updatedTracks);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void addNewDisc() {
    if (_currentAlbum == null) return;

    final discHeaders = _currentAlbum!.tracks.where((t) => t.isHeader);
    final nextDiscNum = discHeaders.length + 1;
    final newHeader = Track(title: 'Disc $nextDiscNum', isHeader: true);

    final updatedTracks = [..._currentAlbum!.tracks, newHeader];

    updateCurrentAlbum(_currentAlbum!.copyWith(tracks: updatedTracks));
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  List<String> getArtistSuggestions(String query) {
    return _repository.getSmartArtistSuggestions(query);
  }

  Map<String, List<String>> getAllOptions() {
    return {
      'formats': _repository.getAllFormats(),
      'genres': _repository.getAllGenres(),
      'styles': _repository.getAllStyles(),
      'labels': _repository.getAllLabels(),
    };
  }
}
