import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:shimmer/shimmer.dart';
import '../models/album.dart';
import '../models/track.dart';
import '../services/haptic_service.dart';
import '../services/i_album_repository.dart';
import 'detail_screen.dart';

// region 헬퍼 클래스

// 트랙과 부모 앨범에 대한 참조를 보유하는 도우미 클래스
class _SongWithAlbumRef {
  final Track track;
  final Album album;

  _SongWithAlbumRef({required this.track, required this.album});
}

// 동일 곡이 여러 앨범에 수록된 경우를 그룹화하는 도우미 클래스
class _SongGroup {
  final String title;
  final String artistName;
  final String? titleKr;
  final List<_SongWithAlbumRef> entries;

  _SongGroup({
    required this.title,
    required this.artistName,
    this.titleKr,
    required this.entries,
  });

  int get albumCount => entries.length;
  bool get isSingle => entries.length == 1;

  // 대표 앨범 (위시리스트가 아닌 첫 앨범 우선)
  Album get primaryAlbum =>
      entries
          .cast<_SongWithAlbumRef?>()
          .firstWhere((e) => !e!.album.isWishlist, orElse: () => null)
          ?.album ??
      entries.first.album;

  bool get isAllWishlist => entries.every((e) => e.album.isWishlist);
}

// endregion

// region 전체 곡 목록 화면 메인

class AllSongsScreen extends StatefulWidget {
  final IAlbumRepository repository;

  const AllSongsScreen({super.key, required this.repository});

  @override
  State<AllSongsScreen> createState() => _AllSongsScreenState();
}

class _AllSongsScreenState extends State<AllSongsScreen> {
  late final IAlbumRepository _repository;
  final List<_SongWithAlbumRef> _allSongs = [];
  List<_SongGroup> _filteredGroups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _includeWishlist = false;
  final TextEditingController _searchController = TextEditingController();

  // region 라이프사이클
  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    _loadAllSongs();
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
          _filterSongs();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  // endregion

  // region 기능 메서드
  Future<void> _showErrorDialog(String message) async {
    return showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('확인'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // region 데이터 로드
  Future<void> _loadAllSongs() async {
    try {
      final albums = await _repository.getAll();
      _allSongs.clear();
      for (final album in albums) {
        for (final track in album.tracks) {
          if (!track.isHeader) {
            _allSongs.add(_SongWithAlbumRef(track: track, album: album));
          }
        }
      }
      _filterSongs();
    } catch (e) {
      if (mounted) {
        _showErrorDialog('곡 목록을 불러오는 데 실패했습니다.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // endregion

  // region 필터링 및 그룹화
  void _filterSongs() {
    List<_SongWithAlbumRef> filtered;

    if (_searchQuery.isEmpty) {
      filtered = List.from(_allSongs);
    } else {
      final lowerQuery = _searchQuery.toLowerCase();
      final matchedArtists = _repository.getArtistNamesMatching(_searchQuery);

      filtered = _allSongs.where((songRef) {
        final track = songRef.track;
        final album = songRef.album;
        final artistName = album.artist;

        final titleMatch = track.title.toLowerCase().contains(lowerQuery);
        final titleKrMatch =
            track.titleKr?.toLowerCase().contains(lowerQuery) ?? false;
        final artistMatch = artistName.toLowerCase().contains(lowerQuery);
        final aliasMatch = matchedArtists.contains(artistName);

        return titleMatch || titleKrMatch || artistMatch || aliasMatch;
      }).toList();
    }

    // 위시리스트 필터링 (그룹화 전)
    if (!_includeWishlist) {
      filtered = filtered.where((s) => !s.album.isWishlist).toList();
    }

    _filteredGroups = _groupSongs(filtered);
    _filteredGroups.sort((a, b) {
      final artistCompare =
          a.artistName.toLowerCase().compareTo(b.artistName.toLowerCase());
      if (artistCompare != 0) return artistCompare;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
  }

  // 동일 곡(제목+아티스트) 그룹화
  List<_SongGroup> _groupSongs(List<_SongWithAlbumRef> songs) {
    final groupMap = <String, List<_SongWithAlbumRef>>{};
    for (final song in songs) {
      final key =
          '${song.track.title.toLowerCase()}||${song.album.artist.toLowerCase()}';
      groupMap.putIfAbsent(key, () => []).add(song);
    }
    return groupMap.entries.map((entry) {
      final first = entry.value.first;
      return _SongGroup(
        title: first.track.title,
        artistName: first.album.artist,
        titleKr: first.track.titleKr,
        entries: entry.value,
      );
    }).toList();
  }
  // endregion

  // region 곡 액션
  void _showSongActions(_SongWithAlbumRef songRef) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(songRef.track.title),
        message: Text(songRef.album.artist),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('다른 앨범에서 보기'),
            onPressed: () {
              Navigator.pop(context);
              _findAndShowOtherAlbums(songRef);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ),
    );
  }

  void _findAndShowOtherAlbums(_SongWithAlbumRef songRef) {
    final otherAlbums = _findOtherAlbumsForTrack(songRef);

    showCupertinoDialog(
      context: context,
      builder: (context) {
        if (otherAlbums.isEmpty) {
          return CupertinoAlertDialog(
            title: const Text('결과 없음'),
            content: const Text('이 곡이 포함된 다른 앨범을 찾을 수 없습니다.'),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('확인'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          );
        }

        return CupertinoAlertDialog(
          title: Text('"${songRef.track.title}"\n포함된 다른 앨범'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: otherAlbums
                .map(
                  (album) => CupertinoDialogAction(
                    child: Text(album.title),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => DetailScreen(album: album),
                        ),
                      );
                    },
                  ),
                )
                .toList(),
          ),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('닫기'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  List<Album> _findOtherAlbumsForTrack(_SongWithAlbumRef currentSong) {
    final trackTitle = currentSong.track.title.toLowerCase();
    final artistName = currentSong.album.artist.toLowerCase();
    final currentAlbumId = currentSong.album.id;

    final otherSongs = _allSongs.where((songRef) {
      return songRef.track.title.toLowerCase() == trackTitle &&
          songRef.album.artist.toLowerCase() == artistName &&
          songRef.album.id != currentAlbumId;
    }).toList();

    final otherAlbums = <Album>[];
    final albumIds = <String>{};
    for (final songRef in otherSongs) {
      if (albumIds.add(songRef.album.id)) {
        otherAlbums.add(songRef.album);
      }
    }
    return otherAlbums;
  }

  // 그룹화된 곡 탭 시 앨범 선택 시트
  void _showAlbumSelectionSheet(_SongGroup group) {
    HapticService.lightTap();
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(group.title),
        message: Text('${group.artistName} \u00b7 ${group.albumCount}개 앨범에 수록'),
        actions: group.entries
            .map(
              (entry) => CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => DetailScreen(album: entry.album),
                    ),
                  );
                  if (result == true && mounted) await _loadAllSongs();
                },
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: _buildAlbumCover(entry.album, 30),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.album.title,
                        style: TextStyle(
                          color: CupertinoColors.label.resolveFrom(context),
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ),
    );
  }
  // endregion

  // region 메인 UI
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('모든 곡'),
        backgroundColor: CupertinoColors.systemBackground,
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: '곡 또는 아티스트 검색...',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '위시리스트 곡 포함',
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.label.resolveFrom(context),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoSwitch(
                    value: _includeWishlist,
                    activeTrackColor: CupertinoColors.systemPink,
                    onChanged: (value) {
                      HapticService.toggle();
                      setState(() {
                        _includeWishlist = value;
                        _filterSongs();
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: CustomScrollView(slivers: [_buildSongList()])),
          ],
        ),
      ),
    );
  }

  Widget _buildSongList() {
    if (_isLoading) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const _SongListItemSkeleton(),
          childCount: 10,
        ),
      );
    }

    if (_filteredGroups.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.music_albums_fill,
                  color: CupertinoColors.systemGrey.resolveFrom(context),
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '표시할 곡이 없습니다',
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFamily: '.SF Pro Text',
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '앨범을 추가하여 보관함을 채워보세요.',
                style: TextStyle(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  fontSize: 15,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverSafeArea(
      top: false,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final group = _filteredGroups[index];

          if (group.isSingle) {
            // 단일 앨범 곡: 기존 동작 (바로 DetailScreen 이동)
            final songRef = group.entries.first;
            return _SongListItem(
              songRef: songRef,
              onTap: () async {
                HapticService.lightTap();
                final result = await Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => DetailScreen(album: songRef.album),
                  ),
                );
                if (result == true && mounted) {
                  await _loadAllSongs();
                }
              },
              onMoreTap: () {
                HapticService.lightTap();
                _showSongActions(songRef);
              },
            );
          }

          // 복수 앨범 곡: 그룹화된 항목
          return _GroupedSongListItem(
            group: group,
            onTap: () => _showAlbumSelectionSheet(group),
          );
        }, childCount: _filteredGroups.length),
      ),
    );
  }
  // endregion
}

// endregion

// region 앨범 커버 빌더 (공용)
Widget _buildAlbumCover(Album album, double size) {
  final imagePath = album.imagePath;
  if (imagePath != null &&
      imagePath.isNotEmpty &&
      File(imagePath).existsSync()) {
    return Image.file(File(imagePath), fit: BoxFit.cover);
  }
  return Container(
    width: size,
    height: size,
    color: CupertinoColors.systemGrey5,
    child: Icon(
      CupertinoIcons.music_note,
      color: CupertinoColors.systemGrey,
      size: size * 0.48,
    ),
  );
}
// endregion

// region 내부 위젯

// 단일 앨범 곡 항목
class _SongListItem extends StatelessWidget {
  final _SongWithAlbumRef songRef;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const _SongListItem({
    required this.songRef,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final album = songRef.album;
    final track = songRef.track;
    final imagePath = album.imagePath;

    return CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child:
                        imagePath != null &&
                            imagePath.isNotEmpty &&
                            File(imagePath).existsSync()
                        ? ColorFiltered(
                            colorFilter: album.isWishlist
                                ? const ColorFilter.mode(
                                    CupertinoColors.systemGrey,
                                    BlendMode.saturation,
                                  )
                                : const ColorFilter.mode(
                                    CupertinoColors.transparent,
                                    BlendMode.multiply,
                                  ),
                            child: Opacity(
                              opacity: album.isWishlist ? 0.7 : 1.0,
                              child: Image.file(
                                File(imagePath),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : Container(
                            color: CupertinoColors.systemGrey5,
                            child: const Icon(
                              CupertinoIcons.music_note,
                              color: CupertinoColors.systemGrey,
                              size: 24,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: TextStyle(
                          color: album.isWishlist
                              ? CupertinoColors.label
                                    .resolveFrom(context)
                                    .withValues(alpha: 0.6)
                              : CupertinoColors.label.resolveFrom(context),
                          fontSize: 17,
                          fontWeight: album.isWishlist
                              ? FontWeight.normal
                              : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        album.artist,
                        style: TextStyle(
                          color: album.isWishlist
                              ? CupertinoColors.secondaryLabel
                                    .resolveFrom(context)
                                    .withValues(alpha: 0.5)
                              : CupertinoColors.secondaryLabel.resolveFrom(
                                  context,
                                ),
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  onPressed: onMoreTap,
                  padding: const EdgeInsets.all(12.0),
                  child: const Icon(
                    CupertinoIcons.ellipsis,
                    color: CupertinoColors.systemGrey2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 82.0, right: 16.0),
            child: Container(
              height: 1.0 / MediaQuery.devicePixelRatioOf(context),
              color: CupertinoColors.separator.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

// 복수 앨범 곡 그룹 항목
class _GroupedSongListItem extends StatelessWidget {
  final _SongGroup group;
  final VoidCallback onTap;

  const _GroupedSongListItem({
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                _buildStackedCovers(context),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        style: TextStyle(
                          color: group.isAllWishlist
                              ? CupertinoColors.label
                                    .resolveFrom(context)
                                    .withValues(alpha: 0.6)
                              : CupertinoColors.label.resolveFrom(context),
                          fontSize: 17,
                          fontWeight: group.isAllWishlist
                              ? FontWeight.normal
                              : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${group.artistName} \u00b7 ${group.albumCount}개 앨범 수록',
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 앨범 수 배지
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${group.albumCount}',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel
                          .resolveFrom(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 82.0, right: 16.0),
            child: Container(
              height: 1.0 / MediaQuery.devicePixelRatioOf(context),
              color: CupertinoColors.separator.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  // 앨범 커버 최대 3장 겹쳐서 표시
  Widget _buildStackedCovers(BuildContext context) {
    final albums = group.entries.map((e) => e.album).toList();
    final displayCount = albums.length.clamp(1, 3);
    const double itemSize = 40;
    const double offset = 5.0;

    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        children: List.generate(displayCount, (i) {
          // 뒤에서부터 쌓기 (첫 앨범이 맨 위)
          final reverseIndex = displayCount - 1 - i;
          final album = albums[reverseIndex];
          return Positioned(
            left: reverseIndex * offset,
            top: reverseIndex * offset,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: CupertinoColors.systemBackground.resolveFrom(context),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha: 0.08),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SizedBox(
                  width: itemSize,
                  height: itemSize,
                  child: _buildAlbumCover(album, itemSize),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// 로딩 스켈레톤
class _SongListItemSkeleton extends StatelessWidget {
  const _SongListItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: CupertinoColors.systemGrey4,
      highlightColor: CupertinoColors.systemGrey5,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 16.0,
                        color: CupertinoColors.white,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.4,
                        height: 14.0,
                        color: CupertinoColors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 82.0, right: 16.0),
            child: Container(
              height: 1.0 / MediaQuery.devicePixelRatioOf(context),
              color: CupertinoColors.separator.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

// endregion
