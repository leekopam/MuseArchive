import 'dart:io';
import 'package:flutter/material.dart';
import '../models/album.dart';
import '../services/album_repository.dart';
import 'detail_screen.dart';

class ArtistDetailScreen extends StatefulWidget {
  final String artistName;
  final String? sourceAlbumId;

  const ArtistDetailScreen({
    super.key,
    required this.artistName,
    this.sourceAlbumId,
  });

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  late List<Album> _artistAlbums;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtistAlbums();
  }

  Future<void> _loadArtistAlbums() async {
    setState(() => _isLoading = true);
    final repository = AlbumRepository();
    _artistAlbums = repository.getAlbumsByArtist(widget.artistName);
    setState(() => _isLoading = false);
  }

  BorderSide _getAlbumBorder(Album album, bool isSourceAlbum) {
    if (album.isLimited) {
      return BorderSide(color: Colors.amber.shade700, width: 2.5);
    }
    if (album.isSpecial) {
      return BorderSide(color: Colors.red.shade700, width: 2.5);
    }
    if (isSourceAlbum) {
      return const BorderSide(color: Colors.indigo, width: 2);
    }
    return BorderSide.none;
  }

  Widget _buildFormatBadge(Album album) {
    const formatColors = {
      'LP': Color(0xFF333333),
      'CD': Color(0xFF4A90E2),
      'DVD': Color(0xFF7B1FA2),
      'Blu-ray': Color(0xFF007BFF),
    };
    final formatPriority = ['LP', 'CD', 'DVD', 'Blu-ray'];

    String? badgeLabel;
    Color? badgeColor;

    for (final format in formatPriority) {
      if (album.formats.any((f) => f.toLowerCase().contains(format.toLowerCase()))) {
        badgeLabel = format;
        badgeColor = formatColors[format];
        break;
      }
    }

    if (badgeLabel == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 4,
      left: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 3)],
        ),
        child: Text(
          badgeLabel,
          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey[50];
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          widget.artistName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _artistAlbums.isEmpty
              ? _buildEmptyState(isDark)
              : _buildAlbumList(isDark, cardColor, textColor),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.album,
            size: 80,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '이 아티스트의 앨범이 없습니다.',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumList(bool isDark, Color cardColor, Color textColor) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _artistAlbums.length,
      itemBuilder: (context, index) {
        final album = _artistAlbums[index];
        final isSourceAlbum = album.id == widget.sourceAlbumId;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isSourceAlbum ? 4 : 1,
          color: isSourceAlbum
              ? (isDark ? Colors.indigo[900] : Colors.indigo[50])
              : cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: _getAlbumBorder(album, isSourceAlbum),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isSourceAlbum
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailScreen(
                          album: album,
                        ),
                      ),
                    );
                  },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: album.imagePath != null &&
                                File(album.imagePath!).existsSync()
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(album.imagePath!),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.album,
                                size: 40,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                      ),
                      _buildFormatBadge(album),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (album.releaseDate.isValid)
                          Text(
                            album.releaseDate.format(),
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        if (album.format.isNotEmpty)
                          Text(
                            album.format,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (isSourceAlbum)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.indigo,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '현재 보고 있는 앨범',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!isSourceAlbum)
                    Icon(
                      Icons.chevron_right,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
