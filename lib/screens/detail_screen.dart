import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/album.dart';
import '../services/i_album_repository.dart';
import '../services/haptic_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/animation_widgets.dart';
import 'add_screen.dart';
import 'artist_detail_screen.dart';

class DetailAppBarStyle {
  static const Color _expandedActionBackground = Color(0x52000000);
  static const Color _collapsedLightActionBackground = Color(0x0D000000);
  static const Color _collapsedDarkActionBackground = Color(0x14FFFFFF);

  const DetailAppBarStyle({
    required this.foregroundColor,
    required this.actionBackgroundColor,
    required this.systemOverlayStyle,
  });

  final Color foregroundColor;
  final Color actionBackgroundColor;
  final SystemUiOverlayStyle systemOverlayStyle;

  static DetailAppBarStyle fromTheme(
    ThemeData theme, {
    required bool isCollapsed,
  }) {
    if (!isCollapsed) {
      return const DetailAppBarStyle(
        foregroundColor: Colors.white,
        actionBackgroundColor: _expandedActionBackground,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      );
    }

    final isDark = theme.brightness == Brightness.dark;
    return DetailAppBarStyle(
      foregroundColor: theme.colorScheme.onSurface,
      actionBackgroundColor: isDark
          ? _collapsedDarkActionBackground
          : _collapsedLightActionBackground,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );
  }
}

// region 상세 화면 메인
class DetailScreen extends StatefulWidget {
  final Album album;

  const DetailScreen({super.key, required this.album});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  static const double _expandedAppBarHeight = 320.0;

  late IAlbumRepository _repository;
  late final ScrollController _scrollController;
  late Album _currentAlbum;
  bool _albumWasModified = false;
  bool _isAppBarCollapsed = false;

  // region 라이프사이클
  @override
  void initState() {
    super.initState();
    _repository = context.read<IAlbumRepository>();
    _scrollController = ScrollController()..addListener(_handleScroll);
    _currentAlbum = widget.album;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _handleScroll();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }
  // endregion

  // region 메인 UI
  @override
  Widget build(BuildContext context) {
    final appBarStyle = DetailAppBarStyle.fromTheme(
      Theme.of(context),
      isCollapsed: _isAppBarCollapsed,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _albumWasModified);
      },
      child: Scaffold(
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildSliverAppBar(context, appBarStyle),
            _buildContent(context),
          ],
        ),
      ),
    );
  }
  // endregion

  // region 앱바 빌더
  SliverAppBar _buildSliverAppBar(
    BuildContext context,
    DetailAppBarStyle appBarStyle,
  ) {
    final theme = Theme.of(context);

    return SliverAppBar(
      expandedHeight: _expandedAppBarHeight,
      pinned: true,
      stretch: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: _isAppBarCollapsed
          ? theme.scaffoldBackgroundColor
          : Colors.transparent,
      systemOverlayStyle: appBarStyle.systemOverlayStyle,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12),
        child: _buildTopBarIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context, _albumWasModified),
          appBarStyle: appBarStyle,
        ),
      ),
      titleSpacing: 0,
      title: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _isAppBarCollapsed ? 1 : 0,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: Text(
            _primaryTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: appBarStyle.foregroundColor,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      actions: [
        _buildTopBarIconButton(
          icon: _currentAlbum.isWishlist ? Icons.star : Icons.star_border,
          tooltip: _currentAlbum.isWishlist ? '위시리스트에서 제거' : '위시리스트에 추가',
          onPressed: () {
            HapticService.toggle();
            _toggleWishlistStatus();
          },
          appBarStyle: appBarStyle,
        ),
        _buildTopBarIconButton(
          icon: Icons.edit_outlined,
          onPressed: () {
            HapticService.lightTap();
            _editAlbum();
          },
          appBarStyle: appBarStyle,
          tooltip: '앨범 수정',
        ),
        _buildTopBarIconButton(
          icon: Icons.delete_outline,
          onPressed: () {
            HapticService.warning();
            _deleteAlbum();
          },
          appBarStyle: appBarStyle,
          tooltip: '앨범 삭제',
        ),
        const SizedBox(width: 12),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
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
                  colors: const [
                    Color(0xA6000000),
                    Color(0x33000000),
                    Color(0x14000000),
                    Color(0xD9000000),
                  ],
                  stops: const [0.0, 0.18, 0.5, 1.0],
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _isAppBarCollapsed ? 0 : 1,
                      child: _buildExpandedTitle(theme),
                    ),
                  ),
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
              FadeSlideIn(child: _buildHeader(context)),
              const SizedBox(height: 24),
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: _buildInfoSection(context),
              ),
              if (_currentAlbum.description.isNotEmpty) ...[
                const SizedBox(height: 24),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: _buildDescriptionSection(context),
                ),
              ],
              if (_currentAlbum.tracks.isNotEmpty) ...[
                const SizedBox(height: 24),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 300),
                  child: _buildTracklistSection(context),
                ),
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
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: _currentAlbum.artists.asMap().entries.map((entry) {
            final isLast = entry.key == _currentAlbum.artists.length - 1;
            return InkWell(
              onTap: () {
                HapticService.lightTap();
                Navigator.push(
                  context,
                  AnimatedPageRoute(
                    page: ArtistDetailScreen(artistName: entry.value),
                  ),
                );
              },
              child: Text(
                entry.value + (isLast ? '' : ', '),
                style: textTheme.displaySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (_currentAlbum.linkUrl != null && _currentAlbum.linkUrl!.isNotEmpty)
          ElevatedButton.icon(
            onPressed: () {
              HapticService.lightTap();
              _launchURL();
            },
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
          if (_currentAlbum.catalogNumber != null &&
              _currentAlbum.catalogNumber!.isNotEmpty)
            _buildInfoRow('카탈로그', _currentAlbum.catalogNumber!),
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

  String get _primaryTitle {
    if (_currentAlbum.titleKr != null && _currentAlbum.titleKr!.isNotEmpty) {
      return _currentAlbum.titleKr!;
    }
    return _currentAlbum.title;
  }

  String? get _secondaryTitle {
    if (_currentAlbum.titleKr != null && _currentAlbum.titleKr!.isNotEmpty) {
      return _currentAlbum.title;
    }
    return null;
  }

  void _handleScroll() {
    if (!mounted || !_scrollController.hasClients) return;

    final collapseThreshold =
        _expandedAppBarHeight -
        kToolbarHeight -
        MediaQuery.paddingOf(context).top;
    final shouldCollapse = _scrollController.offset > collapseThreshold;

    if (shouldCollapse != _isAppBarCollapsed) {
      setState(() {
        _isAppBarCollapsed = shouldCollapse;
      });
    }
  }

  Widget _buildTopBarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required DetailAppBarStyle appBarStyle,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: appBarStyle.foregroundColor,
        backgroundColor: appBarStyle.actionBackgroundColor,
      ),
      icon: Icon(icon),
    );
  }

  Widget _buildExpandedTitle(ThemeData theme) {
    final textTheme = theme.textTheme;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x33111111),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _primaryTitle,
            style: textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              shadows: const [
                Shadow(
                  color: Color(0xAA000000),
                  blurRadius: 16,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (_secondaryTitle != null) ...[
            const SizedBox(height: 4),
            Text(
              _secondaryTitle!,
              style: textTheme.bodyMedium?.copyWith(
                color: const Color(0xD9FFFFFF),
                shadows: const [
                  Shadow(
                    color: Color(0xAA000000),
                    blurRadius: 12,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
      AnimatedPageRoute(page: AddScreen(albumToEdit: _currentAlbum)),
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
      try {
        final Uri url = Uri.parse(_currentAlbum.linkUrl!);
        if (!mounted) return;
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          if (mounted) ErrorSnackBar.show(context, '링크를 열 수 없습니다.');
        }
      } catch (e) {
        if (mounted) ErrorSnackBar.show(context, '링크를 열 수 없습니다.');
      }
    }
  }

  // endregion
}

// endregion
