import 'dart:convert';
import 'dart:io';
import '../settings_service.dart';

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

    final cleanTitle = _cleanTitle(title);
    final cleanArtist = _cleanArtist(artist);
    final activeSources = SettingsService().activeLyricsSources;
    final order = SettingsService().lyricsSourceOrder;

    final sequence = order.where((s) => activeSources.contains(s)).toList();

    for (var source in sequence) {
      try {
        final result = await _fetchFromSource(source, cleanArtist, cleanTitle);
        if (result != null && result.isNotEmpty) {
          _lyricsCache[cacheKey] = result;
          return result;
        }
      } catch (e) {
        // Log fallback
      }
    }

    // Cache empty list to avoid re-fetching failed lyrics during session
    _lyricsCache[cacheKey] = [];
    return null;
  }

  Future<List<LyricLine>?> _fetchFromSource(String source, String artist, String title) async {
    switch (source) {
      case 'LRCLIB':
      case 'LyricsPlus':
      case 'PaxSenix':
      case 'BetterLyrics':
      case 'SimpMusic':
        return await _fetchLrcLib(artist, title);
      case 'KuGou':
        return await _fetchKuGou(artist, title);
      case 'Musixmatch':
        return await _fetchMusixmatch(artist, title);
      case 'Genius':
        return await _fetchGenius(artist, title);
      default:
        return await _fetchLrcLib(artist, title);
    }
  }

  Future<List<LyricLine>?> _fetchLrcLib(String artist, String title) async {
    final client = HttpClient();
    
    // 1. Try exact match
    try {
      final uri = Uri.https('lrclib.net', '/api/get', {
        'artist_name': artist,
        'track_name': title,
      });
      final request = await client.getUrl(uri);
      request.headers.add('User-Agent', 'SillyGooseMusic/1.0.0');
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody);
        if (json['syncedLyrics'] != null && json['syncedLyrics'].toString().isNotEmpty) {
          return _parseLrc(json['syncedLyrics']);
        }
      }
    } catch (_) {}

    // 2. Fuzzy search fallback
    try {
      final searchUri = Uri.https('lrclib.net', '/api/search', {
        'q': '$title $artist',
      });
      final req = await client.getUrl(searchUri);
      req.headers.add('User-Agent', 'SillyGooseMusic/1.0.0');
      final resp = await req.close();

      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final List<dynamic> hits = jsonDecode(body);
        for (var item in hits) {
          if (item['syncedLyrics'] != null && item['syncedLyrics'].toString().isNotEmpty) {
            return _parseLrc(item['syncedLyrics']);
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Future<List<LyricLine>?> _fetchKuGou(String artist, String title) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse('http://kugou.com/search?keyword=${Uri.encodeComponent('$artist $title')}');
      final req = await client.getUrl(uri);
      final resp = await req.close();
      await resp.drain();
    } catch (_) {}
    return null;
  }

  Future<List<LyricLine>?> _fetchMusixmatch(String artist, String title) async {
    return null;
  }

  Future<List<LyricLine>?> _fetchGenius(String artist, String title) async {
    return null;
  }

  String _cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'\((?:from|feat\.?|official|lyrical|video|audio|remix)[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'\s*\|.*?$'), '')
        .trim();
  }

  String _cleanArtist(String artist) {
    return artist.replaceAll(' - Topic', '').trim();
  }

  List<LyricLine> _parseLrc(String lrc) {
    final List<LyricLine> lines = [];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.*)');

    for (var line in lrc.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
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
