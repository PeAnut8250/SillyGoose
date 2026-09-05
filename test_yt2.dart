import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'dart:mirrors';

void main() async {
  final yt = YoutubeExplode();
  final search = yt.search;
  
  try {
    final playlists = await search.search('The Weeknd', filter: SearchFilter.playlist);
    for (var p in playlists.take(3)) {
      print('Playlist: ${p.title}');
    }
  } catch (e) {
    print('Failed to search playlist: $e');
  }
  
  try {
    final searchLists = await search.search('The Weeknd');
    for (var s in searchLists.take(5)) {
      print('Default result type: ${s.runtimeType}');
    }
  } catch (e) {
    print('Failed default search: $e');
  }
  
  yt.close();
}
