import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final OcrService _instance = OcrService._internal();
  factory OcrService() => _instance;
  OcrService._internal();

  Future<String> extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();
      
      return recognizedText.text;
    } catch (e) {
      debugPrint('OCR 오류: $e');
      return '';
    }
  }

  String parseAlbumInfo(String text) {
    final lines = text.split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    
    if (lines.isEmpty) return '';
    
    return lines.take(3).join(' ').trim();
  }
}
