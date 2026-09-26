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

typedef VocadbHttpGet =
    Future<http.Response> Function(Uri uri, {Map<String, String>? headers});

/// VocaDB 요청 실패를 UI 계층까지 전달하기 위한 예외
class VocadbServiceException implements Exception {
  const VocadbServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// VocaDB API 서비스
class VocadbService {
  // region 싱글톤 패턴
  static final VocadbService _instance = VocadbService._internal();
  factory VocadbService() => _instance;
  VocadbService._internal() : _httpGet = http.get, _imageHttpGet = http.get;

  @visibleForTesting
  VocadbService.forTesting({VocadbHttpGet? get, VocadbHttpGet? imageGet})
    : _httpGet = get ?? http.get,
      _imageHttpGet = imageGet ?? http.get;

  final VocadbHttpGet _httpGet;
  final VocadbHttpGet _imageHttpGet;
  String? _lastImageDownloadWarning;

  String? get lastImageDownloadWarning => _lastImageDownloadWarning;
  //endregion

  // region 상수
  static const String _baseUrl = 'https://vocadb.net/api';
  static const String _userAgent = 'MuseArchiveApp/1.0';
  static const String _imageDownloadWarningMessage =
      'VocaDB 앨범 정보는 불러왔지만 커버 이미지를 저장하지 못했습니다. 필요하면 이미지를 직접 선택해주세요.';
  //endregion

  // region API 요청 헬퍼
  Future<http.Response> _get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl$endpoint',
    ).replace(queryParameters: queryParams);
    final headers = {'User-Agent': _userAgent};

    try {
      return await _httpGet(uri, headers: headers);
    } catch (e) {
      debugPrint("VocaDB 연동 오류: $e");
      throw const VocadbServiceException(
        'VocaDB 요청 중 오류가 발생했습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요.',
      );
    }
  }

  static String _messageForStatusCode(int statusCode) {
    if (statusCode == 429) {
      return 'VocaDB 요청 한도를 초과했습니다. 잠시 후 다시 시도해주세요.';
    }
    if (statusCode >= 500) {
      return 'VocaDB 서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }
    return 'VocaDB 요청에 실패했습니다. 상태 코드: $statusCode';
  }
  //endregion

  // region 검색
  Future<List<Map<String, dynamic>>> searchAlbums(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _get(
        '/albums',
        queryParams: {
          'query': query,
          'nameMatchMode': 'Auto',
          'fields': 'MainPicture,Artists',
          'maxResults': '20',
        },
      );

      if (response.statusCode != 200) {
        throw VocadbServiceException(
          _messageForStatusCode(response.statusCode),
        );
      }

      final searchData = jsonDecode(response.body);
      if (searchData is! Map<String, dynamic>) {
        throw const FormatException('VocaDB 검색 응답 형식이 올바르지 않습니다.');
      }
      final rawItems = searchData['items'];
      if (rawItems is! List) {
        throw const FormatException('VocaDB 검색 결과 목록이 없습니다.');
      }

      return rawItems.map((item) {
        if (item is Map<String, dynamic>) {
          final id = item['id'];
          final title = item['name'] ?? '';
          final artist = item['artistString'] ?? '';

          String thumb = '';
          if (item['mainPicture'] != null &&
              item['mainPicture']['urlThumb'] != null) {
            thumb = item['mainPicture']['urlThumb'];
          }

          String date = '';
          if (item['releaseDate'] != null) {
            final year = item['releaseDate']['year']?.toString() ?? '';
            final month = item['releaseDate']['month']?.toString() ?? '';
            final day = item['releaseDate']['day']?.toString() ?? '';
            date = [year, month, day].where((e) => e.isNotEmpty).join('.');
          }

          return {
            'id': id,
            'title': title,
            'artist': artist,
            'year': date.isNotEmpty ? date : '',
            'thumb': thumb,
            'format':
                item['discType'] ??
                '', // VocaDB discType (e.g. Album, Single, EP)
          };
        }
        throw const FormatException('VocaDB 검색 항목 형식이 올바르지 않습니다.');
      }).toList();
    } on VocadbServiceException {
      rethrow;
    } catch (e) {
      debugPrint("VocaDB 검색 오류: $e");
      throw const VocadbServiceException(
        'VocaDB 검색 응답을 처리할 수 없습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요.',
      );
    }
  }
  //endregion

  // region 앨범 상세 조회
  Future<Album?> fetchAlbumById(int id) async {
    _lastImageDownloadWarning = null;

    try {
      final response = await _get(
        '/albums/$id',
        queryParams: {
          'fields': 'Tracks,MainPicture,Artists,Tags,Identifiers,Description',
          'lang': 'Default',
        },
      );

      if (response.statusCode == 404) {
        return null;
      }
      if (response.statusCode != 200) {
        throw VocadbServiceException(
          _messageForStatusCode(response.statusCode),
        );
      }

      final rawData = jsonDecode(response.body);
      if (rawData is! Map<String, dynamic>) {
        throw const FormatException('VocaDB 앨범 응답 형식이 올바르지 않습니다.');
      }

      String? localImagePath;
      final mainPicture = rawData['mainPicture'];
      final imageUrl = mainPicture is Map ? mainPicture['urlOriginal'] : null;
      if (imageUrl is String && imageUrl.trim().isNotEmpty) {
        localImagePath = await downloadAndSaveImage(imageUrl, id.toString());
        if (localImagePath == null) {
          _lastImageDownloadWarning = _imageDownloadWarningMessage;
        }
      }

      return _createAlbumFromRawData(rawData, localImagePath, id);
    } on VocadbServiceException {
      rethrow;
    } catch (e) {
      debugPrint("VocaDB ID 검색 오류: $e");
      throw const VocadbServiceException(
        'VocaDB 앨범 응답을 처리할 수 없습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요.',
      );
    }
  }
  //endregion

  // region 데이터 변환
  Album _createAlbumFromRawData(
    Map<String, dynamic> data,
    String? localImagePath,
    int id,
  ) {
    // 아티스트 향상된 파싱 (Producer 또는 Circle만 필터링, 괄호 내용 제외)
    List<String> parsedArtists = [];
    if (data['artists'] != null) {
      for (var artistData in (data['artists'] as List)) {
        final categories = artistData['categories']?.toString() ?? '';
        if (categories.contains('Producer') || categories.contains('Circle')) {
          String name = artistData['name']?.toString() ?? '';
          if (name.isNotEmpty && !name.contains('(') && !name.contains(')')) {
            parsedArtists.add(name.trim());
          }
        }
      }
    }

    // 유효한 아티스트를 찾지 못한 경우 기존 artistString 사용
    if (parsedArtists.isEmpty && data['artistString'] != null) {
      final str = data['artistString'].toString().trim();
      if (str.isNotEmpty) parsedArtists = [str];
    }

    // 카탈로그 번호
    String? catalogNumber = data['catalogNumber']?.toString().trim();
    if (catalogNumber != null && catalogNumber.isEmpty) {
      catalogNumber = null;
    }

    // 트랙 리스트 파싱
    List<Track> tracks = [];
    if (data['tracks'] != null) {
      final trackList = (data['tracks'] as List);

      // discNumber 단위로 정렬
      trackList.sort((a, b) {
        int discA = a['discNumber'] ?? 1;
        int discB = b['discNumber'] ?? 1;
        if (discA != discB) return discA.compareTo(discB);
        int trackA = a['trackNumber'] ?? 0;
        int trackB = b['trackNumber'] ?? 0;
        return trackA.compareTo(trackB);
      });

      bool hasMultipleDiscs = trackList.any((t) => (t['discNumber'] ?? 1) > 1);
      int currentDisc = -1;

      for (var track in trackList) {
        int discNum = track['discNumber'] ?? 1;

        // 디스크 헤더 로직
        if (currentDisc != -1 && discNum != currentDisc) {
          tracks.add(
            Track(title: 'Disc $discNum', isHeader: true, titleKr: ''),
          );
        } else if (currentDisc == -1 && hasMultipleDiscs) {
          // 다중 디스크 앨범의 경우 첫 번째 트랙부터 Disc 1 헤더 추가
          tracks.add(
            Track(title: 'Disc $discNum', isHeader: true, titleKr: ''),
          );
        } else if (currentDisc == -1 && discNum > 1) {
          // 혹시나 단일 디스크지만 2번 디스크부터 시작하는 예외의 경우
          tracks.add(
            Track(title: 'Disc $discNum', isHeader: true, titleKr: ''),
          );
        }
        currentDisc = discNum;

        // 원본 이름 우선 가져오기
        String trackName = track['name'] ?? '';
        if (track['song'] != null && track['song']['defaultName'] != null) {
          // 가능하면 오리지널 버전 이름 사용
          trackName = track['song']['defaultName'];
        }

        tracks.add(Track(title: trackName, titleKr: '', isHeader: false));
      }
    }

    // 발매일
    String releaseDate = '';
    if (data['releaseDate'] != null) {
      final year =
          data['releaseDate']['year']?.toString().padLeft(4, '0') ?? '';
      final month =
          data['releaseDate']['month']?.toString().padLeft(2, '0') ?? '01';
      final day =
          data['releaseDate']['day']?.toString().padLeft(2, '0') ?? '01';
      if (year.isNotEmpty) {
        releaseDate = '$year.$month.$day';
      }
    }

    // 포맷
    List<String> formats = [];
    if (data['discType'] != null && data['discType'] != 'Unknown') {
      formats.add(data['discType']);
    }

    // 설명 및 식별자(Identifiers) - 카탈로그 번호
    String description = data['description'] is String
        ? data['description']
        : '';

    // 레이블 파싱 로직 추가
    List<String> labels = [];
    if (data['artists'] != null) {
      for (var artistData in (data['artists'] as List)) {
        final categories = artistData['categories']?.toString() ?? '';
        if (categories.contains('Label')) {
          String name = artistData['name']?.toString() ?? '';
          if (name.isNotEmpty) {
            labels.add(name.trim());
          }
        }
      }
    }

    if (data['identifiers'] != null) {
      for (var iden in (data['identifiers'] as List)) {
        final desc = iden['value']?.toString() ?? '';
        if (desc.isNotEmpty) {
          labels.add(desc); // 식별자 정보도 레이블에 합침 (기존 동작 유지)
        }
      }
    }

    // 장르/스타일/포맷 (VocaDB 태그 활용)
    List<String> genres = [];
    List<String> styles = [];
    if (data['tags'] != null) {
      for (var tagWrapper in (data['tags'] as List)) {
        final tag = tagWrapper['tag'];
        if (tag != null && tag['name'] != null) {
          final tagName = tag['name'].toString();
          final category = tag['categoryName']?.toString() ?? '';

          if (category == 'Genres') {
            genres.add(tagName);
          } else if (category == 'Media') {
            if (!formats.contains(tagName)) {
              formats.add(tagName);
            }
          } else {
            styles.add(tagName);
          }
        }
      }
    }

    // 링크 URL
    String linkUrl = 'https://vocadb.net/Al/$id';

    return Album(
      title: data['name'] ?? '',
      artists: parsedArtists,
      catalogNumber: catalogNumber,
      description: description,
      labels: labels,
      imagePath: localImagePath,
      formats: formats.isNotEmpty ? formats : ['CD'],
      releaseDate: ReleaseDate.parse(releaseDate),
      genres: genres,
      styles: styles,
      tracks: tracks,
      linkUrl: linkUrl,
      isLimited: false,
    );
  }
  //endregion

  // region 이미지 다운로드
  Future<String?> downloadAndSaveImage(
    String imageUrl,
    String fileNameBase,
  ) async {
    try {
      final response = await _imageHttpGet(
        Uri.parse(imageUrl),
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode == 200) {
        if (!await _isDecodableImage(response.bodyBytes)) {
          debugPrint('VocaDB 이미지 다운로드 실패: 디코딩할 수 없는 이미지 데이터');
          return null;
        }

        final directory = await getTemporaryDirectory();
        final extension = path
            .extension(imageUrl)
            .split('?')
            .first; // 쿼리 파라미터 제거
        final ext = extension.isEmpty ? '.jpg' : extension;
        final localPath = path.join(directory.path, 'vocadb_$fileNameBase$ext');
        final imageFile = File(localPath);
        await imageFile.writeAsBytes(response.bodyBytes);
        return localPath;
      }
      debugPrint('VocaDB 이미지 다운로드 실패: HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint("VocaDB 이미지 다운로드 실패: $e");
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
      debugPrint('VocaDB 이미지 디코딩 실패: $e');
      return false;
    } finally {
      codec?.dispose();
    }
  }

  //endregion
}
