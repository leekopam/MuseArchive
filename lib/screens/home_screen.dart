import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/album.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/common_widgets.dart';
import 'add_screen.dart';
import 'detail_screen.dart';
import 'settings_screen.dart';
import 'all_songs_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _HomeAppBar(viewModel: viewModel),
      body: LoadingOverlay(
        isLoading: viewModel.isLoading,
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: CupertinoSlidingSegmentedControl<AlbumView>(
                groupValue: viewModel.currentView,
                onValueChanged: (value) {
                  if (value != null) {
                    viewModel.setView(value);
                  }
                },
                children: const {
                  AlbumView.collection: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('컬렉션')),
                  AlbumView.wishlist: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('위시리스트')),
                },
                backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildAlbumGrid(context, viewModel)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumGrid(BuildContext context, HomeViewModel viewModel) {
    final albums = viewModel.filteredAlbums;
    if (albums.isEmpty && !viewModel.isLoading) {
      return EmptyState(
        icon: viewModel.currentView == AlbumView.collection ? Icons.music_note_outlined : Icons.favorite_border,
        message: viewModel.currentView == AlbumView.collection ? '앨범이 없습니다.' : '위시리스트가 비었습니다.',
        onAction: () => _navigateToAddScreen(context, viewModel.currentView),
        actionLabel: '앨범 추가하기',
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
          backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.85),
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(viewModel.isSearching ? Icons.close : Icons.search),
              onPressed: viewModel.toggleSearch,
              tooltip: '검색',
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _navigateToAddScreen(context, viewModel.currentView),
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
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AllSongsScreen()));
            break;
          case 'settings':
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'sort', child: ListTile(leading: Icon(Icons.sort), title: Text('정렬'))),
        PopupMenuItem(
          value: 'reorder',
          child: ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text(viewModel.isReorderMode ? '정렬 완료' : '순서 변경'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'all_songs', child: ListTile(leading: Icon(Icons.queue_music), title: Text('모든 곡 목록'))),
        const PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('설정'))),
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
      onLongPress: () {
        _showMoveAlbumSheet(context, album, viewModel);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)), // Default card radius
          side: BorderSide(
            color: _getBorderColor(),
            width: 2.5,
          ),
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

  void _showMoveAlbumSheet(BuildContext context, Album album, HomeViewModel viewModel) {
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
              color: theme.cardColor.withOpacity(0.85),
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
                    leading: Icon(isWishlist ? Icons.collections_bookmark_outlined : Icons.favorite_border),
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
              color: Colors.grey.shade300,
              child: const Center(child: Icon(Icons.album, size: 50, color: Colors.grey)),
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
            style: textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            album.artist,
            style: textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildFormatBadge() {
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
      top: 8,
      left: 8,
      child: _Badge(label: badgeLabel, color: badgeColor!),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 3)],
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}


// --- Helper methods that were in the original file, adapted for the new design ---

void _navigateToAddScreen(BuildContext context, AlbumView currentView) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => AddScreen(isWishlist: currentView == AlbumView.wishlist)),
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
              child: Text('정렬 순서', style: Theme.of(context).textTheme.titleLarge),
            ),
            ...SortOption.values.map((option) {
              return ListTile(
                leading: Icon(
                  _getSortOptionIcon(option),
                  color: viewModel.sortOption == option ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(
                  _getSortOptionText(option),
                  style: TextStyle(
                    fontWeight: viewModel.sortOption == option ? FontWeight.bold : null,
                    color: viewModel.sortOption == option ? Theme.of(context).colorScheme.primary : null,
                  ),
                ),
                trailing: viewModel.sortOption == option ? const Icon(Icons.check, color: Colors.blue) : null,
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
    case SortOption.custom: return '사용자 지정';
    case SortOption.artist: return '아티스트';
    case SortOption.title: return '앨범명';
    case SortOption.dateDescending: return '발매일 (최신순)';
    case SortOption.dateAscending: return '발매일 (오래된순)';
  }
}

IconData _getSortOptionIcon(SortOption option) {
  switch (option) {
    case SortOption.custom: return Icons.sort_by_alpha;
    case SortOption.artist: return Icons.person_outline;
    case SortOption.title: return Icons.album_outlined;
    case SortOption.dateDescending: return Icons.arrow_downward;
    case SortOption.dateAscending: return Icons.arrow_upward;
  }
}