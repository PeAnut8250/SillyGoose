import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryService extends ChangeNotifier {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;

  late SharedPreferences _prefs;
  bool _initialized = false;
  
  List<Map<String, String>> _history = [];
  List<Map<String, String>> _searchHistory = [];
  
  // Real Data Tracker: Key = songId
  Map<String, Map<String, dynamic>> _statsMap = {};

  List<Map<String, String>> get history => _history;
  List<Map<String, String>> get searchHistory => _searchHistory;
  bool get isInitialized => _initialized;

  // Real Data Stats with Bucket Support
  int getTotalPlays({String bucketKey = 'allTime'}) {
    return _statsMap.values.fold(0, (sum, item) {
      final buckets = item['buckets'] as Map<String, dynamic>?;
      if (buckets == null || !buckets.containsKey(bucketKey)) return sum;
      return sum + ((buckets[bucketKey]['plays'] ?? 0) as int);
    });
  }

  int getTotalMinutesListened({String bucketKey = 'allTime'}) {
    return (_statsMap.values.fold(0, (sum, item) {
      final buckets = item['buckets'] as Map<String, dynamic>?;
      if (buckets == null || !buckets.containsKey(bucketKey)) return sum;
      return sum + ((buckets[bucketKey]['playedMs'] ?? 0) as int);
    }) / 60000).floor();
  }

  int getTotalUniqueSongs({String bucketKey = 'allTime'}) {
    return _statsMap.values.where((item) {
      final buckets = item['buckets'] as Map<String, dynamic>?;
      if (buckets == null || !buckets.containsKey(bucketKey)) return false;
      return ((buckets[bucketKey]['playedMs'] ?? 0) as int) > 0 || ((buckets[bucketKey]['plays'] ?? 0) as int) > 0;
    }).length;
  }

  int getTotalUniqueArtists({String bucketKey = 'allTime'}) {
    return _statsMap.values.where((item) {
      final buckets = item['buckets'] as Map<String, dynamic>?;
      if (buckets == null || !buckets.containsKey(bucketKey)) return false;
      return ((buckets[bucketKey]['playedMs'] ?? 0) as int) > 0 || ((buckets[bucketKey]['plays'] ?? 0) as int) > 0;
    }).map((e) => e['artist'] as String?).where((e) => e != null).toSet().length;
  }

  List<Map<String, dynamic>> getTopSongs({String bucketKey = 'allTime'}) {
    final list = _statsMap.values.where((item) {
      final buckets = item['buckets'] as Map<String, dynamic>?;
      return buckets != null && buckets.containsKey(bucketKey);
    }).toList();
    
    list.sort((a, b) {
      final bucketsA = a['buckets'] as Map<String, dynamic>;
      final bucketsB = b['buckets'] as Map<String, dynamic>;
      final msA = bucketsA[bucketKey]['playedMs'] as int? ?? 0;
      final msB = bucketsB[bucketKey]['playedMs'] as int? ?? 0;
      if (msB != msA) return msB.compareTo(msA);
      return (bucketsB[bucketKey]['plays'] as int? ?? 0).compareTo(bucketsA[bucketKey]['plays'] as int? ?? 0);
    });
    
    return list.map((e) {
      final buckets = e['buckets'] as Map<String, dynamic>;
      return {
        'id': e['id'],
        'title': e['title'],
        'artist': e['artist'],
        'imageUrl': e['imageUrl'],
        'plays': ((buckets[bucketKey]['playedMs'] as int? ?? 0) / 60000).floor(),
      };
    }).toList();
  }

  String _primaryArtist(String credit) {
    var c = credit;
    if (c.endsWith(' - Topic')) c = c.replaceAll(' - Topic', '');
    final regex = RegExp(r'\s*,\s*|\s+&\s+|\s+x\s+|\s+feat\.?\s+|\s+ft\.?\s+|\s+featuring\s+', caseSensitive: false);
    final parts = c.split(regex);
    if (parts.isNotEmpty && parts.first.trim().isNotEmpty) {
      return parts.first.trim();
    }
    return c.trim();
  }

  List<Map<String, dynamic>> getTopArtists({String bucketKey = 'allTime'}) {
    final map = <String, Map<String, dynamic>>{};
    for (var track in _statsMap.values) {
      final buckets = track['buckets'] as Map<String, dynamic>?;
      if (buckets == null || !buckets.containsKey(bucketKey)) continue;

      final rawArtist = (track['artist'] ?? 'Unknown Artist') as String;
      final artist = _primaryArtist(rawArtist);
      
      if (!map.containsKey(artist)) {
        map[artist] = {
          'name': artist,
          'plays': 0,
          'playedMs': 0,
          'imageUrl': track['imageUrl'],
        };
      }
      map[artist]!['plays'] = (map[artist]!['plays'] as int) + (buckets[bucketKey]['plays'] as int? ?? 0);
      map[artist]!['playedMs'] = (map[artist]!['playedMs'] as int) + (buckets[bucketKey]['playedMs'] as int? ?? 0);
      
      if (map[artist]!['imageUrl'] == null || (map[artist]!['imageUrl'] as String).isEmpty) {
        map[artist]!['imageUrl'] = track['imageUrl'];
      }
    }
    
    final list = map.values.map((e) => {
      'name': e['name'],
      'plays': e['plays'],
      'minutes': ((e['playedMs'] as int) / 60000).floor(),
      'imageUrl': e['imageUrl'],
    }).toList();
    
    list.sort((a, b) {
      final minA = a['minutes'] as int? ?? 0;
      final minB = b['minutes'] as int? ?? 0;
      if (minB != minA) return minB.compareTo(minA);
      return (b['plays'] as int? ?? 0).compareTo(a['plays'] as int? ?? 0);
    });
    return list;
  }

  HistoryService._internal();

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    
    final historyJsonList = _prefs.getStringList('listening_history');
    if (historyJsonList != null) {
      _history = historyJsonList.map((jsonStr) {
        return Map<String, String>.from(json.decode(jsonStr));
      }).toList();
    }
    
    final searchJsonList = _prefs.getStringList('search_history');
    if (searchJsonList != null) {
      _searchHistory = searchJsonList.map((jsonStr) {
        return Map<String, String>.from(json.decode(jsonStr));
      }).toList();
    }

    final statsJsonStr = _prefs.getString('listening_stats');
    if (statsJsonStr != null) {
      try {
        final decoded = json.decode(statsJsonStr) as Map<String, dynamic>;
        _statsMap = decoded.map((key, value) {
          final item = Map<String, dynamic>.from(value);
          // Migration from old flat format to bucketed format
          if (!item.containsKey('buckets')) {
            final legacyPlays = item['plays'] ?? 0;
            final legacyMs = item['playedMs'] ?? 0;
            
            final now = DateTime.now();
            final currentYear = '${now.year}';
            final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
            
            item['buckets'] = <String, dynamic>{
              'allTime': <String, dynamic>{ 'plays': legacyPlays, 'playedMs': legacyMs },
              currentYear: <String, dynamic>{ 'plays': legacyPlays, 'playedMs': legacyMs },
              currentMonth: <String, dynamic>{ 'plays': legacyPlays, 'playedMs': legacyMs },
            };
            item.remove('plays');
            item.remove('playedMs');
          }
          return MapEntry(key, item);
        });
      } catch (e) {
        print('Error parsing stats: $e');
        _statsMap = {};
      }
    }
    
    _initialized = true;
    notifyListeners();
  }

  void recordPlayTime(Map<String, String> track, int playedMs, bool countsAsPlay) {
    if (!_initialized) return;
    final id = track['id'];
    if (id == null) return;

    if (!_statsMap.containsKey(id)) {
      _statsMap[id] = {
        'id': id,
        'title': track['title'],
        'artist': track['subtitle'],
        'imageUrl': track['imageUrl'],
        'buckets': <String, dynamic>{},
        'lastPlayed': 0,
      };
    }

    final now = DateTime.now();
    final currentYear = '${now.year}';
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final buckets = _statsMap[id]!['buckets'] as Map<String, dynamic>;

    final keysToUpdate = ['allTime', currentYear, currentMonth];
    
    for (final key in keysToUpdate) {
      if (!buckets.containsKey(key)) {
        buckets[key] = <String, dynamic>{ 'plays': 0, 'playedMs': 0 };
      }
      buckets[key]['playedMs'] = (buckets[key]['playedMs'] as int) + playedMs;
      if (countsAsPlay) {
        buckets[key]['plays'] = (buckets[key]['plays'] as int) + 1;
      }
    }

    _statsMap[id]!['lastPlayed'] = now.millisecondsSinceEpoch;

    _saveStats();
    notifyListeners();
  }

  void addTrack(Map<String, String> track) {
    if (!_initialized) return;
    _history.removeWhere((t) => t['id'] == track['id']);
    _history.insert(0, track);
    if (_history.length > 50) _history = _history.sublist(0, 50);
    _saveHistory();
    notifyListeners();
  }

  void addSearch(Map<String, String> item) {
    if (!_initialized) return;
    _searchHistory.removeWhere((t) => t['id'] == item['id']);
    _searchHistory.insert(0, item);
    if (_searchHistory.length > 50) _searchHistory = _searchHistory.sublist(0, 50);
    _saveSearchHistory();
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    _statsMap.clear();
    _saveHistory();
    _saveStats();
    notifyListeners();
  }

  void clearSearchHistory() {
    _searchHistory.clear();
    _saveSearchHistory();
    notifyListeners();
  }

  void removeTrack(String id) {
    _history.removeWhere((t) => t['id'] == id);
    _statsMap.remove(id);
    _saveHistory();
    _saveStats();
    notifyListeners();
  }

  void removeSearch(String id) {
    _searchHistory.removeWhere((t) => t['id'] == id);
    _saveSearchHistory();
    notifyListeners();
  }

  void _saveHistory() {
    final historyJsonList = _history.map((t) => json.encode(t)).toList();
    _prefs.setStringList('listening_history', historyJsonList);
  }
  
  void _saveSearchHistory() {
    final searchJsonList = _searchHistory.map((t) => json.encode(t)).toList();
    _prefs.setStringList('search_history', searchJsonList);
  }

  void _saveStats() {
    _prefs.setString('listening_stats', json.encode(_statsMap));
  }
}
