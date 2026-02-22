import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/album.dart';
import '../models/track.dart';
import '../models/value_objects/release_date.dart';

/// VocaDB API 서비스
class VocadbService {
  // region 싱글톤 패턴
  static final VocadbService _instance = VocadbService._internal();
  factory VocadbService() => _instance;
  VocadbService._internal();
  //endregion

  // region 상수
  static const String _baseUrl = 'https://vocadb.net/api';
  static const String _userAgent = 'MuseArchiveApp/1.0';
  //endregion

  // region API 요청 헬퍼
  Future<http.Response?> _get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl$endpoint',
    ).replace(queryParameters: queryParams);
    final headers = {'User-Agent': _userAgent};

    try {
      return await http.get(uri, headers: headers);
    } catch (e) {
      debugPrint("VocaDB 연동 오류: $e");
      return null;
    }
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

      if (response != null && response.statusCode == 200) {
        final searchData = jsonDecode(response.body);
        final items = searchData['items'] as List;

        return items.map((item) {
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
        }).toList();
      }
    } catch (e) {
      debugPrint("VocaDB 검색 오류: $e");
    }

    return [];
  }
  //endregion

  // region 앨범 상세 조회
  Future<Album?> fetchAlbumById(int id) async {
    try {
      final response = await _get(
        '/albums/$id',
        queryParams: {
          'fields': 'Tracks,MainPicture,Artists,Tags,Identifiers,Description',
          'lang': 'Default',
        },
      );

      if (response != null && response.statusCode == 200) {
        final rawData = jsonDecode(response.body) as Map<String, dynamic>;

        String? localImagePath;
        if (rawData['mainPicture'] != null &&
            rawData['mainPicture']['urlOriginal'] != null) {
          final imageUrl = rawData['mainPicture']['urlOriginal'];
          localImagePath = await downloadAndSaveImage(imageUrl, id.toString());
        }

        return _createAlbumFromRawData(rawData, localImagePath, id);
      }
    } catch (e) {
      debugPrint("VocaDB ID 검색 오류: $e");
    }

    return null;
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
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode == 200) {
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
    } catch (e) {
      debugPrint("VocaDB 이미지 다운로드 실패: $e");
    }

    return null;
  }

  //endregion
}
