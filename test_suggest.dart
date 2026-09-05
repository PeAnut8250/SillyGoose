import 'dart:convert';
import 'dart:io';
void main() async {
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse('https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=likne'));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  print('FIREFOX YT: $body');
  
  final req2 = await client.getUrl(Uri.parse('https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=likne%20music'));
  final res2 = await req2.close();
  final body2 = await res2.transform(utf8.decoder).join();
  print('FIREFOX MUSIC: $body2');
}
