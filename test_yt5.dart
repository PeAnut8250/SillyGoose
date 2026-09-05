import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  final videos = await yt.search.search('The Weeknd');
  if (videos.isNotEmpty) {
    final channelId = videos.first.channelId;
    print('Channel ID: $channelId');
    final channel = await yt.channels.get(channelId);
    print('Channel Title: ${channel.title}');
    print('Channel Logo: ${channel.logoUrl}');
    print('Channel Banner: ${channel.bannerUrl}');
  }
  yt.close();
}
