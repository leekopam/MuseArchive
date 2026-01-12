import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../models/album.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/common_widgets.dart';
import 'add_screen.dart';
import 'detail_screen.dart';
import 'settings_screen.dart';
import 'all_songs_screen.dart';
import 'artist_detail_screen.dart';
import '../models/artist.dart';
import '../services/i_album_repository.dart';

// region 홈 화면 메인
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PageController _pageController;

  // region 라이프사이클
  @override
  void initState() {
    super.initState();
    final viewModel = context.read<HomeViewModel>();
    // viewModel의 현재 인덱스로 페이지 컨트롤러 초기화
    int initialPage = viewModel.currentView == AlbumView.collection ? 0 : 1;
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  // endregion

  // region 이벤트 핸들러
  void _onPageChanged(int index) {
    final viewModel = context.read<HomeViewModel>();
    if (index == 0) {
      if (viewModel.currentView != AlbumView.collection) {
        viewModel.setView(AlbumView.collection);
      }
    } else {
      if (viewModel.currentView != AlbumView.wishlist) {
        viewModel.setView(AlbumView.wishlist);
      }
    }
  }

  void _onSegmentChanged(AlbumView? value) {
    if (value != null) {
      final viewModel = context.read<HomeViewModel>();
      viewModel.setView(value);
      _pageController.animateToPage(
        value == AlbumView.collection ? 0 : 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();
    final theme = Theme.of(context);

    // 외부 변경이 발생하면 PageController 동기화 (하지만 엄밀히 말하면 VM이 이제 onSegmentChanged를 통해 이를 구동함)
    // 하지만 세그먼트가 아닌 VM 변경 뷰라면(이 설정에서는 거의 없지만 가능함), 애니메이션을 적용하고 싶을 수 있습니다.
    // 현재로서는 루프를 피하기 위해 _onSegmentChanged가 애니메이션을 주도하도록 하는 것이 더 안전합니다.

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _HomeAppBar(viewModel: viewModel),
      body: LoadingOverlay(
        isLoading: viewModel.isLoading,
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: CupertinoSlidingSegmentedControl<AlbumView>(
                groupValue: viewModel.currentView,
                onValueChanged: _onSegmentChanged,
                children: const {
                  AlbumView.collection: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('컬렉션'),
                  ),
                  AlbumView.wishlist: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('위시리스트'),
                  ),
                },
                backgroundColor: theme.colorScheme.surface.withValues(
                  alpha: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  _buildContent(context, viewModel, AlbumView.collection),
                  _buildContent(context, viewModel, AlbumView.wishlist),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  // endregion

  // endregion

  // region UI 빌더
  Widget _buildContent(
    BuildContext context,
    HomeViewModel viewModel,
    AlbumView view,
  ) {
    switch (viewModel.viewMode) {
      case ViewMode.artists:
        return _buildArtistList(context, viewModel, view);
      case ViewMode.grid3:
        return _buildAlbumGrid(context, viewModel, view, 3);
      case ViewMode.grid2:
        return _buildAlbumGrid(context, viewModel, view, 2);
    }
  }

  Widget _buildArtistList(
    BuildContext context,
    HomeViewModel viewModel,
    AlbumView view,
  ) {
    // 현재 뷰에 맞는 아티스트 리스트 가져오기 (HomeViewModel에서 로직 처리됨)
    // 하지만 HomeViewModel.getArtistsForCurrentView()는 현재 *활성화된* 뷰 기준입니다.
    // PageView이므로 각 페이지별로 데이터를 따로 처리해야 합니다.
    // HomeViewModel에 'view' 파라미터를 받는 메서드가 있으면 좋겠지만,
    // 일단 현재 구조상 PageView 전환 시 setView가 호출되므로 currentView를 의존해도 됩니다.
    // 다만, 드래그 중에는 두 페이지가 동시에 보일 수 있어 비효율적일 수 있습니다.
    // 정확성을 위해 viewModel.getAlbumsForView(view)를 사용하여 직접 추출합니다.

    final albums = viewModel.getAlbumsForView(view);
    final uniqueNames = albums.map((a) => a.artist).toSet().toList();
    uniqueNames.sort(
      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
    ); // 이름순 정렬

    if (uniqueNames.isEmpty && !viewModel.isLoading) {
      return EmptyState(
        icon: Icons.person_off_outlined,
        message: '아티스트가 없습니다.',
        onAction: () => _navigateToAddScreen(context, view),
        actionLabel: '앨범 추가하기',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: uniqueNames.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        indent: 60,
        color: Colors.grey.withValues(alpha: 0.2),
      ),
      itemBuilder: (context, index) {
        final artistName = uniqueNames[index];
        // 앨범 수 계산
        final albumCount = albums.where((a) => a.artist == artistName).length;

        // 아티스트 정보를 Repository에서 조회 (이미지 확인용)
        final repository = context.read<IAlbumRepository>();
        final artist = repository.getArtistByName(artistName);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child:
                  artist?.imagePath != null &&
                      File(artist!.imagePath!).existsSync()
                  ? Image.file(File(artist.imagePath!), fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
            ),
          ),
          title: Text(
            artistName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            '$albumCount Albums',
            style: TextStyle(
              color: Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: Colors.grey,
            size: 20,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ArtistDetailScreen(artistName: artistName),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAlbumGrid(
    BuildContext context,
    HomeViewModel viewModel,
    AlbumView view,
    int crossAxisCount,
  ) {
    final albums = viewModel.getAlbumsForView(view);

    if (albums.isEmpty && !viewModel.isLoading) {
      return EmptyState(
        icon: view == AlbumView.collection
            ? Icons.music_note_outlined
            : Icons.favorite_border,
        message: view == AlbumView.collection ? '앨범이 없습니다.' : '위시리스트가 비었습니다.',
        onAction: () => _navigateToAddScreen(context, view),
        actionLabel: '앨범 추가하기',
      );
    }

    if (viewModel.isReorderMode) {
      // ReorderableGridView에는 빌더 또는 개수가 필요합니다.
      // 효율성을 위해 빌더를 사용합니다.
      // 참고: reorderable_grid_view 패키지의 API:
      // ReorderableGridView.builder(itemCount: ..., onReorder: ..., itemBuilder: ...)
      return ReorderableGridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: crossAxisCount == 3 ? 12 : 16,
          mainAxisSpacing: crossAxisCount == 3 ? 12 : 16,
          childAspectRatio: 0.75,
        ),
        itemCount: albums.length,
        onReorder: (oldIndex, newIndex) {
          viewModel.reorderInView(oldIndex, newIndex, view);
        },
        itemBuilder: (context, index) {
          final album = albums[index];
          // 키는 재정렬에 중요합니다.
          return KeyedSubtree(
            key: ValueKey(album.id),
            child: _AlbumCard(album: album, isCompact: crossAxisCount == 3),
          );
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisCount == 3 ? 12 : 16,
        mainAxisSpacing: crossAxisCount == 3 ? 12 : 16,
        childAspectRatio: 0.75,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return _AlbumCard(album: album, isCompact: crossAxisCount == 3);
      },
    );
  }
}
// endregion

// region 앱바 위젯
class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HomeAppBar({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AppBar(
          title: viewModel.isSearching
              ? CupertinoSearchTextField(
                  controller: viewModel.searchController,
                  autofocus: true,
                  onChanged: viewModel.setSearchQuery,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                )
              : const Text('MuseArchive'),
          backgroundColor: theme.scaffoldBackgroundColor.withValues(
            alpha: 0.85,
          ),
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(viewModel.isSearching ? Icons.close : Icons.search),
              onPressed: viewModel.toggleSearch,
              tooltip: '검색',
            ),
            IconButton(
              icon: Icon(
                viewModel.viewMode == ViewMode.grid2
                    ? Icons.grid_3x3_rounded
                    : viewModel.viewMode == ViewMode.grid3
                    ? Icons.people_alt_outlined
                    : Icons.grid_view_rounded,
              ),
              onPressed: viewModel.toggleViewMode,
              tooltip: viewModel.viewMode == ViewMode.grid2
                  ? '3열 그리드로 보기'
                  : viewModel.viewMode == ViewMode.grid3
                  ? '아티스트 목록으로 보기'
                  : '2열 그리드로 보기',
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () =>
                  _navigateToAddScreen(context, viewModel.currentView),
              tooltip: '앨범 추가',
            ),
            _buildMoreMenu(context, viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreMenu(BuildContext context, HomeViewModel viewModel) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'sort':
            _showSortOptions(context, viewModel);
            break;
          case 'reorder':
            viewModel.toggleReorderMode();
            break;
          case 'all_songs':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllSongsScreen()),
            );
            break;
          case 'settings':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'sort',
          child: ListTile(leading: Icon(Icons.sort), title: Text('정렬')),
        ),
        PopupMenuItem(
          value: 'reorder',
          child: ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text(viewModel.isReorderMode ? '정렬 완료' : '순서 변경'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'all_songs',
          child: ListTile(
            leading: Icon(Icons.queue_music),
            title: Text('모든 곡 목록'),
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('설정'),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
// endregion

// region 앨범 카드 위젯
class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, this.isCompact = false});

  final Album album;
  final bool isCompact;

  Color _getBorderColor() {
    if (album.isLimited) {
      return Colors.amber.shade700;
    }
    if (album.isSpecial) {
      return Colors.red.shade700;
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<HomeViewModel>();
    // 재정렬 모드인 경우 ReorderableGridView가 사용할 수 있도록 사용자 지정 onLongPress를 비활성화합니다.
    final canShowMenu = !viewModel.isReorderMode;

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailScreen(album: album)),
        );
        if (result == true) {
          viewModel.loadAlbums();
        }
      },
      onLongPress: canShowMenu
          ? () => _showMoveAlbumSheet(context, album, viewModel)
          : null,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)), // 기본 카드 반경
          side: BorderSide(color: _getBorderColor(), width: 2.5),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildAlbumImage(),
            _buildGradientOverlay(),
            _buildAlbumInfo(context),
            _buildFormatBadge(isCompact),
          ],
        ),
      ),
    );
  }

  void _showMoveAlbumSheet(
    BuildContext context,
    Album album,
    HomeViewModel viewModel,
  ) {
    final isWishlist = album.isWishlist;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (builderContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor.withValues(alpha: 0.85),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              child: Wrap(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      album.title,
                      style: theme.textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      isWishlist
                          ? Icons.collections_bookmark_outlined
                          : Icons.favorite_border,
                    ),
                    title: Text(isWishlist ? '컬렉션으로 이동' : '위시리스트로 이동'),
                    onTap: () async {
                      Navigator.pop(builderContext);
                      await viewModel.toggleWishlistStatus(album.id);

                      if (context.mounted) {
                        final message = isWishlist
                            ? '앨범을 컬렉션으로 옮겼습니다.'
                            : '앨범을 위시리스트로 옮겼습니다.';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24.0),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    title: const Text(
                      '앨범 삭제',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(builderContext);
                      showDialog(
                        context: context,
                        builder: (dialogContext) {
                          return AlertDialog(
                            title: const Text('앨범 삭제'),
                            content: const Text('정말로 이 앨범을 삭제하시겠습니까?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(dialogContext);
                                  await viewModel.deleteAlbum(album.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('앨범이 삭제되었습니다.'),
                                      ),
                                    );
                                  }
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('삭제'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cancel_outlined),
                    title: const Text('취소'),
                    onTap: () => Navigator.pop(builderContext),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlbumImage() {
    return Hero(
      tag: 'album-cover-${album.id}',
      child: (album.imagePath != null && File(album.imagePath!).existsSync())
          ? Image.file(File(album.imagePath!), fit: BoxFit.cover)
          : Container(
              color: const Color(0xFF1E1E2C),
              child: const Center(
                child: Icon(
                  Icons.album,
                  size: 50,
                  color: Color(0xFFD4AF37),
                ), // 메탈릭 골드
              ),
            ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
          stops: [0.6, 1.0],
        ),
      ),
    );
  }

  Widget _buildAlbumInfo(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Positioned(
      bottom: isCompact ? 4 : 8,
      left: isCompact ? 4 : 8,
      right: isCompact ? 4 : 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            album.title,
            style: (isCompact ? textTheme.labelSmall : textTheme.titleMedium)
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            maxLines: isCompact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            album.artist,
            style: (isCompact ? textTheme.labelSmall : textTheme.bodyMedium)
                ?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: isCompact ? 9 : null,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFormatBadge(bool isCompact) {
    const formatColors = {
      'LP': Color(0xFFD4AF37), // 메탈릭 골드
      'CD': Color(0xFF607D8B), // 블루 그레이 (프리미엄 실버 룩)
      'DVD': Color(0xFF8E24AA), // 퍼플 (프리미엄)
      'Blu-ray': Color(0xFF2962FF), // 비비드 블루
    };
    final formatPriority = ['LP', 'CD', 'DVD', 'Blu-ray'];

    List<Widget> badges = [];

    for (final format in formatPriority) {
      if (album.formats.any(
        (f) => f.toLowerCase().contains(format.toLowerCase()),
      )) {
        badges.add(
          _Badge(
            label: format,
            color: formatColors[format]!,
            isCompact: isCompact,
          ),
        );
      }
    }

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: isCompact ? 4 : 8,
      left: isCompact ? 4 : 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: badges,
      ),
    );
  }
}
// endregion

// region 배지 위젯
class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    this.isCompact = false,
  });

  final String label;
  final Color color;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 4 : 6,
        vertical: isCompact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: isCompact ? 2 : 3,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: isCompact ? 8 : 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
// endregion

// region 헬퍼 메서드
// --- 원래 파일에 있던 도우미 메서드, 새 디자인에 맞춰 조정됨 ---

void _navigateToAddScreen(BuildContext context, AlbumView currentView) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) =>
          AddScreen(isWishlist: currentView == AlbumView.wishlist),
    ),
  );
}

void _showSortOptions(BuildContext context, HomeViewModel viewModel) async {
  final selected = await showModalBottomSheet<SortOption>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '정렬 순서',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ...SortOption.values.map((option) {
              return ListTile(
                leading: Icon(
                  _getSortOptionIcon(option),
                  color: viewModel.sortOption == option
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(
                  _getSortOptionText(option),
                  style: TextStyle(
                    fontWeight: viewModel.sortOption == option
                        ? FontWeight.bold
                        : null,
                    color: viewModel.sortOption == option
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                trailing: viewModel.sortOption == option
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () => Navigator.pop(context, option),
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );

  if (selected != null) {
    viewModel.setSortOption(selected);
  }
}

String _getSortOptionText(SortOption option) {
  switch (option) {
    case SortOption.custom:
      return '사용자 지정';
    case SortOption.artist:
      return '아티스트';
    case SortOption.title:
      return '앨범명';
    case SortOption.dateDescending:
      return '발매일 (최신순)';
    case SortOption.dateAscending:
      return '발매일 (오래된순)';
  }
}

IconData _getSortOptionIcon(SortOption option) {
  switch (option) {
    case SortOption.custom:
      return Icons.sort_by_alpha;
    case SortOption.artist:
      return Icons.person_outline;
    case SortOption.title:
      return Icons.album_outlined;
    case SortOption.dateDescending:
      return Icons.arrow_downward;
    case SortOption.dateAscending:
      return Icons.arrow_upward;
  }
}
