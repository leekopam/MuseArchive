import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/album.dart';
import '../services/i_album_repository.dart';
import '../widgets/common_widgets.dart';
import 'add_screen.dart';
import 'artist_detail_screen.dart';

// region 상세 화면 메인
class DetailScreen extends StatefulWidget {
  final Album album;

  const DetailScreen({super.key, required this.album});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late IAlbumRepository _repository;
  late Album _currentAlbum;
  bool _albumWasModified = false;

  // region 라이프사이클
  @override
  void initState() {
    super.initState();
    _repository = context.read<IAlbumRepository>();
    _currentAlbum = widget.album;
  }
  // endregion

  // region 메인 UI
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _albumWasModified);
      },
      child: Scaffold(
        body: CustomScrollView(
          slivers: [_buildSliverAppBar(context), _buildContent(context)],
        ),
      ),
    );
  }
  // endregion

  // region 앱바 빌더
  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300.0,
      pinned: true,
      stretch: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      iconTheme: Theme.of(context).iconTheme,
      actions: [
        IconButton(
          icon: Icon(_currentAlbum.isWishlist ? Icons.star : Icons.star_border),
          tooltip: _currentAlbum.isWishlist ? '위시리스트에서 제거' : '위시리스트에 추가',
          onPressed: _toggleWishlistStatus,
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: _editAlbum,
          tooltip: '앨범 수정',
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: _deleteAlbum,
          tooltip: '앨범 삭제',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        title: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentAlbum.titleKr != null && _currentAlbum.titleKr!.isNotEmpty
                  ? _currentAlbum.titleKr!
                  : _currentAlbum.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: '.SF Pro Display',
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_currentAlbum.titleKr != null &&
                _currentAlbum.titleKr!.isNotEmpty)
              Text(
                _currentAlbum.title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: '.SF Pro Text',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'album-cover-${_currentAlbum.id}',
              child:
                  _currentAlbum.imagePath != null &&
                      File(_currentAlbum.imagePath!).existsSync()
                  ? Image.file(
                      File(_currentAlbum.imagePath!),
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Icon(
                        Icons.album,
                        size: 100,
                        color: const Color(0xFFD4AF37), // 메탈릭 골드
                      ),
                    ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // endregion

  // region 컨텐츠 빌더
  Widget _buildContent(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildInfoSection(context),
              if (_currentAlbum.description.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildDescriptionSection(context),
              ],
              if (_currentAlbum.tracks.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildTracklistSection(context),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ArtistDetailScreen(artistName: _currentAlbum.artist),
            ),
          ),
          child: Text(
            _currentAlbum.artist,
            style: textTheme.displaySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_currentAlbum.linkUrl != null && _currentAlbum.linkUrl!.isNotEmpty)
          ElevatedButton.icon(
            onPressed: _launchURL,
            icon: const Icon(Icons.play_circle_fill_outlined),
            label: const Text("음악 듣기"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return _buildSectionContainer(
      context,
      child: Column(
        children: [
          _buildInfoRow('레이블', _currentAlbum.label),
          _buildInfoRow('형식', _currentAlbum.format),
          _buildInfoRow('발매일', _currentAlbum.releaseDate.format()),
          _buildInfoRow('장르', _currentAlbum.genre),
          _buildInfoRow('스타일', _currentAlbum.style, isLast: true),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('앨범 설명', style: textTheme.titleLarge),
        const SizedBox(height: 8),
        _buildSectionContainer(
          context,
          child: Text(_currentAlbum.description, style: textTheme.bodyMedium),
        ),
      ],
    );
  }

  Widget _buildTracklistSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    int trackNumber = 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('트랙 리스트', style: textTheme.titleLarge),
        const SizedBox(height: 8),
        _buildSectionContainer(
          context,
          child: Column(
            children: _currentAlbum.tracks.map((track) {
              if (track.isHeader) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    track.title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
              return ListTile(
                leading: Text(
                  '${trackNumber++}.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                title: Text(track.title),
                subtitle: (track.titleKr != null && track.titleKr!.isNotEmpty)
                    ? Text(track.titleKr!)
                    : null,
                dense: true,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContainer(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isLast = false}) {
    if (value.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }

  // endregion

  // region 기능 메서드
  Future<void> _toggleWishlistStatus() async {
    final newAlbum = _currentAlbum.copyWith(
      isWishlist: !_currentAlbum.isWishlist,
    );
    try {
      await _repository.update(_currentAlbum.id, newAlbum);
      setState(() {
        _currentAlbum = newAlbum;
        _albumWasModified = true;
      });

      if (!mounted) return;
      final message = _currentAlbum.isWishlist
          ? '앨범을 위시리스트로 옮겼습니다.'
          : '앨범을 컬렉션으로 옮겼습니다.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ErrorSnackBar.show(context, '상태 변경에 실패했습니다.');
    }
  }

  Future<void> _editAlbum() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddScreen(albumToEdit: _currentAlbum)),
    );
    // AddScreen은 자동 저장을 사용하고 뒤로 가기 시 특정 결과를 반환하지 않을 수 있으므로 항상 새로 고침.
    if (mounted) {
      _albumWasModified = true;
      final updatedAlbums = await _repository.getAll();
      setState(() {
        _currentAlbum = updatedAlbums.firstWhere(
          (album) => album.id == _currentAlbum.id,
          orElse: () => _currentAlbum,
        );
      });
    }
  }

  Future<void> _deleteAlbum() async {
    if (!mounted) return;
    final confirm = await ConfirmDialog.show(
      context,
      title: '앨범 삭제',
      content: '정말로 이 앨범을 삭제하시겠습니까?',
      confirmText: '삭제',
    );
    if (confirm == true && mounted) {
      await _repository.delete(_currentAlbum.id);
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _launchURL() async {
    if (_currentAlbum.linkUrl != null && _currentAlbum.linkUrl!.isNotEmpty) {
      final Uri url = Uri.parse(_currentAlbum.linkUrl!);
      if (!mounted) return;
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) ErrorSnackBar.show(context, '링크를 열 수 없습니다.');
      }
    }
  }

  // endregion
}

// endregion
