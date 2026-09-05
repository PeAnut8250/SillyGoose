import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final res = await http.post(
    Uri.parse('https://music.youtube.com/youtubei/v1/browse?prettyPrint=false'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20230522.01.00',
        }
      },
      'browseId': 'FEmusic_moods_and_genres'
    }),
  );
  
  if (res.statusCode == 200) {
    final data = jsonDecode(res.body);
    // Print the first item in the first section to inspect it for an image!
    try {
      final tabs = data['contents']['singleColumnBrowseResultsRenderer']['tabs'];
      final content = tabs[0]['tabRenderer']['content']['sectionListRenderer']['contents'];
      final firstGrid = content[0]['gridRenderer'];
      final firstItem = firstGrid['items'][0];
      print(jsonEncode(firstItem));
    } catch(e) {
      print("Error: $e");
    }
  } else {
    print("Failed: ${res.statusCode}");
  }
}
