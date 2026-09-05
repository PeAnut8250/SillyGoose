import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  
  try {
    // We will search for a playlist first
    final searchResults = await yt.search.searchContent('The Weeknd', filter: TypeFilters.playlist);
    final firstPlaylist = searchResults.whereType<SearchPlaylist>().first;
    print('Found Playlist: ${firstPlaylist.title}, ID: ${firstPlaylist.id.value}');
    
    // Now try to get its videos
    final videos = await yt.playlists.getVideos(firstPlaylist.id.value).toList();
    print('Got ${videos.length} videos from playlist');
  } catch (e) {
    print('Failed: $e');
  }
  
  yt.close();
}
