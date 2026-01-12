import 'package:uuid/uuid.dart';

/// 트랙 데이터 모델
class Track {
  // region 필드
  final String id;
  final String title;
  final String? titleKr;
  final bool isHeader; // 디스크 헤더 여부
  // endregion

  // region 생성자
  Track({String? id, required this.title, this.titleKr, this.isHeader = false})
    : id = id ?? const Uuid().v4();
  // endregion

  // region 직렬화
  Map<String, dynamic> toMap() {
    return {'id': id, 'title': title, 'titleKr': titleKr, 'isHeader': isHeader};
  }

  factory Track.fromMap(Map<String, dynamic> map) {
    return Track(
      id: map['id'],
      title: map['title'] ?? '',
      titleKr: map['titleKr'],
      isHeader: map['isHeader'] ?? false,
    );
  }
  // endregion

  // region 불변 복사
  Track copyWith({String? id, String? title, String? titleKr, bool? isHeader}) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      titleKr: titleKr ?? this.titleKr,
      isHeader: isHeader ?? this.isHeader,
    );
  }

  // endregion
}
