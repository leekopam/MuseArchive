import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:shimmer/shimmer.dart';
import '../models/album.dart';
import '../models/track.dart';
import '../services/album_repository.dart';
import 'detail_screen.dart';

// region 전체 곡 목록 화면 메인
// region 헬퍼 클래스
// 트랙과 부모 앨범에 대한 참조를 보유하는 도우미 클래스
class _SongWithAlbumRef {
  final Track track;
  final Album album;

  _SongWithAlbumRef({required this.track, required this.album});
}
// endregion

class AllSongsScreen extends StatefulWidget {
  const AllSongsScreen({super.key});

  @override
  State<AllSongsScreen> createState() => _AllSongsScreenState();
}

class _AllSongsScreenState extends State<AllSongsScreen> {
  final AlbumRepository _repository = AlbumRepository();
  final List<_SongWithAlbumRef> _allSongs = [];
  List<_SongWithAlbumRef> _filteredSongs = [];
  bool _isLoading = true; // 로딩 true로 시작
  String _searchQuery = '';
  bool _includeWishlist = false; // 위시리스트 포함 여부 (기본값: false)
  final TextEditingController _searchController = TextEditingController();

  // region 라이프사이클
  @override
  void initState() {
    super.initState();
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
    // 처음부터 true이면 로딩을 true로 설정할 필요가 없습니다.
    // 한 번만 로드하는 경우. 당겨서 새로고침이 추가되면 이 로직이 변경됩니다.
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

  void _filterSongs() {
    if (_searchQuery.isEmpty) {
      _filteredSongs = List.from(_allSongs);
    } else {
      final lowerQuery = _searchQuery.toLowerCase();
      // 별명 포함한 아티스트 검색 결과 가져오기
      final matchedArtists = _repository.getArtistNamesMatching(_searchQuery);

      _filteredSongs = _allSongs.where((songRef) {
        final track = songRef.track;
        final album = songRef.album;

        // 위시리스트 필터링: _includeWishlist가 false이면 위시리스트 앨범의 곡은 제외
        if (!_includeWishlist && album.isWishlist) {
          return false;
        }

        final artistName = album.artist;

        // 1. 트랙 제목 검색
        final titleMatch = track.title.toLowerCase().contains(lowerQuery);
        // 2. 트랙 한글 제목 검색
        final titleKrMatch =
            track.titleKr?.toLowerCase().contains(lowerQuery) ?? false;
        // 3. 아티스트 이름 직접 검색
        final artistMatch = artistName.toLowerCase().contains(lowerQuery);
        // 4. 아티스트 별명 매칭 (Repository 결과 활용)
        final aliasMatch = matchedArtists.contains(artistName);

        return titleMatch || titleKrMatch || artistMatch || aliasMatch;
      }).toList();
    }
    _filteredSongs.sort((a, b) {
      final artistCompare = a.album.artist.toLowerCase().compareTo(
        b.album.artist.toLowerCase(),
      );
      if (artistCompare != 0) return artistCompare;
      return a.track.title.toLowerCase().compareTo(b.track.title.toLowerCase());
    });
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
                      Navigator.pop(context); // 대화 상자 닫기
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
          onPressed: () {
            Navigator.pop(context);
          },
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
        backgroundColor: CupertinoColors.systemBackground, // 스크롤 시 색상 변경 방지
        border: null, // 경계선 제거 (깔끔한 UI)
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
                    activeColor: CupertinoColors.systemPink,
                    onChanged: (value) {
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

    if (_filteredSongs.isEmpty) {
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
                  decoration: TextDecoration.none, // 노란색 밑줄 수정
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '앨범을 추가하여 보관함을 채워보세요.',
                style: TextStyle(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  fontSize: 15,
                  decoration: TextDecoration.none, // 노란색 밑줄 수정
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
          final songRef = _filteredSongs[index];
          return _SongListItem(
            songRef: songRef,
            onTap: () async {
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
            onMoreTap: () => _showSongActions(songRef),
          );
        }, childCount: _filteredSongs.length),
      ),
    );
  }
}
// endregion

// region 내부 위젯
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
