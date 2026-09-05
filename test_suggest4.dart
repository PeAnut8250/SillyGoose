import 'dart:convert';
import 'dart:io';
void main() async {
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse('https://itunes.apple.com/search?term=linkin%20p&entity=song&limit=5'));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  final data = jsonDecode(body);
  for (var item in data['results']) {
    print("\ - \");
  }
}
