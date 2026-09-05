import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final name = 'The Weeknd - Topic';
  try {
    final uri = Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(name)}');
    final response = await http.get(uri);
    print('Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Extract: ${data['extract']}');
    } else {
      print('Body: ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
