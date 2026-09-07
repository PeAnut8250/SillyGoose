import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import 'settings_service.dart';
import 'history_service.dart';
import '../ui/components/app_toast.dart';

class DataBackupService {
  static final DataBackupService _instance = DataBackupService._internal();
  factory DataBackupService() => _instance;
  DataBackupService._internal();

  /// Exports settings, history, liked songs, playlists and listening stats to a JSON file.
  Future<void> exportData(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final Map<String, dynamic> settingsData = {};

      for (final key in keys) {
        final val = prefs.get(key);
        if (val is List<String>) {
          settingsData[key] = val;
        } else if (val is bool || val is int || val is double || val is String) {
          settingsData[key] = val;
        }
      }

      final exportPayload = <String, dynamic>{
        'app': 'sillygoose',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': settingsData,
        'history': HistoryService().history,
        'search_history': HistoryService().searchHistory,
        'liked_songs': HistoryService().likedSongs,
        'playlists': HistoryService().playlists,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportPayload);
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      final fileName = 'sillygoose-backup-$dateStr.json';
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      Uri? saveUri;
      try {
        saveUri = await FilePicker.saveFile(
          dialogTitle: 'Save Backup JSON File',
          fileName: fileName,
          bytes: bytes,
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
      } catch (e) {
        debugPrint('FilePicker.saveFile fallback: $e');
      }

      if (saveUri != null) {
        if (context.mounted) {
          showAppToast(context, 'Exported backup successfully!');
        }
      } else {
        // Fallback: write to temp file and share
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(bytes);
        
        await Share.shareXFiles(
          [XFile(tempFile.path)],
          text: 'SillyGoose Backup Data ($dateStr)',
        );
        if (context.mounted) {
          showAppToast(context, 'Backup ready to save/share');
        }
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (context.mounted) {
        showAppToast(context, 'Export failed: $e');
      }
    }
  }

  /// Imports and restores settings and history from a user-selected JSON file.
  Future<void> importData(BuildContext context) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (files.isEmpty) return;

      final path = files.first.path;
      if (path == null || path.isEmpty) return;

      final content = await File(path).readAsString();

      final Map<String, dynamic> data = json.decode(content);

      if (!data.containsKey('settings') && !data.containsKey('history') && !data.containsKey('liked_songs')) {
        if (context.mounted) {
          showAppToast(context, 'Invalid backup file format');
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // Restore SharedPreferences / settings
      if (data['settings'] is Map) {
        final Map<String, dynamic> settingsMap = Map<String, dynamic>.from(data['settings']);
        for (final entry in settingsMap.entries) {
          final k = entry.key;
          final v = entry.value;
          if (v is bool) {
            await prefs.setBool(k, v);
          } else if (v is int) {
            await prefs.setInt(k, v);
          } else if (v is double) {
            await prefs.setDouble(k, v);
          } else if (v is String) {
            await prefs.setString(k, v);
          } else if (v is List) {
            await prefs.setStringList(k, v.cast<String>());
          }
        }
      }

      // Re-initialize services to reload new restored data
      await SettingsService().init();
      await HistoryService().init();

      if (context.mounted) {
        showAppToast(context, 'App data & history restored!');
      }
    } catch (e) {
      debugPrint('Import error: $e');
      if (context.mounted) {
        showAppToast(context, 'Import failed: $e');
      }
    }
  }
}
