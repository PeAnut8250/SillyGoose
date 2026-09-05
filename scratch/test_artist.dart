import '../lib/data/api/youtube_service.dart';

void main() async {
  final yt = YoutubeService();
  final artist = await yt.getArtistByName('The Weeknd');
  print('Artist Data: $artist');
}
