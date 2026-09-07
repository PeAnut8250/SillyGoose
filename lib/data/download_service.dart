import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/jiosaavn_service.dart';
import 'api/youtube_service.dart';

class DownloadState {
  final double progress; // 0.0 to 1.0
  final bool isDownloading;
  final bool isCompleted;
  final String? error;

  const DownloadState({
    this.progress = 0.0,
    this.isDownloading = false,
    this.isCompleted = false,
    this.error,
  });
}

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal() {
    _init();
  }

  static const String _keySavedDownloads = 'downloaded_tracks_v2';
  final JioSaavnService _saavnService = JioSaavnService();
  final YoutubeService _ytService = YoutubeService();

  final Map<String, DownloadState> _activeDownloads = {};
  final Map<String, Map<String, String>> _downloadedTracks = {};
  bool _isInitialized = false;

  Map<String, DownloadState> get activeDownloads => Map.unmodifiable(_activeDownloads);
  List<Map<String, String>> get downloadedTracks => _downloadedTracks.values.toList();

  Future<void> _init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_keySavedDownloads);
      if (savedStr != null) {
        final List<dynamic> decoded = jsonDecode(savedStr);
        for (var item in decoded) {
          final track = Map<String, String>.from(item as Map);
          final filePath = track['localPath'];
          if (filePath != null && await File(filePath).exists()) {
            _downloadedTracks[track['id']!] = track;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading downloaded tracks: $e');
    }
    _isInitialized = true;
    notifyListeners();
  }

  bool isDownloaded(String trackId) {
    return _downloadedTracks.containsKey(trackId);
  }

  DownloadState? getDownloadState(String trackId) {
    return _activeDownloads[trackId];
  }

  Future<Directory> get _downloadDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> downloadTrack(Map<String, String> track, {Function(String)? onComplete, Function(String)? onError}) async {
    final trackId = track['id'];
    if (trackId == null || trackId.isEmpty) return;

    if (isDownloaded(trackId)) {
      onComplete?.call('Already downloaded');
      return;
    }

    if (_activeDownloads[trackId]?.isDownloading == true) {
      return;
    }

    _activeDownloads[trackId] = const DownloadState(isDownloading: true, progress: 0.05);
    notifyListeners();

    try {
      final title = track['title'] ?? '';
      final artist = track['subtitle'] ?? '';

      // 1. Resolve highest quality stream URL (matching BitChord's StreamResolver: 320kbps Lossless)
      SaavnStream? saavnStream;
      String? ytUrl;

      await Future.wait([
        _saavnService.resolveTopStream(title, artist, forceHighestQuality: true).then((v) => saavnStream = v).catchError((_) => null),
        _ytService.getAudioStreamUrl(trackId).then((v) => ytUrl = v).catchError((_) => null),
      ]);

      String? streamUrl;
      String audioSource = 'Audio';
      String quality = '320';

      if (saavnStream != null) {
        streamUrl = saavnStream!.url;
        audioSource = 'JioSaavn (320kbps Lossless)';
        quality = saavnStream!.kbps?.toString() ?? '320';
      } else if (ytUrl != null) {
        streamUrl = ytUrl!;
        audioSource = 'YouTube (HQ)';
        quality = '160';
      }

      if (streamUrl == null) {
        throw Exception('Stream URL could not be resolved');
      }

      // 2. High-speed bounded range HTTP download (matching BitChord's Downloader.kt range algorithm)
      final dir = await _downloadDir;
      final cleanId = trackId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final extension = streamUrl.contains('.mp4') ? 'mp4' : 'm4a';
      final file = File('${dir.path}/$cleanId.$extension');

      await _downloadWithRanges(
        streamUrl,
        file,
        onProgress: (written, total) {
          final p = total > 0 ? (written / total).clamp(0.05, 0.99) : 0.5;
          _activeDownloads[trackId] = DownloadState(isDownloading: true, progress: p);
          notifyListeners();
        },
      );

      // 3. Store track metadata
      final savedMetadata = Map<String, String>.from(track);
      savedMetadata['localPath'] = file.path;
      savedMetadata['audioSource'] = audioSource;
      savedMetadata['audioQuality'] = quality;
      savedMetadata['downloadedAt'] = DateTime.now().toIso8601String();

      _downloadedTracks[trackId] = savedMetadata;
      _activeDownloads.remove(trackId);
      await _saveMetadata();
      notifyListeners();

      onComplete?.call('Downloaded ${track['title']}');
    } catch (e) {
      debugPrint('Download error for $trackId: $e');
      _activeDownloads[trackId] = DownloadState(isDownloading: false, error: e.toString());
      notifyListeners();
      onError?.call('Failed to download: $e');
    }
  }

  /// Range chunk downloader algorithm matching BitChord's Downloader.kt:
  /// Uses 2MB range requests for maximum line-rate download speeds instead of YouTube stream throttling.
  Future<void> _downloadWithRanges(String url, File targetFile, {required Function(int written, int total) onProgress}) async {
    const chunkBytes = 2 * 1024 * 1024; // 2MB chunks matching BitChord
    final uri = Uri.parse(url);

    // Get total content length
    final headRes = await http.head(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    }).timeout(const Duration(seconds: 5)).catchError((_) => http.Response('', 400));

    int totalBytes = -1;
    if (headRes.headers.containsKey('content-length')) {
      totalBytes = int.tryParse(headRes.headers['content-length']!) ?? -1;
    }

    final sink = targetFile.openWrite();
    int position = 0;

    try {
      if (totalBytes > 0) {
        while (position < totalBytes) {
          final end = (position + chunkBytes - 1).clamp(0, totalBytes - 1);
          final client = http.Client();
          final request = http.Request('GET', uri);
          request.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
          request.headers['Range'] = 'bytes=$position-$end';

          final response = await client.send(request);
          if (response.statusCode != 200 && response.statusCode != 206) {
            throw Exception('HTTP ${response.statusCode}');
          }

          await for (final chunk in response.stream) {
            sink.add(chunk);
            position += chunk.length;
            onProgress(position, totalBytes);
          }
          client.close();
        }
      } else {
        // Direct stream fallback
        final client = http.Client();
        final request = http.Request('GET', uri);
        request.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
        final response = await client.send(request);
        await for (final chunk in response.stream) {
          sink.add(chunk);
          position += chunk.length;
          onProgress(position, position + 1000000);
        }
        client.close();
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  Future<void> deleteAllDownloads() async {
    final tracks = List<Map<String, String>>.from(_downloadedTracks.values);
    for (final track in tracks) {
      final path = track['localPath'];
      if (path != null) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error deleting download file: $e');
        }
      }
    }
    _downloadedTracks.clear();
    await _saveMetadata();
    notifyListeners();
  }

  Future<void> deleteDownload(String trackId) async {
    final track = _downloadedTracks[trackId];
    if (track != null) {
      final path = track['localPath'];
      if (path != null) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error deleting download file: $e');
        }
      }
      _downloadedTracks.remove(trackId);
      await _saveMetadata();
      notifyListeners();
    }
  }

  Future<void> _saveMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _downloadedTracks.values.toList();
      await prefs.setString(_keySavedDownloads, jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving download metadata: $e');
    }
  }
}
