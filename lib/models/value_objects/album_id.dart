import 'package:uuid/uuid.dart';

class AlbumId {
  final String value;

  AlbumId._(this.value);

  factory AlbumId.generate() => AlbumId._(const Uuid().v4());
  
  factory AlbumId.fromString(String id) => AlbumId._(id);

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AlbumId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}
