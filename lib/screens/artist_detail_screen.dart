import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../viewmodels/artist_viewmodel.dart';
import '../viewmodels/global_artist_settings.dart';
import '../services/i_album_repository.dart';
import 'detail_screen.dart';

// region 아티스트 상세 화면 메인
class ArtistDetailScreen extends StatelessWidget {
  final String artistName;
  final String? sourceAlbumId;

  const ArtistDetailScreen({
    super.key,
    required this.artistName,
    this.sourceAlbumId,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ArtistViewModel(
        context.read<IAlbumRepository>(),
        context.read<GlobalArtistSettings>(), // 주입
      ),
      child: _ArtistDetailContent(
        artistName: artistName,
        sourceAlbumId: sourceAlbumId,
      ),
    );
  }
}

class _ArtistDetailContent extends StatefulWidget {
  final String artistName;
  final String? sourceAlbumId;

  const _ArtistDetailContent({required this.artistName, this.sourceAlbumId});

  @override
  State<_ArtistDetailContent> createState() => _ArtistDetailContentState();
}

class _ArtistDetailContentState extends State<_ArtistDetailContent> {
  // region 라이프사이클
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ArtistViewModel>().loadArtistData(widget.artistName);
    });
  }
  // endregion

  // region 이미지 선택
  Future<void> _pickImage() async {
    final viewModel = context.read<ArtistViewModel>();
    final hasImage = viewModel.currentArtist?.imagePath != null;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('갤러리에서 선택'),
                onTap: () async {
                  Navigator.pop(context);
                  final picker = ImagePicker();
                  final pickedFile = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (pickedFile != null && mounted) {
                    await viewModel.updateArtistImage(pickedFile.path);
                  }
                },
              ),
              if (hasImage)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    '이미지 삭제',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await viewModel.updateArtistImage(null);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
  // endregion

  // region UI 헬퍼
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
      'LP': Color(0xFFD4AF37),
      'CD': Color(0xFF607D8B),
      'DVD': Color(0xFF8E24AA),
      'Blu-ray': Color(0xFF2962FF),
    };
    final formatPriority = ['LP', 'CD', 'DVD', 'Blu-ray'];

    List<Widget> badges = [];

    for (final format in formatPriority) {
      if (album.formats.any(
        (f) => f.toLowerCase().contains(format.toLowerCase()),
      )) {
        badges.add(
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: formatColors[format],
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 3,
                ),
              ],
            ),
            child: Text(
              format,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    }

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 4,
      left: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: badges,
      ),
    );
  }
  // endregion

  // region 메인 UI
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey[50];
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      body: Consumer<ArtistViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final artist = viewModel.currentArtist;
          final albums = viewModel.artistAlbums;
          final imagePath = artist?.imagePath;

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 300.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: isDark ? Colors.black : Colors.white,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  leading: IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: innerBoxIsScrolled ? textColor : Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        viewModel.sortOrder == SortOrder.asc
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        color: innerBoxIsScrolled ? textColor : Colors.white,
                      ),
                      tooltip: viewModel.sortOrder == SortOrder.asc
                          ? '발매일 내림차순 정렬'
                          : '발매일 오름차순 정렬',
                      onPressed: () {
                        viewModel.toggleSortOrder();
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        color: innerBoxIsScrolled ? textColor : Colors.white,
                      ),
                      onPressed: () => _showEditDialog(context, viewModel),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: true,
                    title: Text(
                      widget.artistName,
                      style: TextStyle(
                        color: innerBoxIsScrolled ? textColor : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 배경용 블러 이미지
                        if (imagePath != null && File(imagePath).existsSync())
                          Image.file(File(imagePath), fit: BoxFit.cover)
                        else
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  isDark
                                      ? const Color(0xFF2C3E50)
                                      : const Color(0xFFBDC3C7),
                                  isDark ? Colors.black : Colors.white,
                                ],
                              ),
                            ),
                          ),

                        // 블러 효과
                        if (imagePath != null)
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                          ),

                        // 중앙 원형 이미지
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Hero(
                                  tag: 'artist_image_${widget.artistName}',
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 15,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        width: 4,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child:
                                          imagePath != null &&
                                              File(imagePath).existsSync()
                                          ? Image.file(
                                              File(imagePath),
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: Colors.grey[800],
                                              child: const Icon(
                                                Icons.person,
                                                size: 60,
                                                color: Colors.white54,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // 카메라 아이콘 (힌트)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.camera_alt,
                                        color: Colors.white70,
                                        size: 14,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        '이미지 변경',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (artist != null &&
                    (artist.aliases.isNotEmpty ||
                        artist.groups.isNotEmpty)) ...[
                  _buildInfoSection(
                    context,
                    artist,
                    viewModel,
                    isDark,
                    textColor,
                    bgColor ?? (isDark ? Colors.black : Colors.white),
                  ),
                  // 섹션 간 간격 (Sliver)
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],

                // 앨범 목록 헤더 (Sliver)
                if (albums.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Albums',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ];
            },
            body: albums.isEmpty
                ? _buildEmptyState(isDark)
                : _buildAlbumList(albums, isDark, cardColor, textColor),
          );
        },
      ),
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

  Widget _buildAlbumList(
    List<Album> albums,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        final isSourceAlbum = album.id == widget.sourceAlbumId;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isSourceAlbum ? 4 : 1,
          color: album.isWishlist
              ? (isDark
                    ? Colors.grey[900]?.withValues(alpha: 0.6)
                    : Colors.grey[100]?.withValues(alpha: 0.8))
              : (isSourceAlbum
                    ? (isDark ? Colors.indigo[900] : Colors.indigo[50])
                    : cardColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: album.isWishlist
                ? BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                    width: 0.5,
                  )
                : _getAlbumBorder(album, isSourceAlbum),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isSourceAlbum
                ? null
                : () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailScreen(album: album),
                      ),
                    );
                    // 돌아올 때 데이터 새로고침
                    if (context.mounted) {
                      context.read<ArtistViewModel>().loadArtistData(
                        widget.artistName,
                      );
                    }
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
                        child:
                            album.imagePath != null &&
                                File(album.imagePath!).existsSync()
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: ColorFiltered(
                                  colorFilter: album.isWishlist
                                      ? const ColorFilter.mode(
                                          Colors.grey,
                                          BlendMode.saturation,
                                        )
                                      : const ColorFilter.mode(
                                          Colors.transparent,
                                          BlendMode.multiply,
                                        ),
                                  child: Opacity(
                                    opacity: album.isWishlist ? 0.7 : 1.0,
                                    child: Image.file(
                                      File(album.imagePath!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.album,
                                size: 40,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                      ),
                      _buildFormatBadge(album),
                      if (album.isWishlist)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Icon(
                            Icons.favorite_border,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                album.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: album.isWishlist
                                      ? textColor.withValues(alpha: 0.6)
                                      : textColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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

  void _showEditDialog(BuildContext context, ArtistViewModel viewModel) {
    final artist = viewModel.currentArtist;
    if (artist == null) return;

    final aliasesController = TextEditingController(
      text: artist.aliases.join(', '),
    );

    // 그룹 관리를 위한 로컬 상태
    List<String> selectedGroups = List.from(artist.groups);
    final groupInputController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('아티스트 정보 편집'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: aliasesController,
                    decoration: const InputDecoration(
                      labelText: '배리에이션 (별명)',
                      hintText: '쉼표(,)로 구분하여 입력',
                      helperText: '검색 시 이 별명들도 함께 검색됩니다.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '그룹 내 (소속)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: selectedGroups.map((group) {
                      return InputChip(
                        label: Text(group),
                        onDeleted: () {
                          setState(() {
                            selectedGroups.remove(group);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Autocomplete<Artist>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Artist>.empty();
                      }
                      return viewModel.searchArtists(textEditingValue.text);
                    },
                    displayStringForOption: (Artist option) => option.name,
                    onSelected: (Artist selection) {
                      if (!selectedGroups.contains(selection.name)) {
                        setState(() {
                          selectedGroups.add(selection.name);
                        });
                      }
                      groupInputController.clear(); // 입력창 초기화
                    },
                    fieldViewBuilder:
                        (
                          context,
                          textEditingController,
                          focusNode,
                          onFieldSubmitted,
                        ) {
                          // 내부 컨트롤러와 외부 컨트롤러 동기화 (필요시)
                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: '그룹 추가',
                              hintText: '아티스트 이름 또는 별명 검색',
                              suffixIcon: Icon(Icons.search),
                            ),
                            onSubmitted: (value) {
                              if (value.isNotEmpty &&
                                  !selectedGroups.contains(value)) {
                                setState(() {
                                  selectedGroups.add(value);
                                });
                                textEditingController.clear();
                              }
                            },
                          );
                        },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: Container(
                            width: 300,
                            color: Theme.of(context).cardColor,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option.name),
                                  subtitle: option.aliases.isNotEmpty
                                      ? Text('별명: ${option.aliases.join(", ")}')
                                      : null,
                                  onTap: () {
                                    onSelected(option);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () {
                  final aliases = aliasesController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();

                  // selectedGroups는 이미 리스트 형태임
                  viewModel.updateArtistMetadata(aliases, selectedGroups);
                  Navigator.pop(context);
                },
                child: const Text('저장'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    Artist artist,
    ArtistViewModel viewModel,
    bool isDark,
    Color textColor,
    Color bgColor,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (artist.aliases.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          '배리에이션',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: artist.aliases.map((alias) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[700] : Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey[600]!
                                      : Colors.grey[300]!,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                alias,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                  height: 1.2,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              if (artist.groups.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        '그룹 내',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: artist.groups.map((group) {
                          final isExistingArtist = viewModel.artists.any(
                            (a) => a.name == group,
                          );
                          return GestureDetector(
                            onTap: isExistingArtist
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ArtistDetailScreen(
                                              artistName: group,
                                            ),
                                      ),
                                    );
                                  }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2.0,
                              ),
                              child: Text(
                                group,
                                style: TextStyle(
                                  color: isExistingArtist
                                      ? Colors.blue
                                      : textColor,
                                  fontSize: 13,
                                  decoration: isExistingArtist
                                      ? TextDecoration.underline
                                      : TextDecoration.none,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// endregion
