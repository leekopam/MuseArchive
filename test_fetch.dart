import 'lib/services/vocadb_service.dart';

void main() async {
  final service = VocadbService();
  try {
    for (int id in [1, 2, 3, 4, 10, 100]) {
      print("Fetching $id...");
      final album = await service.fetchAlbumById(id);
      if (album == null) {
        print("Album $id is null");
      } else {
        print("Album $id: tracks=${album.tracks.length}");
      }
    }
  } catch (e, st) {
    print("Error: $e\n$st");
  }
}
