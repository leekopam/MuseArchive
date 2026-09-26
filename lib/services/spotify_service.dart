import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

typedef SpotifyCredentialProvider = Future<SpotifyCredentials?> Function();
typedef SpotifyHttpPost =
    Future<http.Response> Function(
      Uri uri, {
      Map<String, String>? headers,
      Object? body,
      Encoding? encoding,
    });
typedef SpotifyHttpGet =
    Future<http.Response> Function(Uri uri, {Map<String, String>? headers});

/// Spotify 인증 정보
class SpotifyCredentials {
  const SpotifyCredentials({
    required this.clientId,
    required this.clientSecret,
  });

  final String clientId;
  final String clientSecret;

  String get normalizedClientId => clientId.trim();
  String get normalizedClientSecret => clientSecret.trim();
  bool get isConfigured =>
      normalizedClientId.isNotEmpty && normalizedClientSecret.isNotEmpty;
}

/// Spotify 요청 실패를 UI 계층까지 전달하기 위한 예외
class SpotifyServiceException implements Exception {
  const SpotifyServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Spotify API 서비스
class SpotifyService {
  // region 싱글톤 패턴
  static final SpotifyService _instance = SpotifyService._internal();
  factory SpotifyService() => _instance;
  SpotifyService._internal()
    : _credentialProvider = _readCredentialsFromPreferences,
      _post = http.post,
      _get = http.get;

  @visibleForTesting
  SpotifyService.forTesting({
    SpotifyCredentialProvider? credentialProvider,
    SpotifyHttpPost? post,
    SpotifyHttpGet? get,
  }) : _credentialProvider =
           credentialProvider ?? _readCredentialsFromPreferences,
       _post = post ?? http.post,
       _get = get ?? http.get;

  final SpotifyCredentialProvider _credentialProvider;
  final SpotifyHttpPost _post;
  final SpotifyHttpGet _get;
  //endregion

  // endregion

  // region 상수
  static const String clientIdPrefsKey = 'spotify_client_id';
  static const String clientSecretPrefsKey = 'spotify_client_secret';
  static const String _authUrl = 'https://accounts.spotify.com/api/token';
  static const String _baseUrl = 'https://api.spotify.com/v1';
  //endregion

  // endregion

  // region 상태 필드
  String? _accessToken;
  DateTime? _tokenExpiry;
  //endregion

  // endregion

  // region 인증
  static Future<SpotifyCredentials?> _readCredentialsFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return SpotifyCredentials(
      clientId: prefs.getString(clientIdPrefsKey) ?? '',
      clientSecret: prefs.getString(clientSecretPrefsKey) ?? '',
    );
  }

  Future<String> _getAccessToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        _tokenExpiry!.isAfter(DateTime.now())) {
      return _accessToken!;
    }

    final credentials = await _credentialProvider();
    if (credentials == null || !credentials.isConfigured) {
      debugPrint('Spotify Client ID/Secret not set');
      throw const SpotifyServiceException(
        'Spotify 키가 설정되지 않았습니다. 설정에서 Client ID와 Client Secret을 입력해주세요.',
      );
    }

    final response = await _requestAccessToken(credentials);
    if (response.statusCode != 200) {
      debugPrint('Spotify 인증 실패: ${response.statusCode}');
      throw SpotifyServiceException(_messageForStatusCode(response.statusCode));
    }

    try {
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Spotify 인증 응답 형식이 올바르지 않습니다.');
      }

      final token = data['access_token'];
      final expiresIn = data['expires_in'];
      if (token is! String || token.isEmpty || expiresIn is! int) {
        throw const FormatException('Spotify 인증 토큰 정보가 없습니다.');
      }

      _accessToken = token;
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
      return token;
    } catch (e) {
      debugPrint('Spotify 인증 응답 처리 오류');
      throw const SpotifyServiceException(
        'Spotify 인증 응답을 처리할 수 없습니다. 잠시 후 다시 시도해주세요.',
      );
    }
  }

  Future<http.Response> _requestAccessToken(
    SpotifyCredentials credentials,
  ) async {
    try {
      return await _post(
        Uri.parse(_authUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization':
              'Basic ${base64Encode(utf8.encode('${credentials.normalizedClientId}:${credentials.normalizedClientSecret}'))}',
        },
        body: {'grant_type': 'client_credentials'},
      );
    } catch (e) {
      debugPrint('Spotify 인증 요청 오류');
      throw const SpotifyServiceException(
        'Spotify 요청 중 오류가 발생했습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요.',
      );
    }
  }

  Future<bool> hasConfiguredCredentials() async {
    final credentials = await _credentialProvider();
    return credentials?.isConfigured ?? false;
  }

  Future<bool> testConnection() async {
    _accessToken = null;
    _tokenExpiry = null;

    try {
      await _getAccessToken();
      return true;
    } catch (e) {
      debugPrint('Spotify 연결 테스트 실패');
      return false;
    }
  }

  static String _messageForStatusCode(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return 'Spotify 인증에 실패했습니다. 설정의 Client ID/Secret을 확인해주세요.';
    }
    if (statusCode == 429) {
      return 'Spotify 요청 한도를 초과했습니다. 잠시 후 다시 시도해주세요.';
    }
    if (statusCode >= 500) {
      return 'Spotify 서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }
    return 'Spotify 요청에 실패했습니다. 상태 코드: $statusCode';
  }
  //endregion

  // endregion

  // region 앨범 검색
  Future<List<Map<String, String>>> searchAlbums(String query) async {
    if (query.trim().isEmpty) return [];

    final token = await _getAccessToken();
    final response = await _requestAlbumSearch(query, token);
    if (response.statusCode != 200) {
      debugPrint('Spotify 검색 실패: ${response.statusCode}');
      throw SpotifyServiceException(_messageForStatusCode(response.statusCode));
    }

    try {
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Spotify 검색 응답 형식이 올바르지 않습니다.');
      }

      final albumsData = data['albums'];
      if (albumsData is! Map<String, dynamic>) {
        throw const FormatException('Spotify 앨범 응답이 없습니다.');
      }

      final albums = albumsData['items'];
      if (albums is! List) {
        throw const FormatException('Spotify 앨범 목록이 없습니다.');
      }

      return albums.map<Map<String, String>>(_albumToSearchResult).toList();
    } catch (e) {
      debugPrint('Spotify 검색 응답 처리 오류');
      throw const SpotifyServiceException(
        'Spotify 검색 응답을 처리할 수 없습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요.',
      );
    }
  }

  Future<http.Response> _requestAlbumSearch(String query, String token) async {
    try {
      return await _get(
        Uri.parse(
          '$_baseUrl/search?q=${Uri.encodeComponent(query)}&type=album&limit=20',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      debugPrint('Spotify 검색 요청 오류');
      throw const SpotifyServiceException(
        'Spotify 요청 중 오류가 발생했습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요.',
      );
    }
  }

  Map<String, String> _albumToSearchResult(dynamic album) {
    if (album is! Map<String, dynamic>) {
      throw const FormatException('Spotify 앨범 항목 형식이 올바르지 않습니다.');
    }

    final images = album['images'];
    var imageUrl = '';
    if (images is List && images.isNotEmpty) {
      final firstImage = images.first;
      if (firstImage is Map<String, dynamic>) {
        imageUrl = firstImage['url']?.toString() ?? '';
      }
    }

    final artistsData = album['artists'];
    final artists = artistsData is List
        ? artistsData
              .whereType<Map<String, dynamic>>()
              .map((artist) => artist['name']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .join(', ')
        : '';

    final externalUrls = album['external_urls'];
    final externalUrl = externalUrls is Map<String, dynamic>
        ? externalUrls['spotify']?.toString() ?? ''
        : '';

    return {
      'id': album['id']?.toString() ?? '',
      'title': album['name']?.toString() ?? '',
      'artist': artists,
      'image_url': imageUrl,
      'release_date': album['release_date']?.toString() ?? '',
      'external_url': externalUrl,
    };
  }
  //endregion

  // endregion

  // region 이미지 다운로드
  Future<List<int>?> downloadImage(String url) async {
    try {
      final response = await _get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('Spotify Image Download Error');
    }
    return null;
  }

  //endregion
}
