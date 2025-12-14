import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reorderables/reorderables.dart';
import '../models/album.dart';
import '../models/track.dart';
import '../models/value_objects/release_date.dart';
import '../viewmodels/album_form_viewmodel.dart';
import '../widgets/common_widgets.dart';
import 'barcode_scanner_screen.dart';

class AddScreen extends StatefulWidget {
  final Album? albumToEdit;
  final bool isWishlist;

  const AddScreen({super.key, this.albumToEdit, this.isWishlist = false});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  late final AlbumFormViewModel _viewModel;
  final _formKey = GlobalKey<FormState>();

  final _controllers = _FormControllers();
  Timer? _debounce;

  String? _albumId;

  @override
  void initState() {
    super.initState();
    _albumId = widget.albumToEdit?.id;

    // Post-frame callback to safely access context and initialize VM
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _viewModel = context.read<AlbumFormViewModel>();
      _viewModel.initialize(widget.albumToEdit, widget.isWishlist);
      _viewModel.addListener(_updateControllers);
      _controllers.setupInitial(context, _viewModel);
      _controllers.addListener(_onFieldChanged);

      // If we are starting with a new album, the VM creates one with a new ID.
      // We don't set _albumId yet; we wait for the first save.
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _viewModel.removeListener(_updateControllers);
    _controllers.removeListener(_onFieldChanged);
    _controllers.dispose();
    super.dispose();
  }

  void _updateControllers() {
    // Only update from ViewModel if we are not actively editing
    // or if the change came from an external source (like barcode scan)
    // This is tricky with two-way binding.
    // Simplified: We trust _FormControllers to hold the truth while editing.
    // But if ViewModel changes drastically (e.g. search result loaded), we must update controllers.

    if (_viewModel.isLoading) return; // Don't update while loading

    // We can check specific flags or just update if the ViewModel has "newer" data that wasn't user input.
    // For now, relies on explicit updates from VM side or careful management.
    // In this specific architecture, updateControllers is called on VM notify.
    // We should be careful not to overwrite user input if the user is typing.
    // But since VM update usually happens on 'save' or 'load', it should be fine.

    // Ideally we'd have a 'source' of change.
    // For this task, we will just update.
    _controllers.update(_viewModel);

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onFieldChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      _saveIfNeeded();
    });
  }

  Future<void> _saveIfNeeded() async {
    if (!mounted) return;

    final title = _controllers.title.text.trim();
    final artist = _controllers.artist.text.trim();

    // Checklist Requirement: Require at least Title and Artist.
    if (title.isEmpty || artist.isEmpty) {
      // If essential fields are empty, we do NOT create/update the album yet.
      return;
    }

    _controllers.commitChanges(_viewModel);

    // Debug Log
    // Debug Log removed for production
    // print("DEBUG: Saving Album...");

    await _viewModel.saveAlbum(_albumId);

    // After first save of a new album, capture the ID so future saves are updates, not creates.
    if (_albumId == null && _viewModel.currentAlbum != null) {
      if (mounted) {
        setState(() {
          _albumId = _viewModel.currentAlbum!.id;
        });
      }
      // print("DEBUG: Album created...");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Trigger a final save check before allowing exit
        // We cancel the debounce to prevent double-save, then save immediately.
        if (_debounce?.isActive ?? false) _debounce!.cancel();

        // Only attempt save if there's a title (to avoid error/ghost)
        // and if there are actual changes
        await _saveIfNeeded();

        if (context.mounted) Navigator.pop(context);
      },
      child: Consumer<AlbumFormViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.errorMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) ErrorSnackBar.show(context, viewModel.errorMessage!);
              viewModel.clearError();
            });
          }

          return Scaffold(
            appBar: _buildAppBar(context, viewModel),
            body: SafeArea(
              child: Stack(
                children: [
                  if (viewModel.currentAlbum != null)
                    Form(key: _formKey, child: _buildForm(context, viewModel)),
                  if (viewModel.isLoading)
                    Positioned.fill(
                      child: Container(
                        color: theme.scaffoldBackgroundColor.withValues(
                          alpha: 0.5,
                        ),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, AlbumFormViewModel viewModel) {
    return AppBar(
      title: Text(widget.albumToEdit == null ? '앨범 추가' : '앨범 수정'),
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: () => _scanBarcode(context, viewModel),
          tooltip: '바코드 스캔',
        ),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => _showSearchDialog(context, viewModel),
          tooltip: 'Discogs에서 검색',
        ),
        // Save button removed for auto-save
      ],
    );
  }

  Widget _buildForm(BuildContext context, AlbumFormViewModel viewModel) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildSection('기본 정보', [
                _ImagePicker(
                  viewModel: viewModel,
                  onTap: () => _showImageSourceSelection(context),
                ),
                const SizedBox(height: 16),
                _buildTextField(_controllers.title, '앨범 제목', isRequired: true),
                _buildTextField(_controllers.titleKr, '앨범 제목 (한국어)'),
                _buildTextField(_controllers.artist, '아티스트', isRequired: true),
              ]),
              _buildSection('세부 정보', [
                _buildTextField(_controllers.desc, '설명', maxLines: 4),
                _buildDateField(context), // New Date Picker Field
                _buildTextField(
                  _controllers.link,
                  '음악 듣기 링크',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Color(0xFF1DB954)),
                    tooltip: 'Spotify에서 링크 검색',
                    onPressed: () async {
                      final configured = await viewModel.isSpotifyConfigured();
                      if (configured && mounted) {
                        _showSpotifyLinkSearchDialog(context, viewModel);
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('설정에서 Spotify 키를 입력해주세요.'),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ]),
              _buildSection('분류', [
                _buildTextField(_controllers.label, '레이블 (쉼표로 구분)'),
                _buildTextField(_controllers.format, '포맷 (쉼표로 구분)'),
                _buildTextField(_controllers.genre, '장르 (쉼표로 구분)'),
                _buildTextField(_controllers.style, '스타일 (쉼표로 구분)'),
              ]),
              _buildSection('옵션', [
                _buildSwitchTile('한정판', viewModel.currentAlbum!.isLimited, (v) {
                  viewModel.updateCurrentAlbum(
                    viewModel.currentAlbum!.copyWith(isLimited: v),
                  );
                  _onFieldChanged(); // Trigger auto-save
                }),
                _buildSwitchTile('특이사항', viewModel.currentAlbum!.isSpecial, (
                  v,
                ) {
                  viewModel.updateCurrentAlbum(
                    viewModel.currentAlbum!.copyWith(isSpecial: v),
                  );
                  _onFieldChanged();
                }),
                _buildSwitchTile('위시리스트', viewModel.currentAlbum!.isWishlist, (
                  v,
                ) {
                  viewModel.updateCurrentAlbum(
                    viewModel.currentAlbum!.copyWith(isWishlist: v),
                  );
                  _onFieldChanged();
                }),
              ]),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('트랙 리스트', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.album_outlined),
                          label: const Text('디스크 추가'),
                          onPressed: () {
                            viewModel.addNewDisc();
                            _onFieldChanged();
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('트랙 추가'),
                          onPressed: () {
                            viewModel.addTrack(Track(title: ''));
                            _onFieldChanged();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: ReorderableSliverList(
            delegate: ReorderableSliverChildBuilderDelegate((context, index) {
              final track = viewModel.currentAlbum!.tracks[index];
              return _TrackListItemWidget(
                key: ValueKey(track.id),
                track: track,
                viewModel: viewModel,
                index: index,
                onChanged: _onFieldChanged, // Pass callback
              );
            }, childCount: viewModel.currentAlbum!.tracks.length),
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                viewModel.reorderTracks(oldIndex, newIndex);
                _onFieldChanged();
              });
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isRequired = false,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, suffixIcon: suffixIcon),
        maxLines: maxLines,
        // Validation visually hints but doesn't block strictly since we allow loose saving,
        // but for title we want to ensure it is there for meaningful record.
        validator: isRequired
            ? (value) =>
                  value == null || value.isEmpty ? '$label 필드는 필수입니다.' : null
            : null,
      ),
    );
  }

  Widget _buildDateField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () async {
          final initialDate =
              DateTime.tryParse(_controllers.date.text.replaceAll('.', '-')) ??
              DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: initialDate,
            firstDate: DateTime(1900),
            lastDate: DateTime(2100),
            locale: const Locale('ko', 'KR'),
          );
          if (picked != null) {
            final formatted =
                '${picked.year}.${picked.month.toString().padLeft(2, '0')}.${picked.day.toString().padLeft(2, '0')}';
            if (_controllers.date.text != formatted) {
              _controllers.date.text = formatted;
              // Trigger immediate save for date changes to avoid race conditions with navigation
              _saveIfNeeded();
            }
          }
        },
        child: IgnorePointer(
          child: TextFormField(
            controller: _controllers.date,
            decoration: const InputDecoration(
              labelText: '발매일',
              suffixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      activeThumbColor: Theme.of(context).colorScheme.primary,
    );
  }

  // --- Actions ---

  Future<void> _scanBarcode(
    BuildContext context,
    AlbumFormViewModel viewModel,
  ) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result != null && mounted) {
      await viewModel.searchByBarcode(result);
      _onFieldChanged();
    }
  }

  Future<void> _showSearchDialog(
    BuildContext context,
    AlbumFormViewModel viewModel,
  ) async {
    final searchTitleController = TextEditingController(
      text: _controllers.title.text,
    );
    final searchArtistController = TextEditingController(
      text: _controllers.artist.text,
    );

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Discogs 앨범 검색'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: searchArtistController,
                decoration: const InputDecoration(labelText: '아티스트 (선택 사항)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: searchTitleController,
                decoration: const InputDecoration(labelText: '앨범 제목'),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'artist': searchArtistController.text,
                'title': searchTitleController.text,
              }),
              child: const Text('검색'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      final artist = result['artist']?.trim();
      final title = result['title']?.trim();

      if ((title != null && title.isNotEmpty) ||
          (artist != null && artist.isNotEmpty)) {
        final searchResults = await viewModel.searchByTitleArtist(
          artist: artist,
          title: title,
        );
        if (mounted) {
          _showSearchResultsDialog(context, viewModel, searchResults);
        }
      }
    }
  }

  Future<void> _showSearchResultsDialog(
    BuildContext context,
    AlbumFormViewModel viewModel,
    List<dynamic> results,
  ) async {
    if (!mounted) return;

    if (results.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('검색 결과가 없습니다.')));
      return;
    }

    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('앨범 검색 결과', style: theme.textTheme.headlineSmall),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 20.0,
            horizontal: 8,
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                final imageUrl = result['thumb'] as String?;
                final title = result['title'] ?? '제목 없음';
                final artist = result['artist'] ?? '아티스트 없음';
                final year = result['year']?.toString() ?? '';
                final format = result['format'] as String? ?? '';

                return InkWell(
                  onTap: () async {
                    final releaseId = result['id'];
                    if (releaseId != null) {
                      Navigator.pop(dialogContext);
                      await viewModel.loadAlbumById(releaseId);
                      _onFieldChanged();
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Album Art
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Container(
                            width: 80,
                            height: 80,
                            color: theme.colorScheme.surface,
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.0,
                                              value:
                                                  loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                          Icons.music_note,
                                          size: 40,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                  )
                                : Icon(
                                    Icons.music_note,
                                    size: 40,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Album Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                artist,
                                style: theme.textTheme.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$year · $format',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSpotifySearchDialog(
    BuildContext context,
    AlbumFormViewModel viewModel,
  ) async {
    final searchController = TextEditingController(
      text: _controllers.title.text,
    );

    try {
      final query = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Spotify 이미지 검색'),
            content: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: '검색어 (앨범명/아티스트)',
                hintText: '예: Pink Floyd Dark Side',
              ),
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                Navigator.pop(dialogContext, value);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, searchController.text),
                child: const Text('검색'),
              ),
            ],
          );
        },
      );

      if (query != null && query.isNotEmpty && mounted) {
        final results = await viewModel.searchSpotifyForConnect(query);
        if (mounted) {
          _showSpotifyResultsDialog(context, viewModel, results);
        }
      }
    } finally {
      searchController.dispose();
    }
  }

  Future<void> _showSpotifyResultsDialog(
    BuildContext context,
    AlbumFormViewModel viewModel,
    List<Map<String, String>> results,
  ) async {
    if (results.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('검색 결과가 없습니다.')));
      }
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Spotify 검색 결과'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final album = results[index];
                final hasImage =
                    album['image_url'] != null &&
                    album['image_url']!.isNotEmpty;
                return ListTile(
                  leading: hasImage
                      ? Image.network(
                          album['image_url']!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, _, __) => const Icon(Icons.album),
                        )
                      : const Icon(Icons.album),
                  title: Text(album['title'] ?? ''),
                  subtitle: Text(
                    '${album['artist']} (${album['release_date']})',
                  ),
                  onTap: () {
                    // 1. Pop the dialog immediately using its context
                    Navigator.pop(dialogContext);

                    if (hasImage) {
                      // 2. Schedule the async update on the next microtask
                      // using the parent 'context' (AddScreen's context) if needed,
                      // but here we just need to ensure we don't hold onto dialogContext.
                      Future.microtask(() async {
                        if (mounted) {
                          await viewModel.updateFromSpotify(
                            imageUrl: album['image_url']!,
                            linkUrl: album['external_url'],
                          );
                          if (mounted) _onFieldChanged();
                        }
                      });
                    } else {
                      // Use parent context for snackbar, not dialog's
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('이미지가 없는 앨범입니다.')),
                        );
                      }
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDiscogsSearchForImage(
    BuildContext context,
    AlbumFormViewModel viewModel,
  ) async {
    // Reuse the existing search dialog logic but intent is only image
    // Ideally we duplicate the dialog or refactor, for now let's reuse simple logic
    // Or just simple title search
    final searchController = TextEditingController(
      text: _controllers.title.text,
    );

    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Discogs 이미지 검색'),
          content: TextField(
            controller: searchController,
            decoration: const InputDecoration(labelText: '검색어'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, searchController.text),
              child: const Text('검색'),
            ),
          ],
        );
      },
    );

    if (query != null && query.isNotEmpty && mounted) {
      final results = await viewModel.searchByTitleArtist(title: query);
      if (mounted) {
        _showDiscogsImageResults(context, viewModel, results);
      }
    }
  }

  void _showDiscogsImageResults(
    BuildContext context,
    AlbumFormViewModel viewModel,
    List<dynamic> results,
  ) {
    if (results.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('검색 결과가 없습니다.')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이미지 선택'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final item = results[index];
              final thumb = item['thumb'] as String?;
              return InkWell(
                onTap: () async {
                  Navigator.pop(context);
                  // Need to fetch full details to get high res image?
                  // Or just use thumb? Often 'thumb' is low res. 'cover_image' might be available in full search
                  // But search result usually has 'thumb'.
                  // Let's try to load detailed album first to extract image
                  if (item['id'] != null) {
                    // We can reuse loadAlbumById but that overwrites everything.
                    // We need a helper to just get Image from ID.
                    // Or just use thumb for now.
                    if (thumb != null) {
                      await viewModel.updateCoverFromUrl(thumb);
                      _onFieldChanged();
                    }
                  }
                },
                child: thumb != null
                    ? Image.network(thumb, fit: BoxFit.cover)
                    : const Icon(Icons.broken_image),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showImageSourceSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('사진 보관함에서 선택'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final imagePath = await _viewModel.pickImage();
                if (imagePath != null && mounted) {
                  _viewModel.updateCurrentAlbum(
                    _viewModel.currentAlbum!.copyWith(imagePath: imagePath),
                  );
                  _onFieldChanged();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.album),
              title: const Text('Discogs에서 검색'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showDiscogsSearchForImage(context, _viewModel);
              },
            ),
            ListTile(
              leading: const Icon(Icons.music_note, color: Color(0xFF1DB954)),
              title: const Text('Spotify에서 검색'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final configured = await _viewModel.isSpotifyConfigured();
                if (configured && mounted) {
                  _showSpotifySearchDialog(context, _viewModel);
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('설정에서 Spotify 키를 입력해주세요.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSpotifyLinkSearchDialog(
    BuildContext context,
    AlbumFormViewModel viewModel,
  ) async {
    final searchController = TextEditingController(
      text: _controllers.title.text,
    );

    try {
      final query = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Spotify 링크 검색'),
            content: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: '검색어 (앨범명/아티스트)',
                hintText: '예: Unhappy Refrain',
              ),
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                Navigator.pop(dialogContext, value);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, searchController.text),
                child: const Text('검색'),
              ),
            ],
          );
        },
      );

      if (query != null && query.isNotEmpty && mounted) {
        final results = await viewModel.searchSpotifyForConnect(query);
        if (mounted) {
          _showSpotifyLinkResultsDialog(context, viewModel, results);
        }
      }
    } finally {
      searchController.dispose();
    }
  }

  Future<void> _showSpotifyLinkResultsDialog(
    BuildContext context,
    AlbumFormViewModel viewModel,
    List<Map<String, String>> results,
  ) async {
    if (results.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('검색 결과가 없습니다.')));
      }
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Spotify 링크 검색 결과'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final album = results[index];
                final hasImage =
                    album['image_url'] != null &&
                    album['image_url']!.isNotEmpty;
                return ListTile(
                  leading: hasImage
                      ? Image.network(
                          album['image_url']!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, _, __) => const Icon(Icons.album),
                        )
                      : const Icon(Icons.album),
                  title: Text(album['title'] ?? ''),
                  subtitle: Text(
                    '${album['artist']} (${album['release_date']})',
                  ),
                  onTap: () {
                    final link = album['external_url'];
                    Navigator.pop(dialogContext);

                    if (link != null && link.isNotEmpty) {
                      if (mounted) {
                        _controllers.link.text = link;
                        _onFieldChanged(); // Trigger save
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Spotify 링크가 적용되었습니다.')),
                        );
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('링크 정보가 없는 앨범입니다.')),
                        );
                      }
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }
}

class _ImagePicker extends StatelessWidget {
  final AlbumFormViewModel viewModel;
  // We need access to the parent state to trigger the modal which is defined in State.
  // Or better, pass the callback.
  // But _AddScreenState is private.
  // We can just find the ancestor state or pass a callback.
  // The easiest valid way is to modify the constructor or make _ImagePicker part of the main file logic.
  // Since it's already in the same file, let's just use a callback.
  // But the replacement block above didn't change the constructor call site (which is in _buildSection).
  // So I cannot easily add a parameter without changing _buildSection.
  // Wait, _AddScreenState can just pass the function if I change the call site.
  // OR, I can move the logic INTO this widget if I pass 'context' (it has context in build).
  // But _showImageSourceSelection is in _AddScreenState currently (in my proposed code above).
  // Actually, I pasted the methods INSIDE _AddScreenState (implicitly, by replacing _ImagePicker but wait...
  // The target lines I selected (644-711) contain the _ImagePicker class definition.
  // If I overwrite it with methods, I break the file structure if I don't put it in the class.
  // My bad.
  // The methods `_showSpotifySearchDialog` etc. should be in `_AddScreenState`.
  // `_ImagePicker` should be a widget that calls `_showImageSourceSelection`.
  // I must be careful with placement.

  // Re-evaluating:
  // I will make `_ImagePicker` accept `VoidCallback onPickImage`.
  // And in `_buildSection`, I will pass `() => _showImageSourceSelection(context)`.

  // Let's redefine _ImagePicker to accept the callback.
  final VoidCallback onTap;

  const _ImagePicker({required this.viewModel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final album = viewModel.currentAlbum!;
    final theme = Theme.of(context);
    final heroTag = 'add-album-cover-${album.id}';

    return Center(
      child: Hero(
        tag: heroTag,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor, width: 2),
              image:
                  album.imagePath != null && File(album.imagePath!).existsSync()
                  ? DecorationImage(
                      image: FileImage(File(album.imagePath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child:
                (album.imagePath == null ||
                    !File(album.imagePath!).existsSync())
                ? Center(
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

// A dedicated StatefulWidget for each track item to manage its own controllers.
class _TrackListItemWidget extends StatefulWidget {
  final Track track;
  final AlbumFormViewModel viewModel;
  final int index;
  final VoidCallback onChanged;

  const _TrackListItemWidget({
    required Key key,
    required this.track,
    required this.viewModel,
    required this.index,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<_TrackListItemWidget> createState() => _TrackListItemWidgetState();
}

class _TrackListItemWidgetState extends State<_TrackListItemWidget> {
  late final TextEditingController _titleController;
  late final TextEditingController _titleKrController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.track.title);
    _titleKrController = TextEditingController(text: widget.track.titleKr);

    _titleController.addListener(_onTitleChanged);
    _titleKrController.addListener(_onTitleKrChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleKrController.removeListener(_onTitleKrChanged);
    _titleController.dispose();
    _titleKrController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TrackListItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.track != oldWidget.track) {
      if (widget.track.title != _titleController.text) {
        _titleController.text = widget.track.title;
      }
      if (widget.track.titleKr != _titleKrController.text) {
        _titleKrController.text = widget.track.titleKr ?? '';
      }
    }
  }

  void _onTitleChanged() {
    if (widget.track.title != _titleController.text) {
      widget.viewModel.updateTrack(
        widget.index,
        widget.track.copyWith(title: _titleController.text),
      );
      widget.onChanged();
    }
  }

  void _onTitleKrChanged() {
    if (widget.track.titleKr != _titleKrController.text) {
      widget.viewModel.updateTrack(
        widget.index,
        widget.track.copyWith(titleKr: _titleKrController.text),
      );
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHeader = widget.track.isHeader;

    if (isHeader) {
      return ReorderableDragStartListener(
        index: widget.index,
        child: Card(
          key: widget.key,
          margin: const EdgeInsets.symmetric(vertical: 6),
          color: theme.colorScheme.secondary.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Icon(Icons.drag_handle),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '디스크 제목',
                      border: InputBorder.none,
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle,
                    color: Colors.redAccent,
                  ),
                  onPressed: () {
                    widget.viewModel.removeTrack(widget.index);
                    widget.onChanged();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Calculate track number within the disc
      int trackNumberInDisc = 0;
      final tracks = widget.viewModel.currentAlbum!.tracks;
      for (int i = 0; i <= widget.index; i++) {
        if (tracks[i].isHeader) {
          trackNumberInDisc = 0;
        } else {
          trackNumberInDisc++;
        }
      }

      return ReorderableDragStartListener(
        index: widget.index,
        child: Card(
          key: widget.key,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Icon(Icons.drag_handle),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: '트랙 $trackNumberInDisc',
                          border: InputBorder.none,
                        ),
                      ),
                      TextFormField(
                        controller: _titleKrController,
                        decoration: InputDecoration(
                          labelText: '트랙 $trackNumberInDisc (한국어)',
                          border: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: () {
                    widget.viewModel.removeTrack(widget.index);
                    widget.onChanged();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}

class _FormControllers {
  final title = TextEditingController();
  final titleKr = TextEditingController();
  final artist = TextEditingController();
  final date = TextEditingController();
  final desc = TextEditingController();
  final link = TextEditingController();
  final label = TextEditingController();
  final format = TextEditingController();
  final genre = TextEditingController();
  final style = TextEditingController();

  void setupInitial(BuildContext context, AlbumFormViewModel viewModel) {
    update(viewModel);
  }

  void addListener(VoidCallback listener) {
    title.addListener(listener);
    titleKr.addListener(listener);
    artist.addListener(listener);
    date.addListener(listener);
    desc.addListener(listener);
    link.addListener(listener);
    label.addListener(listener);
    format.addListener(listener);
    genre.addListener(listener);
    style.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    title.removeListener(listener);
    titleKr.removeListener(listener);
    artist.removeListener(listener);
    date.removeListener(listener);
    desc.removeListener(listener);
    link.removeListener(listener);
    label.removeListener(listener);
    format.removeListener(listener);
    genre.removeListener(listener);
    style.removeListener(listener);
  }

  void update(AlbumFormViewModel viewModel) {
    final album = viewModel.currentAlbum;
    if (album == null) return;

    _updateText(title, album.title);
    _updateText(titleKr, album.titleKr ?? '');
    _updateText(artist, album.artist);
    _updateText(date, album.releaseDate.format());
    _updateText(desc, album.description);
    _updateText(link, album.linkUrl ?? '');
    _updateText(label, album.labels.join(', '));
    _updateText(format, album.formats.join(', '));
    _updateText(genre, album.genres.join(', '));
    _updateText(style, album.styles.join(', '));
  }

  void commitChanges(AlbumFormViewModel viewModel) {
    final album = viewModel.currentAlbum;
    if (album == null) return;

    // The view model's tracks are already up-to-date. We only commit the other fields.
    viewModel.updateCurrentAlbum(
      album.copyWith(
        title: title.text,
        titleKr: titleKr.text,
        artist: artist.text,
        releaseDate: ReleaseDate.parse(date.text),
        description: desc.text,
        linkUrl: link.text,
        labels: label.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        formats: format.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        genres: genre.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        styles: style.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      ),
    );
  }

  void _updateText(TextEditingController controller, String text) {
    if (controller.text != text) {
      controller.text = text;
    }
  }

  void dispose() {
    title.dispose();
    titleKr.dispose();
    artist.dispose();
    date.dispose();
    desc.dispose();
    link.dispose();
    label.dispose();
    format.dispose();
    genre.dispose();
    style.dispose();
  }
}
