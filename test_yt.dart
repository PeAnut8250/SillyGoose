import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  final results = await yt.search.search('The Weeknd');
  
  for (var res in results.take(10)) {
    print('Type: ${res.runtimeType}, Title: ${res.title}');
    if (res is SearchPlaylist) {
      print('  Playlist ID: ${res.id.value}, Author: ${res.author}, VideoCount: ${res.videoCount}');
    } else if (res is SearchChannel) {
      print('  Channel ID: ${res.id.value}, Name: ${res.name}');
    }
  }
  
  yt.close();
}
