import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/album.dart';
import '../models/track.dart';
import '../models/value_objects/release_date.dart';

typedef MusicBrainzHttpGet =
    Future<http.Response> Function(Uri uri, {Map<String, String>? headers});

/// MusicBrainz 요청 실패를 UI 계층까지 전달하기 위한 예외
class MusicBrainzServiceException implements Exception {
  const MusicBrainzServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// MusicBrainz API 서비스
class MusicBrainzService {
  // region 싱글톤 패턴
  static final MusicBrainzService _instance = MusicBrainzService._internal();
  factory MusicBrainzService() => _instance;
  MusicBrainzService._internal()
    : _httpGet = http.get,
      _apiTimeout = const Duration(seconds: 15);

  @visibleForTesting
  MusicBrainzService.forTesting({
    MusicBrainzHttpGet? get,
    Duration apiTimeout = const Duration(seconds: 15),
  }) : _httpGet = get ?? http.get,
       _apiTimeout = apiTimeout;

  final MusicBrainzHttpGet _httpGet;
  final Duration _apiTimeout;
  //endregion

  // region 상수
  static const String _baseUrl = 'https://musicbrainz.org/ws/2';
  static const String _coverArtBaseUrl = 'https://coverartarchive.org';
  static const String _userAgent = 'MuseArchiveApp/1.0 (museArchive@app.com)';
  //endregion

  // region API 요청 헬퍼
  /// 매 요청마다 새 연결 생성 (VocaDB/Discogs와 동일 패턴, stale 연결 방지)
  Future<http.Response> _get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    final params = {'fmt': 'json', ...?queryParams};
    final uri = Uri.parse(
      '$_baseUrl$endpoint',
    ).replace(queryParameters: params);
    final headers = {'User-Agent': _userAgent, 'Accept': 'application/json'};

    try {
      // 타임아웃이 없으면 응답 지연 시 UI가 무한 로딩에 빠진다.
      // 간헐적 연결 지연은 새 요청으로 한 번 더 시도해 흡수한다.
      try {
        return await _httpGet(uri, headers: headers).timeout(_apiTimeout);
      } on TimeoutException {
        return await _httpGet(uri, headers: headers).timeout(_apiTimeout);
      }
    } on TimeoutException {
      throw const MusicBrainzServiceException(
        'MusicBrainz 응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.',
      );
    } catch (e) {
      debugPrint('MusicBrainz 요청 오류: $e');
      throw const MusicBrainzServiceException(
        'MusicBrainz 요청 중 오류가 발생했습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요.',
      );
    }
  }

  static String _messageForStatusCode(int statusCode) {
    if (statusCode == 429) {
      return 'MusicBrainz 요청 한도를 초과했습니다. 잠시 후 다시 시도해주세요.';
    }
    if (statusCode >= 500) {
      return 'MusicBrainz 서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }
    return 'MusicBrainz 요청에 실패했습니다. 상태 코드: $statusCode';
  }
  //endregion

  // region 검색
  /// 앨범 검색 (검색 결과 목록 반환)
  Future<List<Map<String, dynamic>>> searchAlbums(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      // rate limit(503) 시 1회 재시도
      late http.Response response;
      for (int attempt = 0; attempt < 2; attempt++) {
        response = await _get(
          '/release/',
          queryParams: {'query': query, 'limit': '20'},
        );

        if (response.statusCode == 503) {
          if (attempt == 0) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          throw MusicBrainzServiceException(
            _messageForStatusCode(response.statusCode),
          );
        }

        break;
      }

      if (response.statusCode != 200) {
        throw MusicBrainzServiceException(
          _messageForStatusCode(response.statusCode),
        );
      }

      final searchData = jsonDecode(response.body);
      if (searchData is! Map<String, dynamic>) {
        throw const FormatException('MusicBrainz 검색 응답 형식이 올바르지 않습니다.');
      }
      final releases = searchData['releases'];
      if (releases is! List) {
        throw const FormatException('MusicBrainz 검색 결과 목록이 없습니다.');
      }

      return releases.map(_releaseToSearchResult).toList();
    } on MusicBrainzServiceException {
      rethrow;
    } catch (e) {
      debugPrint('MusicBrainz 검색 오류: $e');
      throw const MusicBrainzServiceException(
        'MusicBrainz 검색 응답을 처리할 수 없습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요.',
      );
    }
  }

  Map<String, dynamic> _releaseToSearchResult(dynamic item) {
    if (item is! Map<String, dynamic>) {
      throw const FormatException('MusicBrainz 검색 항목 형식이 올바르지 않습니다.');
    }

    final id = item['id'] ?? '';
    final title = item['title'] ?? '';

    // 아티스트 파싱
    String artist = '';
    final artistCredits = item['artist-credit'];
    if (artistCredits is List && artistCredits.isNotEmpty) {
      artist = artistCredits
          .whereType<Map<String, dynamic>>()
          .map((ac) => ac['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .join(', ');
    }

    // 발매일에서 연도 추출
    String year = '';
    final date = item['date']?.toString() ?? '';
    if (date.isNotEmpty) {
      year = date.length >= 4 ? date.substring(0, 4) : date;
    }

    // 포맷 (media에서 추출)
    String format = '';
    final media = item['media'];
    if (media is List && media.isNotEmpty) {
      final firstMedia = media.first;
      if (firstMedia is Map<String, dynamic>) {
        format = firstMedia['format']?.toString() ?? '';
      }
    }

    return {
      'id': id,
      'title': title,
      'artist': artist,
      'year': year,
      'thumb': null, // 검색 결과에서 이미지 로드 시 연결 풀 점유로 API 타임아웃 발생
      'format': format,
    };
  }
  //endregion

  // region 앨범 상세 조회
  /// MBID로 앨범 상세 정보 조회
  Future<Album?> fetchAlbumById(String mbid) async {
    try {
      // API 데이터는 필수 — 조회 실패 시 커버아트 다운로드를 시작하지 않음
      final rawData = await _fetchReleaseData(mbid);
      if (rawData == null) {
        return null;
      }

      // 이미지는 API 완료 후 추가 3초만 대기, 초과 시 이미지 없이 진행
      String? localImagePath;
      try {
        localImagePath = await downloadAndSaveImage(
          mbid,
        ).timeout(const Duration(seconds: 3));
      } on TimeoutException {
        debugPrint('MusicBrainz 커버아트 다운로드 타임아웃 — 이미지 없이 진행');
      }

      return _createAlbumFromRawData(rawData, localImagePath, mbid);
    } on MusicBrainzServiceException {
      rethrow;
    } catch (e) {
      debugPrint('MusicBrainz ID 검색 오류: $e');
      throw const MusicBrainzServiceException(
        'MusicBrainz 앨범 응답을 처리할 수 없습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요.',
      );
    }
  }

  /// 릴리스 상세 데이터 조회 (503 재시도 포함)
  Future<Map<String, dynamic>?> _fetchReleaseData(String mbid) async {
    late http.Response response;
    for (int attempt = 0; attempt < 2; attempt++) {
      response = await _get(
        '/release/$mbid',
        queryParams: {'inc': 'recordings+artists+labels+media'},
      );

      if (response.statusCode == 503) {
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        throw MusicBrainzServiceException(
          _messageForStatusCode(response.statusCode),
        );
      }

      break;
    }

    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      throw MusicBrainzServiceException(
        _messageForStatusCode(response.statusCode),
      );
    }

    final rawData = jsonDecode(response.body);
    if (rawData is! Map<String, dynamic>) {
      throw const FormatException('MusicBrainz 앨범 응답 형식이 올바르지 않습니다.');
    }

    return rawData;
  }
  //endregion

  // region 데이터 변환
  Album _createAlbumFromRawData(
    Map<String, dynamic> data,
    String? localImagePath,
    String mbid,
  ) {
    // 아티스트 파싱
    List<String> parsedArtists = [];
    if (data['artist-credit'] != null) {
      for (var ac in (data['artist-credit'] as List)) {
        final name = ac['name']?.toString() ?? '';
        if (name.isNotEmpty) {
          parsedArtists.add(name.trim());
        }
      }
    }

    // 레이블 및 카탈로그 번호 파싱
    List<String> labels = [];
    String? catalogNumber;
    if (data['label-info'] != null) {
      for (var li in (data['label-info'] as List)) {
        if (li['label'] != null) {
          final labelName = li['label']['name']?.toString() ?? '';
          if (labelName.isNotEmpty && !labels.contains(labelName)) {
            labels.add(labelName);
          }
        }
        if (catalogNumber == null) {
          final catNo = li['catalog-number']?.toString().trim() ?? '';
          if (catNo.isNotEmpty) {
            catalogNumber = catNo;
          }
        }
      }
    }

    // 포맷 및 트랙 리스트 파싱
    List<String> formats = [];
    List<Track> tracks = [];
    if (data['media'] != null) {
      final mediaList = data['media'] as List;
      bool hasMultipleDiscs = mediaList.length > 1;

      for (var media in mediaList) {
        final mediaFormat = media['format']?.toString() ?? '';
        if (mediaFormat.isNotEmpty && !formats.contains(mediaFormat)) {
          formats.add(mediaFormat);
        }

        final discNum = media['position'] ?? 1;
        if (hasMultipleDiscs) {
          tracks.add(
            Track(title: 'Disc $discNum', isHeader: true, titleKr: ''),
          );
        }

        if (media['tracks'] != null) {
          for (var track in (media['tracks'] as List)) {
            final trackTitle = track['title']?.toString() ?? '';
            tracks.add(Track(title: trackTitle, titleKr: '', isHeader: false));
          }
        }
      }
    }

    // 발매일 (YYYY-MM-DD → YYYY.MM.DD)
    String releaseDate = '';
    final date = data['date']?.toString() ?? '';
    if (date.isNotEmpty) {
      releaseDate = date.replaceAll('-', '.');
    }

    String linkUrl = 'https://musicbrainz.org/release/$mbid';

    return Album(
      title: data['title'] ?? '',
      artists: parsedArtists,
      catalogNumber: catalogNumber,
      description: '',
      labels: labels,
      imagePath: localImagePath,
      formats: formats.isNotEmpty ? formats : ['CD'],
      releaseDate: ReleaseDate.parse(releaseDate),
      genres: [],
      styles: [],
      tracks: tracks,
      linkUrl: linkUrl,
      isLimited: false,
    );
  }
  //endregion

  // region 이미지 다운로드
  /// Cover Art Archive에서 프론트 커버 다운로드
  Future<String?> downloadAndSaveImage(String mbid) async {
    try {
      final response = await _httpGet(
        Uri.parse('$_coverArtBaseUrl/release/$mbid/front-500'),
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode == 200) {
        if (!await _isDecodableImage(response.bodyBytes)) {
          debugPrint('MusicBrainz 이미지 다운로드 실패: 디코딩할 수 없는 이미지 데이터');
          return null;
        }

        final directory = await getTemporaryDirectory();
        final localPath = path.join(directory.path, 'musicbrainz_$mbid.jpg');
        final imageFile = File(localPath);
        await imageFile.writeAsBytes(response.bodyBytes);
        return localPath;
      }
    } catch (e) {
      debugPrint("MusicBrainz 이미지 다운로드 실패: $e");
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
      debugPrint('MusicBrainz 이미지 디코딩 실패: $e');
      return false;
    } finally {
      codec?.dispose();
    }
  }

  //endregion
}
