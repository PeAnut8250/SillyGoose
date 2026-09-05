import 'dart:convert';
import 'dart:io';

class LyricLine {
  final Duration time;
  final String text;

  LyricLine(this.time, this.text);
}

class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  final Map<String, List<LyricLine>> _lyricsCache = {};

  Future<List<LyricLine>?> getLyrics(String artist, String title) async {
    final cacheKey = '$artist-$title';
    if (_lyricsCache.containsKey(cacheKey)) {
      return _lyricsCache[cacheKey];
    }

    try {
      final uri = Uri.https('lrclib.net', '/api/get', {
        'artist_name': artist,
        'track_name': title,
      });

      final client = HttpClient();
      final request = await client.getUrl(uri);
      // LRCLIB requires a user-agent
      request.headers.add('User-Agent', 'JustAMusicApp/1.0.0');
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody);

        if (json['syncedLyrics'] != null) {
          final lyrics = _parseLrc(json['syncedLyrics']);
          _lyricsCache[cacheKey] = lyrics;
          return lyrics;
        }
      }
    } catch (e) {
      print('Error fetching lyrics: $e');
    }

    // Cache empty list to avoid re-fetching failed lyrics during the session
    _lyricsCache[cacheKey] = [];
    return null;
  }

  List<LyricLine> _parseLrc(String lrc) {
    final List<LyricLine> lines = [];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.*)');

    for (var line in lrc.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        // Sometimes milliseconds are 2 digits (e.g. 50 = 500ms) or 3 digits
        String msStr = match.group(3)!;
        if (msStr.length == 2) msStr += '0';
        final milliseconds = int.parse(msStr);

        final text = match.group(4)!.trim();
        
        if (text.isNotEmpty) {
          final time = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          );
          lines.add(LyricLine(time, text));
        }
      }
    }

    return lines;
  }
}
