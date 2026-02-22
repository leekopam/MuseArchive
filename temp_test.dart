import 'lib/services/vocadb_service.dart';

void main() async {
  final service = VocadbService();
  final album = await service.fetchAlbumById(1);
  if (album == null) {
    print("Album is null");
  } else {
    print("Tracks count: ${album.tracks.length}");
    for (var t in album.tracks) {
      print("${t.isHeader ? 'HEADER: ' : 'TRACK: '}${t.title}");
    }
  }
}
