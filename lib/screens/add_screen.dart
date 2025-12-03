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

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<AlbumFormViewModel>();
    _viewModel.initialize(widget.albumToEdit, widget.isWishlist);
    _viewModel.addListener(_updateControllers);
    _controllers.setupInitial(context, _viewModel);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_updateControllers);
    _controllers.dispose();
    super.dispose();
  }

  void _updateControllers() {
    _controllers.update(_viewModel);
    if (mounted) {
      // Defer the setState call to after the build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Consumer<AlbumFormViewModel>(
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
                  Form(
                    key: _formKey,
                    child: _buildForm(context, viewModel),
                  ),
                if (viewModel.isLoading)
                  Positioned.fill(
                    child: Container(
                      color: theme.scaffoldBackgroundColor.withOpacity(0.5),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
          child: ElevatedButton(
            onPressed: () => _saveForm(context, viewModel),
            child: const Text('저장'),
          ),
        ),
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
                _ImagePicker(viewModel: viewModel),
                const SizedBox(height: 16),
                _buildTextField(_controllers.title, '앨범 제목', isRequired: true),
                _buildTextField(_controllers.artist, '아티스트', isRequired: true),
              ]),
              _buildSection('세부 정보', [
                _buildTextField(_controllers.desc, '설명', maxLines: 4),
                _buildTextField(_controllers.date, '발매일 (YYYY.MM.DD)'),
                _buildTextField(_controllers.link, '음악 듣기 링크'),
              ]),
              _buildSection('분류', [
                _buildTextField(_controllers.label, '레이블 (쉼표로 구분)'),
                _buildTextField(_controllers.format, '포맷 (쉼표로 구분)'),
                _buildTextField(_controllers.genre, '장르 (쉼표로 구분)'),
                _buildTextField(_controllers.style, '스타일 (쉼표로 구분)'),
              ]),
              _buildSection('옵션', [
                _buildSwitchTile('한정판', viewModel.currentAlbum!.isLimited, (v) => viewModel.updateCurrentAlbum(viewModel.currentAlbum!.copyWith(isLimited: v))),
                _buildSwitchTile('특이사항', viewModel.currentAlbum!.isSpecial, (v) => viewModel.updateCurrentAlbum(viewModel.currentAlbum!.copyWith(isSpecial: v))),
                _buildSwitchTile('위시리스트', viewModel.currentAlbum!.isWishlist, (v) => viewModel.updateCurrentAlbum(viewModel.currentAlbum!.copyWith(isWishlist: v))),
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
                          onPressed: () => viewModel.addNewDisc(),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('트랙 추가'),
                          onPressed: () => viewModel.addTrack(Track(title: '')),
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
            delegate: ReorderableSliverChildBuilderDelegate(
              (context, index) {
                final track = viewModel.currentAlbum!.tracks[index];
                return _TrackListItemWidget(
                  key: ValueKey(track.id), // Use stable, unique ID for the key
                  track: track,
                  viewModel: viewModel,
                  index: index,
                );
              },
              childCount: viewModel.currentAlbum!.tracks.length,
            ),
            onReorder: (oldIndex, newIndex) {
              setState(() {
                // Adjust index when moving an item down the list.
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                viewModel.reorderTracks(oldIndex, newIndex);
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

  Widget _buildTextField(TextEditingController controller, String label, {bool isRequired = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        maxLines: maxLines,
        validator: isRequired ? (value) => value == null || value.isEmpty ? '$label 필드는 필수입니다.' : null : null,
      ),
    );
  }
  
  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }

  // --- Actions ---

  Future<void> _scanBarcode(BuildContext context, AlbumFormViewModel viewModel) async {
    final result = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
    if (result != null && mounted) {
      await viewModel.searchByBarcode(result);
    }
  }

  Future<void> _saveForm(BuildContext context, AlbumFormViewModel viewModel) async {
    if (_formKey.currentState!.validate()) {
      _controllers.commitChanges(viewModel); // Commit final text changes
      await viewModel.saveAlbum(widget.albumToEdit?.id);
      if (mounted && viewModel.errorMessage == null) {
        Navigator.pop(context, true);
      }
    }
  }
  
  Future<void> _showSearchDialog(BuildContext context, AlbumFormViewModel viewModel) async {
    final searchTitleController = TextEditingController(text: _controllers.title.text);
    final searchArtistController = TextEditingController(text: _controllers.artist.text);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Discogs 앨범 검색'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: searchArtistController, decoration: const InputDecoration(labelText: '아티스트 (선택 사항)')),
              const SizedBox(height: 8),
              TextField(controller: searchTitleController, decoration: const InputDecoration(labelText: '앨범 제목'), autofocus: true),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, {'artist': searchArtistController.text, 'title': searchTitleController.text}),
              child: const Text('검색'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      final artist = result['artist']?.trim();
      final title = result['title']?.trim();
      if (title != null && title.isNotEmpty) {
        final searchResults = await viewModel.searchByTitleArtist(artist: artist, title: title);
        if (mounted) _showSearchResultsDialog(context, viewModel, searchResults);
      }
    }
  }

  Future<void> _showSearchResultsDialog(BuildContext context,
      AlbumFormViewModel viewModel, List<dynamic> results) async {
    if (!mounted) return;

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검색 결과가 없습니다.')),
      );
      return;
    }

    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('앨범 검색 결과', style: theme.textTheme.headlineSmall),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 20.0, horizontal: 8),
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
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.0,
                                          value: loadingProgress
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
                                    errorBuilder: (context, error, stackTrace) =>
                                        Icon(
                                      Icons.music_note,
                                      size: 40,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.5),
                                    ),
                                  )
                                : Icon(
                                    Icons.music_note,
                                    size: 40,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
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
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
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
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
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
            )
          ],
        );
      },
    );
  }
}

class _ImagePicker extends StatelessWidget {
  final AlbumFormViewModel viewModel;
  const _ImagePicker({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final album = viewModel.currentAlbum!;
    final theme = Theme.of(context);
    // Unique tag for the Hero animation
    final heroTag = 'album-cover-${album.id}';
    
    return Center(
      child: Hero(
        tag: heroTag,
        child: GestureDetector(
          onTap: () async {
            final imagePath = await viewModel.pickImage();
            if (imagePath != null) {
              viewModel.updateCurrentAlbum(album.copyWith(imagePath: imagePath));
            }
          },
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor, width: 2),
              image: album.imagePath != null && File(album.imagePath!).existsSync()
                  ? DecorationImage(image: FileImage(File(album.imagePath!)), fit: BoxFit.cover)
                  : null,
            ),
            child: (album.imagePath == null || !File(album.imagePath!).existsSync())
                ? Center(child: Icon(Icons.add_a_photo_outlined, size: 40, color: theme.colorScheme.primary))
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

  const _TrackListItemWidget({
    required Key key,
    required this.track,
    required this.viewModel,
    required this.index,
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
      widget.viewModel.updateTrack(widget.index, widget.track.copyWith(title: _titleController.text));
    }
  }

  void _onTitleKrChanged() {
    if (widget.track.titleKr != _titleKrController.text) {
      widget.viewModel.updateTrack(widget.index, widget.track.copyWith(titleKr: _titleKrController.text));
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
          color: theme.colorScheme.secondary.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Icon(Icons.drag_handle),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: '디스크 제목', border: InputBorder.none),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                  onPressed: () => widget.viewModel.removeTrack(widget.index),
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
                        decoration: InputDecoration(labelText: '트랙 $trackNumberInDisc', border: InputBorder.none),
                      ),
                      TextFormField(
                        controller: _titleKrController,
                        decoration: InputDecoration(labelText: '트랙 $trackNumberInDisc (한국어)', border: InputBorder.none),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                  onPressed: () => widget.viewModel.removeTrack(widget.index),
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

  void update(AlbumFormViewModel viewModel) {
    final album = viewModel.currentAlbum;
    if (album == null) return;

    _updateText(title, album.title);
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
    viewModel.updateCurrentAlbum(album.copyWith(
      title: title.text,
      artist: artist.text,
      description: desc.text,
      releaseDate: ReleaseDate.parse(date.text),
      linkUrl: link.text,
      labels: label.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      formats: format.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      genres: genre.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      styles: style.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
    ));
  }

  void _updateText(TextEditingController controller, String text) {
    if (controller.text != text) {
      controller.text = text;
    }
  }

  void dispose() {
    title.dispose();
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
