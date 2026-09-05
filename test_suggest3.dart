import 'dart:convert';
import 'dart:io';
void main() async {
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse('https://itunes.apple.com/search?term=likne&entity=song&limit=7'));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  print('ITUNES: $body');
}
