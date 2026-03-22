import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/album.dart';
import '../models/track.dart';
import '../models/value_objects/release_date.dart';

/// MusicBrainz API 서비스
class MusicBrainzService {
  // region 싱글톤 패턴
  static final MusicBrainzService _instance = MusicBrainzService._internal();
  factory MusicBrainzService() => _instance;
  MusicBrainzService._internal();
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
      return await http.get(uri, headers: headers);
    } on SocketException {
      throw Exception('네트워크 연결을 확인해주세요.');
    }
  }
  //endregion

  // region 검색
  /// 앨범 검색 (검색 결과 목록 반환)
  Future<List<Map<String, dynamic>>> searchAlbums(String query) async {
    if (query.trim().isEmpty) return [];

    // rate limit(503) 시 1회 재시도
    late http.Response response;
    for (int attempt = 0; attempt < 2; attempt++) {
      response = await _get(
        '/release/',
        queryParams: {
          'query': query,
          'limit': '20',
        },
      );

      if (response.statusCode == 503) {
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        throw Exception('MusicBrainz 서버가 일시적으로 사용 불가합니다. 잠시 후 다시 시도해주세요.');
      }

      break;
    }

    if (response.statusCode != 200) {
      throw Exception('MusicBrainz 검색 실패 (HTTP ${response.statusCode})');
    }

    final searchData = jsonDecode(response.body);
    final releases = searchData['releases'] as List? ?? [];

    return releases.map((item) {
      final id = item['id'] ?? '';
      final title = item['title'] ?? '';

      // 아티스트 파싱
      String artist = '';
      if (item['artist-credit'] != null &&
          (item['artist-credit'] as List).isNotEmpty) {
        artist = (item['artist-credit'] as List)
            .map((ac) => ac['name'] ?? '')
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
      if (item['media'] != null && (item['media'] as List).isNotEmpty) {
        format = item['media'][0]['format']?.toString() ?? '';
      }

      return {
        'id': id,
        'title': title,
        'artist': artist,
        'year': year,
        'thumb': null, // 검색 결과에서 이미지 로드 시 연결 풀 점유로 API 타임아웃 발생
        'format': format,
      };
    }).toList();
  }
  //endregion

  // region 앨범 상세 조회
  /// MBID로 앨범 상세 정보 조회
  Future<Album?> fetchAlbumById(String mbid) async {
    // 앨범 상세 API와 커버아트 다운로드를 병렬 시작
    final apiFuture = _fetchReleaseData(mbid);
    final imageFuture = downloadAndSaveImage(mbid);

    // API 데이터는 필수 — 완료까지 대기
    final rawData = await apiFuture;

    // 이미지는 API 완료 후 추가 3초만 대기, 초과 시 이미지 없이 진행
    String? localImagePath;
    try {
      localImagePath = await imageFuture.timeout(
        const Duration(seconds: 3),
      );
    } on TimeoutException {
      debugPrint('MusicBrainz 커버아트 다운로드 타임아웃 — 이미지 없이 진행');
    }

    return _createAlbumFromRawData(rawData, localImagePath, mbid);
  }

  /// 릴리스 상세 데이터 조회 (503 재시도 포함)
  Future<Map<String, dynamic>> _fetchReleaseData(String mbid) async {
    late http.Response response;
    for (int attempt = 0; attempt < 2; attempt++) {
      response = await _get(
        '/release/$mbid',
        queryParams: {
          'inc': 'recordings+artists+labels+media',
        },
      );

      if (response.statusCode == 503) {
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        throw Exception('MusicBrainz 서버가 일시적으로 사용 불가합니다. 잠시 후 다시 시도해주세요.');
      }

      break;
    }

    if (response.statusCode != 200) {
      throw Exception('MusicBrainz 앨범 조회 실패 (HTTP ${response.statusCode})');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
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
            tracks.add(
              Track(title: trackTitle, titleKr: '', isHeader: false),
            );
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
      final response = await http.get(
        Uri.parse('$_coverArtBaseUrl/release/$mbid/front-500'),
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode == 200) {
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
  //endregion
}
