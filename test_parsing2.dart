import 'dart:convert';
import 'dart:io';

void main() async {
  final content = await File('temp_album_utf8.json').readAsString();
  final data = jsonDecode(content);

  try {
    List<dynamic> tracks = [];
    if (data['tracks'] != null) {
      final trackList = (data['tracks'] as List);
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
          tracks.add({'header': 'Disc $discNum'});
        } else if (currentDisc == -1 && discNum > 1) {
          tracks.add({'header': 'Disc $discNum'});
        }
        currentDisc = discNum;
        tracks.add({'track': track['name'] ?? ''});
      }
    }

    print("Success. Tracks: ${tracks.length}");
    for (var t in tracks) {
      print(t);
    }
  } catch (e, st) {
    print("Error: $e\n$st");
  }
}
