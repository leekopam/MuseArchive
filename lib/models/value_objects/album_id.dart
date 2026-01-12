import 'package:uuid/uuid.dart';

/// 앨범 ID 값 객체
class AlbumId {
  // region 필드
  final String value;
  //endregion

  // endregion

  // region 생성자
  AlbumId._(this.value);

  /// 새 UUID 생성
  factory AlbumId.generate() => AlbumId._(const Uuid().v4());

  /// 문자열에서 생성
  factory AlbumId.fromString(String id) => AlbumId._(id);
  //endregion

  // endregion

  // region 메서드
  @override
  String toString() => value;
  //endregion

  // endregion

  // region 연산자 오버라이드
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AlbumId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
  //endregion
}
