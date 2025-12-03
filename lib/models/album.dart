import 'package:uuid/uuid.dart';
import 'track.dart';
import 'value_objects/release_date.dart';

class Album {
  final String id;
  final String title;
  final String artist;
  final String description;
  final List<String> labels;
  final String? imagePath;
  final List<String> formats;
  final ReleaseDate releaseDate;
  final List<String> genres;
  final List<String> styles;
  final String? linkUrl;
  final List<Track> tracks;
  final bool isLimited;
  final bool isSpecial;
  final bool isWishlist;

  Album({
    String? id,
    required this.title,
    required this.artist,
    this.description = '',
    List<String>? labels,
    this.imagePath,
    List<String>? formats,
    ReleaseDate? releaseDate,
    List<String>? genres,
    List<String>? styles,
    this.linkUrl,
    List<Track>? tracks,
    this.isLimited = false,
    this.isSpecial = false,
    this.isWishlist = false,
  })  : id = id ?? const Uuid().v4(),
        labels = labels ?? [],
        formats = formats ?? [],
        releaseDate = releaseDate ?? const ReleaseDate(null),
        genres = genres ?? [],
        styles = styles ?? [],
        tracks = tracks ?? [];

  String get label => labels.join(', ');
  String get format => formats.join(', ');
  String get genre => genres.join(', ');
  String get style => styles.join(', ');
  String get releaseDateString => releaseDate.format();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'description': description,
      'labels': labels,
      'imagePath': imagePath,
      'formats': formats,
      'releaseDate': releaseDate.format(),
      'genres': genres,
      'styles': styles,
      'linkUrl': linkUrl,
      'tracks': tracks.map((t) => t.toMap()).toList(),
      'isLimited': isLimited,
      'isSpecial': isSpecial,
      'isWishlist': isWishlist,
    };
  }

  factory Album.fromMap(Map<dynamic, dynamic> map) {
    List<Track> safeTracks = [];
    if (map['tracks'] != null) {
      try {
        safeTracks = (map['tracks'] as List)
            .map((e) => Track.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (e) {
        // ignore: avoid_print
        print("트랙 불러오기 오류: $e");
      }
    }

    return Album(
      id: map['id']?.toString(),
      title: map['title'] ?? '',
      artist: map['artist'] ?? '',
      description: map['description'] ?? '',
      labels: List<String>.from(map['labels'] ?? []),
      imagePath: map['imagePath'],
      formats: List<String>.from(map['formats'] ?? []),
      releaseDate: ReleaseDate.parse(map['releaseDate'] ?? ''),
      genres: List<String>.from(map['genres'] ?? []),
      styles: List<String>.from(map['styles'] ?? []),
      linkUrl: map['linkUrl'],
      tracks: safeTracks,
      isLimited: map['isLimited'] ?? false,
      isSpecial: map['isSpecial'] ?? false,
      isWishlist: map['isWishlist'] ?? false,
    );
  }

  Album copyWith({
    String? id,
    String? title,
    String? artist,
    String? description,
    List<String>? labels,
    String? imagePath,
    List<String>? formats,
    ReleaseDate? releaseDate,
    List<String>? genres,
    List<String>? styles,
    String? linkUrl,
    List<Track>? tracks,
    bool? isLimited,
    bool? isSpecial,
    bool? isWishlist,
  }) {
    return Album(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      description: description ?? this.description,
      labels: labels ?? this.labels,
      imagePath: imagePath ?? this.imagePath,
      formats: formats ?? this.formats,
      releaseDate: releaseDate ?? this.releaseDate,
      genres: genres ?? this.genres,
      styles: styles ?? this.styles,
      linkUrl: linkUrl ?? this.linkUrl,
      tracks: tracks ?? this.tracks,
      isLimited: isLimited ?? this.isLimited,
      isSpecial: isSpecial ?? this.isSpecial,
      isWishlist: isWishlist ?? this.isWishlist,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Album && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
