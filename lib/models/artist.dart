import 'package:uuid/uuid.dart';

class Artist {
  final String id;
  final String name;
  final List<String> albumIds;

  Artist({
    String? id,
    required this.name,
    List<String>? albumIds,
  })  : id = id ?? const Uuid().v4(),
        albumIds = albumIds ?? [];

  int get albumCount => albumIds.length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'albumIds': albumIds,
    };
  }

  factory Artist.fromMap(Map<dynamic, dynamic> map) {
    return Artist(
      id: map['id']?.toString(),
      name: map['name'] ?? '',
      albumIds: (map['albumIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Artist copyWith({
    String? id,
    String? name,
    List<String>? albumIds,
  }) {
    return Artist(
      id: id ?? this.id,
      name: name ?? this.name,
      albumIds: albumIds ?? this.albumIds,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Artist && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
