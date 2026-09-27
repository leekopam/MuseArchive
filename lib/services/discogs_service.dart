import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/album.dart';
import '../models/track.dart';
import '../models/value_objects/release_date.dart';

typedef DiscogsTokenProvider = Future<String?> Function();
typedef DiscogsHttpGet =
    Future<http.Response> Function(Uri uri, {Map<String, String>? headers});

/// Discogs 요청 실패를 UI 계층까지 전달하기 위한 예외
class DiscogsServiceException implements Exception {
  const DiscogsServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Discogs API 서비스
class DiscogsService {
  // region 싱글톤 패턴
  static final DiscogsService _instance = DiscogsService._internal();
  factory DiscogsService() => _instance;
  DiscogsService._internal()
    : _tokenProvider = _readApiTokenFromPreferences,
      _get = http.get,
      _imageGet = http.get,
      _apiTimeout = const Duration(seconds: 15);

  @visibleForTesting
  DiscogsService.forTesting({
    DiscogsTokenProvider? tokenProvider,
    DiscogsHttpGet? get,
    DiscogsHttpGet? imageGet,
    Duration apiTimeout = const Duration(seconds: 15),
  }) : _tokenProvider = tokenProvider ?? _readApiTokenFromPreferences,
       _get = get ?? http.get,
       _imageGet = imageGet ?? http.get,
       _apiTimeout = apiTimeout;

  final DiscogsTokenProvider _tokenProvider;
  final DiscogsHttpGet _get;
  final DiscogsHttpGet _imageGet;
  final Duration _apiTimeout;
  //endregion

  // endregion

  // region 상수
  static const String _baseUrl = 'https://api.discogs.com';
  static const String _tokenKey = 'discogs_api_token';
  //endregion

  // endregion

  // region 인증 및 HTTP 요청
  static Future<String?> _readApiTokenFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<http.Response> _authenticatedGet(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    final token = (await _tokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      debugPrint("오류: Discogs API 토큰이 설정되지 않았습니다.");
      throw const DiscogsServiceException(
        'Discogs API 토큰이 설정되지 않았습니다. 설정에서 토큰을 입력해주세요.',
      );
    }

    final uri = Uri.parse(
      '$_baseUrl$endpoint',
    ).replace(queryParameters: queryParams);

    final headers = {
      'User-Agent': 'MuseArchiveApp/1.0',
      'Authorization': 'Discogs token=$token',
    };

    // 타임아웃이 없으면 응답 지연 시 UI가 무한 로딩에 빠진다
    final http.Response response;
    try {
      response = await _requestWithTimeout(uri, headers);
    } on TimeoutException {
      throw const DiscogsServiceException(
        'Discogs 응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.',
      );
    } on SocketException {
      // DNS 실패·오프라인 등 연결 자체가 안 되는 경우를 구분해 안내한다
      throw const DiscogsServiceException(
        '네트워크에 연결할 수 없습니다. 인터넷 연결을 확인한 뒤 다시 시도해주세요.',
      );
    }
    if (response.statusCode == 200) {
      return response;
    }

    throw DiscogsServiceException(_messageForStatusCode(response.statusCode));
  }

  // 간헐적 연결 지연은 새 요청으로 한 번 더 시도해 흡수한다
  Future<http.Response> _requestWithTimeout(
    Uri uri,
    Map<String, String> headers,
  ) async {
    try {
      return await _get(uri, headers: headers).timeout(_apiTimeout);
    } on TimeoutException {
      return _get(uri, headers: headers).timeout(_apiTimeout);
    }
  }

  static String _messageForStatusCode(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return 'Discogs 인증에 실패했습니다. 설정의 토큰을 확인해주세요.';
    }
    if (statusCode == 429) {
      return 'Discogs 요청 한도를 초과했습니다. 잠시 후 다시 시도해주세요.';
    }
    if (statusCode >= 500) {
      return 'Discogs 서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }
    return 'Discogs 요청에 실패했습니다. 상태 코드: $statusCode';
  }

  Future<bool> testConnection() async {
    try {
      await _authenticatedGet('/oauth/identity');
      return true;
    } catch (e) {
      debugPrint("Discogs 연결 테스트 실패: $e");
      return false;
    }
  }
  //endregion

  // endregion

  // region 검색
  Future<List<Map<String, dynamic>>> searchAlbumsByTitleArtist({
    String? artist,
    String? title,
  }) async {
    try {
      final queryParams = {'type': 'release', 'per_page': '20'};

      final queryList = <String>[];
      if (artist != null && artist.isNotEmpty) {
        queryList.add(artist);
      }
      if (title != null && title.isNotEmpty) {
        queryList.add(title);
      }

      if (queryList.isEmpty) {
        return [];
      }

      queryParams['q'] = queryList.join(' ');

      final response = await _authenticatedGet(
        '/database/search',
        queryParams: queryParams,
      );

      final searchData = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (searchData['results'] as List?) ?? const [];

      return results
          .map(
            (result) => {
              'id': result['id'],
              'title': result['title'] ?? '',
              'artist': result['artist'] ?? '',
              'year': result['year']?.toString() ?? '',
              'thumb': result['thumb'] ?? '',
              'format': (result['format'] as List?)?.join(', ') ?? '',
            },
          )
          .toList();
    } on DiscogsServiceException {
      rethrow;
    } catch (e) {
      debugPrint("Discogs 검색 오류: $e");
      throw const DiscogsServiceException(
        'Discogs 검색 응답을 처리할 수 없습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요.',
      );
    }
  }

  Future<Album?> fetchAlbumByBarcode(String barcode) async {
    try {
      final response = await _authenticatedGet(
        '/database/search',
        queryParams: {'barcode': barcode, 'type': 'release'},
      );

      final searchData = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (searchData['results'] as List?) ?? const [];

      if (results.isNotEmpty) {
        final releaseId = results[0]['id'];
        final rawData = await _fetchRawAlbumDetails(releaseId);

        String? localImagePath;
        if (rawData['images'] != null &&
            (rawData['images'] as List).isNotEmpty) {
          final imageUrl = rawData['images'][0]['resource_url'];
          if (imageUrl != null) {
            localImagePath = await downloadAndSaveImage(
              imageUrl,
              releaseId.toString(),
            );
          }
        }

        return _createAlbumFromRawData(rawData, localImagePath);
      }
    } on DiscogsServiceException {
      rethrow;
    } catch (e) {
      debugPrint("Discogs 검색 오류: $e");
      throw const DiscogsServiceException(
        'Discogs 바코드 검색 중 오류가 발생했습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요.',
      );
    }

    return null;
  }
  //endregion

  // endregion

  // region 앨범 조회
  Future<Album> fetchAlbumById(int releaseId) async {
    try {
      final rawData = await _fetchRawAlbumDetails(releaseId);

      String? localImagePath;
      if (rawData['images'] != null && (rawData['images'] as List).isNotEmpty) {
        final imageUrl = rawData['images'][0]['resource_url'];
        if (imageUrl != null) {
          localImagePath = await downloadAndSaveImage(
            imageUrl,
            releaseId.toString(),
          );
        }
      }
      return _createAlbumFromRawData(rawData, localImagePath);
    } on DiscogsServiceException {
      rethrow;
    } catch (e) {
      debugPrint("Discogs ID 검색 오류: $e");
      throw const DiscogsServiceException(
        'Discogs 앨범 정보를 불러오는 중 오류가 발생했습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요.',
      );
    }
  }

  Future<Map<String, dynamic>> _fetchRawAlbumDetails(int releaseId) async {
    try {
      final response = await _authenticatedGet('/releases/$releaseId');

      return jsonDecode(response.body) as Map<String, dynamic>;
    } on DiscogsServiceException {
      rethrow;
    } catch (e) {
      debugPrint("상세 정보 요청 실패: $e");
      throw const DiscogsServiceException(
        'Discogs 상세 정보를 처리할 수 없습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요.',
      );
    }
  }
  //endregion

  // endregion

  // region 이미지 다운로드
  Future<String?> downloadAndSaveImage(
    String imageUrl,
    String fileNameBase,
  ) async {
    try {
      final response = await _imageGet(
        Uri.parse(imageUrl),
        headers: {'User-Agent': 'MuseArchiveApp/1.0'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (!await _isDecodableImage(response.bodyBytes)) {
          debugPrint('이미지 다운로드 실패: 디코딩할 수 없는 이미지 데이터');
          return null;
        }

        final directory = await getTemporaryDirectory();
        final extension = path.extension(imageUrl).split('?').first;
        final ext = extension.isEmpty ? '.jpg' : extension;
        final localPath = path.join(
          directory.path,
          'discogs_$fileNameBase$ext',
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

  Future<bool> _isDecodableImage(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) {
      return false;
    }

    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(imageBytes);
      return true;
    } catch (e) {
      debugPrint('이미지 디코딩 실패: $e');
      return false;
    } finally {
      codec?.dispose();
    }
  }
  //endregion

  // endregion

  // region 데이터 변환
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
        tracks.add(
          Track(
            title: track['title'] ?? '',
            titleKr: '',
            isHeader: track['type_'] == 'heading',
          ),
        );
      }
    }

    String releaseDate = data['released'] ?? '';
    releaseDate = releaseDate.replaceAll('-', '.');

    final formatList =
        data['formats'] != null && (data['formats'] as List).isNotEmpty
        ? (data['formats'] as List).map<String>((f) {
            final name = f['name'] ?? '';
            final descriptions = (f['descriptions'] as List?)?.join(', ') ?? '';
            if (name.isNotEmpty && descriptions.isNotEmpty) {
              return '$name, $descriptions';
            }
            return name.isNotEmpty ? name : descriptions;
          }).toList()
        : ['CD'];

    final isLimited = formatList.any(
      (f) => f.toLowerCase().contains('limited edition'),
    );

    return Album(
      title: data['title'] ?? '',
      artists: [artist],
      description: data['notes'] ?? '',
      labels: data['labels'] != null && (data['labels'] as List).isNotEmpty
          ? (data['labels'] as List).map<String>((l) {
              String name = l['name'] ?? '';
              String catno = l['catno'] ?? '';
              if (name.isNotEmpty && catno.isNotEmpty) {
                return '$name - $catno';
              }
              return name.isNotEmpty ? name : catno;
            }).toList()
          : [],
      imagePath: localImagePath,
      formats: formatList,
      releaseDate: ReleaseDate.parse(releaseDate),
      genres: data['genres'] != null
          ? (data['genres'] as List).map((e) => e.toString()).toList()
          : [],
      styles: data['styles'] != null
          ? (data['styles'] as List).map((e) => e.toString()).toList()
          : [],
      tracks: tracks,
      linkUrl: null,
      isLimited: isLimited,
    );
  }

  //endregion
}
