import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  final channelId = ChannelId('UC4mN-eIebt9sXlYvW1i8pLg'); // Some channel
  try {
    final about = await yt.channels.getAboutPage(channelId);
    print('Description: ${about.description}');
  } catch (e) {
    print('About Error: $e');
  }
  
  try {
    final channel = await yt.channels.get(channelId);
    print('Channel title: ${channel.title}');
    print('Subscribers: ${channel.subscribersCount}');
  } catch (e) {
    print('Channel error: $e');
  }
  
  yt.close();
}
