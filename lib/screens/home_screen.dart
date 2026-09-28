import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../models/album.dart';
import '../utils/file_utils.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/common_widgets.dart';
import '../widgets/animation_widgets.dart';
import '../services/haptic_service.dart';
import 'add_screen.dart';
import 'detail_screen.dart';
import 'settings_screen.dart';
import 'all_songs_screen.dart';
import 'artist_detail_screen.dart';
import '../services/i_album_repository.dart';

// region 홈 화면 메인
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PageController _pageController;
  final Map<AlbumView, String> _selectedAlbumIds = {};

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
      HapticService.toggle();
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
    final repository = context.read<IAlbumRepository>();
    final theme = Theme.of(context);

    // 외부 변경이 발생하면 PageController 동기화 (하지만 엄밀히 말하면 VM이 이제 onSegmentChanged를 통해 이를 구동함)
    // 하지만 세그먼트가 아닌 VM 변경 뷰라면(이 설정에서는 거의 없지만 가능함), 애니메이션을 적용하고 싶을 수 있습니다.
    // 현재로서는 루프를 피하기 위해 _onSegmentChanged가 애니메이션을 주도하도록 하는 것이 더 안전합니다.

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _HomeAppBar(viewModel: viewModel, repository: repository),
      body: LoadingOverlay(
        // 재로드 시 블로킹 오버레이가 깜빡이지 않도록 최초 로드에만 표시한다
        isLoading: viewModel.isLoading && !viewModel.hasAlbums,
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
                thumbColor: theme.colorScheme.surface,
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
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            // 검색창이 비어 있을 때 최근 검색어를 칩으로 노출한다
            if (viewModel.isSearching &&
                viewModel.searchQuery.isEmpty &&
                viewModel.recentSearches.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '최근 검색',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      for (final term in viewModel.recentSearches)
                        InputChip(
                          label: Text(term),
                          onPressed: () => viewModel.applyRecentSearch(term),
                          onDeleted: () => viewModel.removeRecentSearch(term),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  _buildContent(
                    context,
                    viewModel,
                    repository,
                    AlbumView.collection,
                  ),
                  _buildContent(
                    context,
                    viewModel,
                    repository,
                    AlbumView.wishlist,
                  ),
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
    IAlbumRepository repository,
    AlbumView view,
  ) {
    switch (viewModel.viewMode) {
      case ViewMode.listPreview:
        if (viewModel.isReorderMode) {
          return _buildAlbumGrid(context, viewModel, view, isCompact: false);
        }
        return _buildListPreview(context, viewModel, view);
      case ViewMode.artists:
        return _buildArtistList(context, viewModel, repository, view);
      case ViewMode.grid3:
        return _buildAlbumGrid(context, viewModel, view, isCompact: true);
      case ViewMode.grid2:
        return _buildAlbumGrid(context, viewModel, view, isCompact: false);
    }
  }

  Widget _buildListPreview(
    BuildContext context,
    HomeViewModel viewModel,
    AlbumView view,
  ) {
    final albums = viewModel.getAlbumsForView(view);
    if (albums.isEmpty) {
      return _buildAlbumGrid(context, viewModel, view, isCompact: false);
    }

    final selectedId = _selectedAlbumIds[view];
    final selected = albums.firstWhere(
      (album) => album.id == selectedId,
      orElse: () => albums.first,
    );
    final others = albums.where((album) => album.id != selected.id).toList();
    final theme = Theme.of(context);

    return ListView.builder(
      key: PageStorageKey('home-preview-${view.name}'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      itemCount: others.length + 1,
      itemBuilder: (context, index) {
        if (index > 0) {
          final album = others[index - 1];
          return _AlbumPreviewRow(
            album: album,
            onSelect: () => setState(() => _selectedAlbumIds[view] = album.id),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('앨범 목록', style: theme.textTheme.headlineLarge),
            const SizedBox(height: 6),
            Text(
              '${albums.length}장 · ${_getSortOptionText(viewModel.sortOption)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: reduceMotionEnabled
                  ? Duration.zero
                  : const Duration(milliseconds: 140),
              switchInCurve: Curves.easeOut,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.965, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: _AlbumPreviewCard(
                key: ValueKey('album-preview-${selected.id}'),
                album: selected,
              ),
            ),
            if (others.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text('다른 앨범', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  Widget _buildArtistList(
    BuildContext context,
    HomeViewModel viewModel,
    IAlbumRepository repository,
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
      // 검색 중이면 "없음"과 "결과 없음"을 구분해 안내한다
      if (viewModel.searchQuery.isNotEmpty) {
        return EmptyState(
          icon: Icons.search_off,
          message: '\'${viewModel.searchQuery}\'에 대한 검색 결과가 없습니다.',
        );
      }
      return EmptyState(
        icon: Icons.person_off_outlined,
        message: '등록된 아티스트가 없습니다.\n앨범을 추가하면 아티스트가 여기에 표시됩니다.',
        onAction: () => _navigateToAddScreen(context, view),
        actionLabel: '앨범 추가하기',
      );
    }

    return EntryAnimationLimiter(
      key: const ValueKey('artists'),
      child: ListView.separated(
        // 뷰 전환·화면 복귀 시 스크롤 위치를 복원한다
        key: PageStorageKey('home-artists-${view.name}'),
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
          final artist = repository.getArtistByName(artistName);

          return FadeSlideIn.staggered(
            index: index,
            child: ListTile(
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
                          fileExistsSync(artist!.imagePath!)
                      ? Image.file(
                          File(artist.imagePath!),
                          fit: BoxFit.cover,
                          cacheWidth: 150,
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                ),
              ),
              title: Text(
                artistName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '앨범 $albumCount장',
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
                HapticService.lightTap();
                Navigator.push(
                  context,
                  AnimatedPageRoute(
                    page: ArtistDetailScreen(artistName: artistName),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlbumGrid(
    BuildContext context,
    HomeViewModel viewModel,
    AlbumView view, {
    required bool isCompact,
  }) {
    final albums = viewModel.getAlbumsForView(view);

    // 토글은 "편하게/촘촘하게"를 고르고, 실제 열 수는 카드 최소 너비 기준으로
    // 화면 폭에 맞춘다. 폰(~400px)은 기존과 같이 2열/3열이 된다.
    final width = MediaQuery.sizeOf(context).width;
    final minTileWidth = isCompact ? 120.0 : 170.0;
    var crossAxisCount = (width / minTileWidth).floor();
    final minCount = isCompact ? 3 : 2;
    if (crossAxisCount < minCount) crossAxisCount = minCount;

    if (albums.isEmpty && !viewModel.isLoading) {
      if (viewModel.searchQuery.isNotEmpty) {
        return EmptyState(
          icon: Icons.search_off,
          message: '\'${viewModel.searchQuery}\'에 대한 검색 결과가 없습니다.',
        );
      }
      return EmptyState(
        icon: view == AlbumView.collection
            ? Icons.music_note_outlined
            : Icons.favorite_border,
        message: view == AlbumView.collection
            ? '아직 저장된 앨범이 없습니다.\n첫 앨범을 추가해 컬렉션을 시작해보세요.'
            : '위시리스트가 비었습니다.\n나중에 사고 싶은 앨범을 담아보세요.',
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
        key: PageStorageKey('home-grid-${view.name}'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: isCompact ? 12 : 16,
          mainAxisSpacing: isCompact ? 12 : 16,
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
            child: _AlbumCard(album: album, isCompact: isCompact),
          );
        },
      );
    }

    return EntryAnimationLimiter(
      key: ValueKey('grid$crossAxisCount'),
      child: GridView.builder(
        // 뷰 전환·화면 복귀 시 스크롤 위치를 복원한다
        key: PageStorageKey('home-grid-${view.name}'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: isCompact ? 12 : 16,
          mainAxisSpacing: isCompact ? 12 : 16,
          childAspectRatio: 0.75,
        ),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          return FadeSlideIn.staggered(
            index: index,
            child: _AlbumCard(album: album, isCompact: isCompact),
          );
        },
      ),
    );
  }
}
// endregion

// region 앱바 위젯
class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HomeAppBar({required this.viewModel, required this.repository});

  final HomeViewModel viewModel;
  final IAlbumRepository repository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AppBar(
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: viewModel.isSearching
                ? CupertinoSearchTextField(
                    key: const ValueKey('search-field'),
                    controller: viewModel.searchController,
                    autofocus: true,
                    onChanged: viewModel.setSearchQuery,
                    onSubmitted: viewModel.recordSearch,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  )
                : const Text('MuseArchive', key: ValueKey('app-title')),
          ),
          backgroundColor: theme.scaffoldBackgroundColor.withValues(
            alpha: 0.85,
          ),
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(viewModel.isSearching ? Icons.close : Icons.search),
              onPressed: () {
                HapticService.lightTap();
                viewModel.toggleSearch();
              },
              tooltip: '검색',
            ),
            IconButton(
              icon: Icon(
                viewModel.viewMode == ViewMode.listPreview
                    ? Icons.grid_view_rounded
                    : viewModel.viewMode == ViewMode.grid2
                    ? Icons.grid_3x3_rounded
                    : viewModel.viewMode == ViewMode.grid3
                    ? Icons.people_alt_outlined
                    : Icons.view_list_rounded,
              ),
              onPressed: () {
                HapticService.toggle();
                viewModel.toggleViewMode();
              },
              tooltip: viewModel.viewMode == ViewMode.listPreview
                  ? '2열 그리드로 보기'
                  : viewModel.viewMode == ViewMode.grid2
                  ? '3열 그리드로 보기'
                  : viewModel.viewMode == ViewMode.grid3
                  ? '아티스트 목록으로 보기'
                  : '목록과 미리보기로 보기',
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                HapticService.lightTap();
                _navigateToAddScreen(context, viewModel.currentView);
              },
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
        HapticService.selection();
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
              AnimatedPageRoute(page: AllSongsScreen(repository: repository)),
            );
            break;
          case 'settings':
            Navigator.push(
              context,
              AnimatedPageRoute(page: const SettingsScreen()),
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

class _AlbumPreviewCard extends StatelessWidget {
  const _AlbumPreviewCard({super.key, required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.read<HomeViewModel>();

    void openDetail() async {
      HapticService.lightTap();
      final result = await Navigator.push(
        context,
        AnimatedPageRoute(page: DetailScreen(album: album)),
      );
      if (result == true) viewModel.loadAlbums();
    }

    void openMenu() {
      HapticService.dragStart();
      _AlbumCard.showMoveAlbumSheet(context, album, viewModel);
    }

    return Semantics(
      label: '${album.title}, ${album.artist} 앨범 미리보기',
      button: true,
      onTap: openDetail,
      onLongPress: openMenu,
      child: TapScaleWrapper(
        onTap: openDetail,
        onLongPress: openMenu,
        child: Card(
          margin: EdgeInsets.zero,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AlbumPreviewCover(album: album, size: 105, hero: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        album.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (album.releaseDateString.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          album.releaseDateString,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: openDetail,
                        child: const Text('상세 보기'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlbumPreviewRow extends StatelessWidget {
  const _AlbumPreviewRow({required this.album, required this.onSelect});

  final Album album;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.read<HomeViewModel>();

    void select() {
      HapticService.selection();
      onSelect();
    }

    void openMenu() {
      HapticService.dragStart();
      _AlbumCard.showMoveAlbumSheet(context, album, viewModel);
    }

    return Semantics(
      label: '${album.title}, ${album.artist} 앨범 미리보기 선택',
      button: true,
      onTap: select,
      onLongPress: openMenu,
      child: TapScaleWrapper(
        onTap: select,
        onLongPress: openMenu,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              _AlbumPreviewCover(album: album, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      album.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumPreviewCover extends StatelessWidget {
  const _AlbumPreviewCover({
    required this.album,
    required this.size,
    this.hero = false,
  });

  final Album album;
  final double size;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget cover = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: size,
        child: album.imagePath != null && fileExistsSync(album.imagePath!)
            ? Image.file(
                File(album.imagePath!),
                fit: BoxFit.cover,
                cacheWidth: 400,
              )
            : ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  Icons.album_outlined,
                  color: scheme.primary,
                  size: size * 0.42,
                ),
              ),
      ),
    );
    if (hero) cover = Hero(tag: 'album-cover-${album.id}', child: cover);
    return cover;
  }
}

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

    void openDetail() async {
      HapticService.lightTap();
      final result = await Navigator.push(
        context,
        AnimatedPageRoute(page: DetailScreen(album: album)),
      );
      if (result == true) {
        viewModel.loadAlbums();
      }
    }

    void openMenu() {
      HapticService.dragStart();
      showMoveAlbumSheet(context, album, viewModel);
    }

    final artistLabel = album.artists.join(', ');
    return Semantics(
      label: artistLabel.isEmpty
          ? '${album.title} 앨범'
          : '${album.title}, $artistLabel 앨범',
      button: true,
      // 스크린리더 활성화 액션이 실제 카드 제스처와 동일하게 동작하도록 연결한다
      onTap: openDetail,
      onLongPress: canShowMenu ? openMenu : null,
      child: ExcludeSemantics(
        child: _buildCard(
          context,
          viewModel,
          canShowMenu,
          openDetail,
          openMenu,
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    HomeViewModel viewModel,
    bool canShowMenu,
    VoidCallback onOpenDetail,
    VoidCallback onOpenMenu,
  ) {
    return TapScaleWrapper(
      enabled: canShowMenu,
      onTap: onOpenDetail,
      onLongPress: canShowMenu ? onOpenMenu : null,
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

  static void showMoveAlbumSheet(
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
                  // 시트 배경이 투명해 기본 showDragHandle이 카드 밖에
                  // 뜨므로, 카드 안쪽에 핸들을 직접 그린다
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
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
                      HapticService.selection();
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
                    onTap: () async {
                      HapticService.warning();
                      Navigator.pop(builderContext);
                      final confirm = await ConfirmDialog.show(
                        context,
                        title: '앨범 삭제',
                        content: '정말로 이 앨범을 삭제하시겠습니까?',
                        confirmText: '삭제',
                        isDestructive: true,
                      );
                      if (!confirm || !context.mounted) return;
                      await deleteAlbumWithUndo(
                        context.read<IAlbumRepository>(),
                        album,
                        ScaffoldMessenger.of(context),
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
      child: (album.imagePath != null && fileExistsSync(album.imagePath!))
          ? Image.file(
              File(album.imagePath!),
              fit: BoxFit.cover,
              cacheWidth: 600,
            )
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
            album.artists.join(', '),
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
    if (album.formats.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: isCompact ? 4 : 8,
      left: isCompact ? 4 : 8,
      child: AlbumFormatBadges(formats: album.formats, isCompact: isCompact),
    );
  }
}
// endregion

// region 헬퍼 메서드
// --- 원래 파일에 있던 도우미 메서드, 새 디자인에 맞춰 조정됨 ---

void _navigateToAddScreen(BuildContext context, AlbumView currentView) {
  Navigator.push(
    context,
    AnimatedPageRoute(
      page: AddScreen(isWishlist: currentView == AlbumView.wishlist),
    ),
  );
}

void _showSortOptions(BuildContext context, HomeViewModel viewModel) async {
  final selected = await showModalBottomSheet<SortOption>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
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
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, option),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );

  if (selected != null) {
    HapticService.selection();
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
