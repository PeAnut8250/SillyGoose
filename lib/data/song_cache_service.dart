import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'settings_service.dart';

class SongCacheService {
  static final SongCacheService _instance = SongCacheService._internal();
  factory SongCacheService() => _instance;
  SongCacheService._internal();

  Directory? _cacheDir;

  Future<Directory> get cacheDir async {
    if (_cacheDir != null) return _cacheDir!;
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/song_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  Future<File> getCacheFile(String trackId) async {
    final dir = await cacheDir;
    final cleanId = trackId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return File('${dir.path}/$cleanId.cache');
  }

  Future<AudioSource> getAudioSource(String trackId, String streamUrl, {Map<String, String>? headers}) async {
    final file = await getCacheFile(trackId);
    
    // If fully cached on disk, play directly from file for instant loading & replay!
    if (await file.exists() && (await file.length()) > 0) {
      try {
        file.setLastModifiedSync(DateTime.now());
      } catch (_) {}
      return AudioSource.file(file.path, tag: trackId);
    }

    // Stream while caching to disk
    try {
      return LockCachingAudioSource(
        Uri.parse(streamUrl),
        cacheFile: file,
        headers: headers,
        tag: trackId,
      );
    } catch (e) {
      // Fallback to plain URI if LockCachingAudioSource fails
      return AudioSource.uri(
        Uri.parse(streamUrl),
        headers: headers,
        tag: trackId,
      );
    }
  }

  Future<double> getSongCacheSizeMB() async {
    try {
      final dir = await cacheDir;
      if (!await dir.exists()) return 0.0;
      int totalBytes = 0;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }
      return totalBytes / (1024 * 1024);
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> enforceCacheLimit() async {
    try {
      final dir = await cacheDir;
      if (!await dir.exists()) return;

      final limitBytes = (SettingsService().songCacheLimit * 1024 * 1024).toInt();
      final files = <File>[];
      int totalBytes = 0;

      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          files.add(entity);
          totalBytes += await entity.length();
        }
      }

      if (totalBytes <= limitBytes) return;

      // Sort files by last modified date (oldest first - LRU)
      files.sort((a, b) {
        try {
          return a.lastModifiedSync().compareTo(b.lastModifiedSync());
        } catch (_) {
          return 0;
        }
      });

      for (final file in files) {
        if (totalBytes <= limitBytes) break;
        try {
          final len = await file.length();
          await file.delete();
          totalBytes -= len;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error enforcing song cache limit: $e');
    }
  }

  Future<void> clearSongCache() async {
    try {
      final dir = await cacheDir;
      if (await dir.exists()) {
        await for (final entity in dir.list(followLinks: false)) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error clearing song cache: $e');
    }
  }

  Future<void> clearImageCache() async {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      final temp = await getTemporaryDirectory();
      await for (final entity in temp.list(followLinks: false)) {
        if (entity is File && (entity.path.endsWith('.jpg') || entity.path.endsWith('.png') || entity.path.endsWith('.webp'))) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error clearing image cache: $e');
    }
  }
}
