import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AlbumCoverPicker extends StatelessWidget {
  final String? imagePath;
  final ValueChanged<String?> onImageSelected;
  final Color primaryColor;
  final bool isDark;

  const AlbumCoverPicker({
    super.key,
    required this.imagePath,
    required this.onImageSelected,
    required this.primaryColor,
    required this.isDark,
  });

  Future<void> _pickImage(BuildContext context) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이미지 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        onImageSelected(pickedFile.path);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickImage(context),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              image: imagePath != null
                  ? DecorationImage(
                      image: FileImage(File(imagePath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imagePath == null
                ? Icon(
                    Icons.album,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                    size: 50,
                  )
                : null,
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.grey[900]! : Colors.white,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.camera_alt,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
