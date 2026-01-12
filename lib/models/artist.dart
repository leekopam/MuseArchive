import 'package:uuid/uuid.dart';

/// 아티스트 데이터 모델
class Artist {
  // region 필드
  final String id;
  final String name;
  final String? imagePath;
  final List<String> albumIds;
  final List<String> aliases;
  final List<String> groups;
  // endregion

  // region 생성자
  Artist({
    String? id,
    required this.name,
    this.imagePath,
    List<String>? albumIds,
    List<String>? aliases,
    List<String>? groups,
  }) : id = id ?? const Uuid().v4(),
       albumIds = albumIds ?? [],
       aliases = aliases ?? [],
       groups = groups ?? [];
  // endregion

  // region Getter 메서드
  int get albumCount => albumIds.length;
  // endregion

  // region 직렬화
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'albumIds': albumIds,
      'aliases': aliases,
      'groups': groups,
    };
  }

  factory Artist.fromMap(Map<dynamic, dynamic> map) {
    return Artist(
      id: map['id']?.toString(),
      name: map['name'] ?? '',
      imagePath: map['imagePath'],
      albumIds:
          (map['albumIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      aliases:
          (map['aliases'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      groups:
          (map['groups'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
  // endregion

  // region 불변 복사
  Artist copyWith({
    String? id,
    String? name,
    String? imagePath,
    List<String>? albumIds,
    List<String>? aliases,
    List<String>? groups,
  }) {
    return Artist(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      albumIds: albumIds ?? this.albumIds,
      aliases: aliases ?? this.aliases,
      groups: groups ?? this.groups,
    );
  }
  // endregion

  // region 연산자 오버라이드
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Artist && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
  // endregion
}
