import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SpotifyService {
  static final SpotifyService _instance = SpotifyService._internal();
  factory SpotifyService() => _instance;
  SpotifyService._internal();

  static const String _authUrl = 'https://accounts.spotify.com/api/token';
  static const String _baseUrl = 'https://api.spotify.com/v1';

  String? _accessToken;
  DateTime? _tokenExpiry;

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
        _tokenExpiry = DateTime.now().add(
          Duration(seconds: expiresIn - 60),
        ); // Buffer
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
    // _getAccessToken handles the logic of using Client ID/Secret to fetch a token.
    // If it returns a non-null string, it means authentication was successful.
    // We force a check even if we have a token, effectively verifying credentials if token is expired or by just trusting the current valid token.
    // To be sure, we can clear the token to force a re-auth check, but that might be wasteful.
    // A simple approach: Call _getAccessToken. If it works, we used the credentials successfully at some point.
    // If user CHANGED credentials, _getAccessToken might still return old token if we don't clear it.
    // So we should probably clear cached token if we want to test *current* storage/input (but here we read from storage).

    // For 'Test Connection' button context:
    // Usually user just saved new keys.
    // So we should invalidate current token to force a new fetch using new keys.
    _accessToken = null;
    _tokenExpiry = null;

    final token = await _getAccessToken();
    return token != null;
  }

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
          // Prefer high res (usually first), but fallback if empty
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

  // Method to assist with downloading the image bytes if needed by ViewModels
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
}
