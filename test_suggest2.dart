import 'dart:convert';
import 'dart:io';
void main() async {
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse('https://suggestqueries.google.com/complete/search?client=youtube-music&ds=yt&q=likne'));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  print('YT MUSIC: $body');
}
