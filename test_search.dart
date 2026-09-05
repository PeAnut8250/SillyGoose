import 'package:youtube_explode_dart/youtube_explode_dart.dart';
void main() async {
  final yt = YoutubeExplode();
  final suggestions = await yt.search.getQuerySuggestions('linkn');
  print(suggestions);
  yt.close();
}
