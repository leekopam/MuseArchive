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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<HomeViewModel>();
    // Initialize page controller with the current index from viewModel
    int initialPage = viewModel.currentView == AlbumView.collection ? 0 : 1;
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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

    // Sync PageController if external change happens (though strictly VM drives this now via onSegmentChanged)
    // But if VM changes view NOT via segment (unlikely in this setup but possible), we might want to animate.
    // For now, relying on _onSegmentChanged driving the animation is safer to avoid loops.

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
                  _buildAlbumGrid(context, viewModel, AlbumView.collection),
                  _buildAlbumGrid(context, viewModel, AlbumView.wishlist),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumGrid(
    BuildContext context,
    HomeViewModel viewModel,
    AlbumView view,
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
      // ReorderableGridView requires a builder or count.
      // We use builder for efficiency.
      // Note: reorderable_grid_view package's API:
      // ReorderableGridView.builder(itemCount: ..., onReorder: ..., itemBuilder: ...)
      return ReorderableGridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: albums.length,
        onReorder: (oldIndex, newIndex) {
          viewModel.reorderInView(oldIndex, newIndex, view);
        },
        itemBuilder: (context, index) {
          final album = albums[index];
          // Key is crucial for reordering
          return KeyedSubtree(
            key: ValueKey(album.id),
            child: _AlbumCard(album: album),
          );
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return _AlbumCard(album: album);
      },
    );
  }
}

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

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album});

  final Album album;

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
    // If in Reorder mode, we disable our custom onLongPress so ReorderableGridView can claim it.
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
          borderRadius: const BorderRadius.all(
            Radius.circular(12),
          ), // Default card radius
          side: BorderSide(color: _getBorderColor(), width: 2.5),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildAlbumImage(),
            _buildGradientOverlay(),
            _buildAlbumInfo(context),
            _buildFormatBadge(),
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
                ), // Metallic Gold
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
      bottom: 8,
      left: 8,
      right: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            album.title,
            style: textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            album.artist,
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFormatBadge() {
    const formatColors = {
      'LP': Color(0xFFD4AF37), // Metallic Gold
      'CD': Color(0xFF607D8B), // Blue Grey (Premium Silver look)
      'DVD': Color(0xFF8E24AA), // Purple (Premium)
      'Blu-ray': Color(0xFF2962FF), // Vivid Blue
    };
    final formatPriority = ['LP', 'CD', 'DVD', 'Blu-ray'];

    List<Widget> badges = [];

    for (final format in formatPriority) {
      if (album.formats.any(
        (f) => f.toLowerCase().contains(format.toLowerCase()),
      )) {
        badges.add(_Badge(label: format, color: formatColors[format]!));
      }
    }

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 8,
      left: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: badges,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 3),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// --- Helper methods that were in the original file, adapted for the new design ---

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
