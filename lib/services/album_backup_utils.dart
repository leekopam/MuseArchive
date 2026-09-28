import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

String buildBackupImageFileName(String prefix, String sourcePath) {
  final baseName = path.basename(sourcePath);
  return '${prefix}_$baseName';
}

Map<String, dynamic> parseBackupJsonMap(dynamic value, String type) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  throw Exception('Invalid backup $type data');
}

/// 추출 디렉터리 아래에서 백업 JSON 파일을 찾는다.
/// 구버전·재압축된 zip에서 루트 폴더가 한 단계 중첩된 경우를 흡수한다.
File? findBackupJsonFile(Directory root, String fileName) {
  File? best;
  var bestDepth = 1 << 30;
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || path.basename(entity.path) != fileName) continue;
    final depth = path
        .relative(entity.path, from: root.path)
        .split(path.separator)
        .length;
    if (depth < bestDepth) {
      best = entity;
      bestDepth = depth;
    }
  }
  return best;
}

/// 백업 JSON을 항목 리스트로 디코딩한다.
/// 최상위가 List이거나 {'albums': [...]} 형태의 Map인 경우를 허용한다.
List<dynamic>? decodeBackupList(String jsonText) {
  final raw = jsonDecode(jsonText);
  if (raw is List) return raw;
  if (raw is Map) {
    for (final key in const ['albums', 'artists', 'items', 'data']) {
      final value = raw[key];
      if (value is List) return value;
    }
  }
  return null;
}

/// 리스트 필드가 문자열로 저장된 구버전 백업 항목을 흡수한다.
List<String> coerceToStringList(dynamic value) {
  if (value == null) return [];
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return [];
    return trimmed
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return [value.toString()];
}

bool coerceToBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.trim().toLowerCase() == 'true';
  return false;
}

/// 구버전 백업의 앨범 항목을 현재 스키마로 정규화한다.
Map<String, dynamic> normalizeBackupAlbumMap(Map<String, dynamic> map) {
  final normalized = Map<String, dynamic>.from(map);

  for (final key in const [
    'artists',
    'labels',
    'formats',
    'genres',
    'styles',
  ]) {
    normalized[key] = coerceToStringList(normalized[key]);
  }

  if ((normalized['artists'] as List).isEmpty) {
    final single = map['artist'];
    if (single != null && single.toString().trim().isNotEmpty) {
      normalized['artists'] = [single.toString().trim()];
    }
  }

  normalized['title'] = map['title']?.toString() ?? '';
  normalized['description'] = map['description']?.toString() ?? '';
  normalized['titleKr'] = map['titleKr']?.toString();
  normalized['catalogNumber'] = map['catalogNumber']?.toString();
  normalized['linkUrl'] = map['linkUrl']?.toString();
  normalized['imagePath'] = map['imagePath']?.toString();
  normalized['releaseDate'] = map['releaseDate']?.toString() ?? '';

  for (final key in const ['isLimited', 'isSpecial', 'isWishlist']) {
    normalized[key] = coerceToBool(normalized[key]);
  }

  final tracks = map['tracks'];
  if (tracks is List) {
    normalized['tracks'] = tracks.whereType<Map>().map((t) {
      final trackMap = Map<String, dynamic>.from(t);
      trackMap['id'] = trackMap['id']?.toString();
      trackMap['title'] = trackMap['title']?.toString() ?? '';
      trackMap['titleKr'] = trackMap['titleKr']?.toString();
      trackMap['isHeader'] = coerceToBool(trackMap['isHeader']);
      return trackMap;
    }).toList();
  } else {
    normalized['tracks'] = <Map<String, dynamic>>[];
  }

  return normalized;
}

/// 구버전 백업의 아티스트 항목을 현재 스키마로 정규화한다.
Map<String, dynamic> normalizeBackupArtistMap(Map<String, dynamic> map) {
  final normalized = Map<String, dynamic>.from(map);
  normalized['name'] = map['name']?.toString() ?? '';
  normalized['imagePath'] = map['imagePath']?.toString();
  for (final key in const ['albumIds', 'aliases', 'groups']) {
    normalized[key] = coerceToStringList(normalized[key]);
  }
  return normalized;
}

File? resolveBackupImageFile(
  Directory extractDir,
  String rawPath, {
  required List<String> searchFolders,
}) {
  final normalized = rawPath.trim();
  if (normalized.isEmpty) return null;

  final candidates = <String>{};

  if (!path.isAbsolute(normalized)) {
    final directPath = path.normalize(path.join(extractDir.path, normalized));
    if (path.isWithin(extractDir.path, directPath)) {
      candidates.add(directPath);
    }
  }

  final fileName = path.basename(normalized);
  candidates.add(path.join(extractDir.path, fileName));

  for (final folder in searchFolders) {
    candidates.add(path.join(extractDir.path, folder, fileName));

    if (!path.isAbsolute(normalized)) {
      final folderPath = path.normalize(
        path.join(extractDir.path, folder, normalized),
      );
      if (path.isWithin(extractDir.path, folderPath)) {
        candidates.add(folderPath);
      }
    }
  }

  for (final candidatePath in candidates) {
    final candidateFile = File(candidatePath);
    if (candidateFile.existsSync()) {
      return candidateFile;
    }
  }

  return null;
}
