import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Spotify API 서비스
class SpotifyService {
  // region 싱글톤 패턴
  static final SpotifyService _instance = SpotifyService._internal();
  factory SpotifyService() => _instance;
  SpotifyService._internal();
  //endregion

  // endregion

  // region 상수
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
  Future<String?> _getAccessToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        _tokenExpiry!.isAfter(DateTime.now())) {
      return _accessToken;
    }

    final prefs = await SharedPreferences.getInstance();
    final clientId = prefs.getString('spotify_client_id');
    final clientSecret = prefs.getString('spotify_client_secret');

    if (clientId == null ||
        clientId.isEmpty ||
        clientSecret == null ||
        clientSecret.isEmpty) {
      debugPrint("Spotify Client ID/Secret not set");
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(_authUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
        },
        body: {'grant_type': 'client_credentials'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        final expiresIn = data['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
        return _accessToken;
      } else {
        debugPrint(
          "Spotify Auth Failed: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      debugPrint("Spotify Auth Error: $e");
    }
    return null;
  }

  Future<bool> testConnection() async {
    _accessToken = null;
    _tokenExpiry = null;

    final token = await _getAccessToken();
    return token != null;
  }
  //endregion

  // endregion

  // region 앨범 검색
  Future<List<Map<String, String>>> searchAlbums(String query) async {
    final token = await _getAccessToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/search?q=${Uri.encodeComponent(query)}&type=album&limit=20',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final albums = data['albums']['items'] as List;

        return albums.map<Map<String, String>>((album) {
          final images = album['images'] as List;
          String imageUrl = '';
          if (images.isNotEmpty) {
            imageUrl = images[0]['url'];
          }

          final artists = (album['artists'] as List)
              .map((a) => a['name'].toString())
              .join(', ');

          final externalUrl =
              (album['external_urls'] as Map?)?['spotify'] as String?;

          return {
            'id': album['id'],
            'title': album['name'],
            'artist': artists,
            'image_url': imageUrl,
            'release_date': album['release_date'] ?? '',
            'external_url': externalUrl ?? '',
          };
        }).toList();
      }
    } catch (e) {
      debugPrint("Spotify Search Error: $e");
    }
    return [];
  }
  //endregion

  // endregion

  // region 이미지 다운로드
  Future<List<int>?> downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('Spotify Image Download Error: $e');
    }
    return null;
  }

  //endregion
}
