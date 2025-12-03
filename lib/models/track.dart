import 'package:uuid/uuid.dart';

class Track {
  final String id;
  final String title;
  final String? titleKr;
  final bool isHeader;

  Track({
    String? id,
    required this.title,
    this.titleKr,
    this.isHeader = false,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'titleKr': titleKr,
      'isHeader': isHeader,
    };
  }

  factory Track.fromMap(Map<String, dynamic> map) {
    return Track(
      id: map['id'],
      title: map['title'] ?? '',
      titleKr: map['titleKr'],
      isHeader: map['isHeader'] ?? false,
    );
  }

  Track copyWith({
    String? id,
    String? title,
    String? titleKr,
    bool? isHeader,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      titleKr: titleKr ?? this.titleKr,
      isHeader: isHeader ?? this.isHeader,
    );
  }
}
