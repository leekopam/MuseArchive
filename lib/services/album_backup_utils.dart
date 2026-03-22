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
