import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  Future<String?> saveImage(String? imagePath, String uniqueId) async {
    if (imagePath == null || imagePath.isEmpty) return null;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/album_images');
      
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final imageFile = File(imagePath);
      if (!await imageFile.exists()) return null;

      final extension = path.extension(imagePath);
      final newPath = '${imagesDir.path}/${uniqueId}_${DateTime.now().millisecondsSinceEpoch}$extension';
      
      await imageFile.copy(newPath);
      return newPath;
    } catch (e) {
      debugPrint('이미지 저장 실패: $e');
      return null;
    }
  }

  Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;

    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('이미지 삭제 실패: $e');
    }
  }

  Future<List<String>> getAllImagePaths() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/album_images');
      
      if (!await imagesDir.exists()) return [];

      final files = await imagesDir.list().toList();
      return files
          .whereType<File>()
          .map((file) => file.path)
          .toList();
    } catch (e) {
      debugPrint('이미지 목록 조회 실패: $e');
      return [];
    }
  }

  Future<void> cleanupUnusedImages(List<String> usedImagePaths) async {
    try {
      final allImages = await getAllImagePaths();
      
      for (final imagePath in allImages) {
        if (!usedImagePaths.contains(imagePath)) {
          await deleteImage(imagePath);
        }
      }
    } catch (e) {
      debugPrint('이미지 정리 실패: $e');
    }
  }
}
