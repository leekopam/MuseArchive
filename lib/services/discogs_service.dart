import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/album.dart';
import '../models/track.dart';
import '../models/value_objects/release_date.dart';

class DiscogsService {
  static final DiscogsService _instance = DiscogsService._internal();
  factory DiscogsService() => _instance;
  DiscogsService._internal();

  static const String _baseUrl = 'https://api.discogs.com';
  static const String _tokenKey = 'discogs_api_token';

  Future<String?> _getApiToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<http.Response?> _authenticatedGet(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    final token = await _getApiToken();
    if (token == null || token.isEmpty) {
      debugPrint("오류: Discogs API 토큰이 설정되지 않았습니다.");
      return null;
    }

    final uri = Uri.parse('$_baseUrl$endpoint')
        .replace(queryParameters: queryParams);
    
    final headers = {
      'User-Agent': 'MuseArchiveApp/1.0',
      'Authorization': 'Discogs token=$token',
    };

    return await http.get(uri, headers: headers);
  }

  Future<List<Map<String, dynamic>>> searchAlbumsByTitleArtist({
    String? artist,
    required String title,
  }) async {
    try {
      final queryParams = {
        'type': 'release',
        'per_page': '20',
        'release_title': title,
      };
      if (artist != null && artist.isNotEmpty) {
        queryParams['artist'] = artist;
      }

      final response = await _authenticatedGet('/database/search', queryParams: queryParams);

      if (response != null && response.statusCode == 200) {
        final searchData = jsonDecode(response.body);
        final results = searchData['results'] as List;
        
        return results.map((result) => {
          'id': result['id'],
          'title': result['title'] ?? '',
          'artist': result['artist'] ?? '', // Add artist to the result map
          'year': result['year']?.toString() ?? '',
          'thumb': result['thumb'] ?? '',
          'format': (result['format'] as List?)?.join(', ') ?? '',
        }).toList();
      }
    } catch (e) {
      debugPrint("Discogs 검색 오류: $e");
    }

    return [];
  }

  Future<Album?> fetchAlbumById(int releaseId) async {
    try {
      final rawData = await _fetchRawAlbumDetails(releaseId);
      if (rawData != null) {
        String? localImagePath;
        if (rawData['images'] != null && (rawData['images'] as List).isNotEmpty) {
          final imageUrl = rawData['images'][0]['resource_url'];
          if (imageUrl != null) {
            localImagePath = await _downloadAndSaveImage(
              imageUrl,
              releaseId.toString(),
            );
          }
        }
        return _createAlbumFromRawData(rawData, localImagePath);
      }
    } catch (e) {
      debugPrint("Discogs ID 검색 오류: $e");
    }

    return null;
  }

  Future<Album?> fetchAlbumByBarcode(String barcode) async {
    try {
      final response = await _authenticatedGet('/database/search', queryParams: {
        'barcode': barcode,
        'type': 'release',
      });

      if (response != null && response.statusCode == 200) {
        final searchData = jsonDecode(response.body);
        final results = searchData['results'] as List;

        if (results.isNotEmpty) {
          final releaseId = results[0]['id'];
          final rawData = await _fetchRawAlbumDetails(releaseId);

          if (rawData != null) {
            String? localImagePath;
            if (rawData['images'] != null && (rawData['images'] as List).isNotEmpty) {
              final imageUrl = rawData['images'][0]['resource_url'];
              if (imageUrl != null) {
                localImagePath = await _downloadAndSaveImage(
                  imageUrl,
                  releaseId.toString(),
                );
              }
            }

            return _createAlbumFromRawData(rawData, localImagePath);
          }
        }
      }
    } catch (e) {
      debugPrint("Discogs 검색 오류: $e");
    }

    return null;
  }

  Future<String?> _downloadAndSaveImage(
    String imageUrl,
    String fileNameBase,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {'User-Agent': 'MuseArchiveApp/1.0'},
      );

      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final extension = path.extension(imageUrl);
        final localPath = path.join(
          directory.path,
          'discogs_$fileNameBase$extension',
        );
        final imageFile = File(localPath);
        await imageFile.writeAsBytes(response.bodyBytes);
        return localPath;
      }
    } catch (e) {
      debugPrint("이미지 다운로드 실패: $e");
    }

    return null;
  }

  Future<Map<String, dynamic>?> _fetchRawAlbumDetails(int releaseId) async {
    try {
      final response = await _authenticatedGet('/releases/$releaseId');

      if (response != null && response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("상세 정보 요청 실패: $e");
    }

    return null;
  }

  Album _createAlbumFromRawData(
    Map<String, dynamic> data,
    String? localImagePath,
  ) {
    String artist = '';
    if (data['artists'] != null && (data['artists'] as List).isNotEmpty) {
      artist = data['artists'][0]['name'];
      artist = artist.replaceAll(RegExp(r'\s\(\d+\)$'), '');
    }

    List<Track> tracks = [];
    if (data['tracklist'] != null) {
      for (var track in data['tracklist']) {
        tracks.add(Track(
          title: track['title'] ?? '',
          titleKr: '',
          isHeader: track['type_'] == 'heading',
        ));
      }
    }

    String releaseDate = data['released'] ?? '';
    releaseDate = releaseDate.replaceAll('-', '.');

    return Album(
      title: data['title'] ?? '',
      artist: artist,
      description: data['notes'] ?? '',
      labels: data['labels'] != null && (data['labels'] as List).isNotEmpty
          ? [data['labels'][0]['name']]
          : [],
      imagePath: localImagePath,
      formats: data['formats'] != null && (data['formats'] as List).isNotEmpty
          ? [(data['formats'][0]['descriptions'] as List?)?.join(', ') ?? 
             data['formats'][0]['name']]
          : ['CD'],
      releaseDate: ReleaseDate.parse(releaseDate),
      genres: data['genres'] != null 
          ? (data['genres'] as List).map((e) => e.toString()).toList()
          : [],
      styles: data['styles'] != null
          ? (data['styles'] as List).map((e) => e.toString()).toList()
          : [],
      tracks: tracks,
      linkUrl: null,
    );
  }
}
