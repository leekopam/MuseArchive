import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final response = await http.get(
    Uri.parse('https://vocadb.net/api/albums/1?fields=Tracks'),
  );
  final data = jsonDecode(response.body);

  List<dynamic> trackList = [];
  if (data['tracks'] != null) {
    trackList = (data['tracks'] as List);

    // discNumber 단위로 정렬
    trackList.sort((a, b) {
      int discA = a['discNumber'] ?? 1;
      int discB = b['discNumber'] ?? 1;
      if (discA != discB) return discA.compareTo(discB);
      int trackA = a['trackNumber'] ?? 0;
      int trackB = b['trackNumber'] ?? 0;
      return trackA.compareTo(trackB);
    });

    int currentDisc = -1;
    for (var track in trackList) {
      int discNum = track['discNumber'] ?? 1;
      if (currentDisc != -1 && discNum != currentDisc) {
        print("Header: Disc $discNum");
      } else if (currentDisc == -1 && discNum > 1) {
        print("Header: Disc $discNum");
      }
      currentDisc = discNum;

      print("Track: ${track['name'] ?? ''}");
    }
  } else {
    print("No tracks found");
  }
}
