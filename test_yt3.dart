import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  final search = yt.search;
  
  try {
    final playlists = await search.getPlaylists('The Weeknd');
    for (var p in playlists.take(3)) {
      print('Playlist: ${p.title}');
    }
  } catch (e) {
    print('Failed to getPlaylists: $e');
  }
  
  try {
    final channels = await search.getChannels('The Weeknd');
    for (var p in channels.take(3)) {
      print('Channel: ${p.name}');
    }
  } catch (e) {
    print('Failed to getChannels: $e');
  }
  
  yt.close();
}
