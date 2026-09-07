import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_des/dart_des.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../settings_service.dart';

class SaavnStream {
  final String url;
  final int? kbps;
  SaavnStream(this.url, this.kbps);
}

class JioSaavnService {
  static const String _baseUrl = 'https://www.jiosaavn.com/api.php';

  static String _decryptUrl(String encryptedUrl) {
    if (encryptedUrl.isEmpty) return '';
    try {
      String key = '38346591';
      DES desECB = DES(key: key.codeUnits, mode: DESMode.ECB, paddingType: DESPaddingType.PKCS7);
      
      final decodedBytes = base64Decode(encryptedUrl);
      final decrypted = desECB.decrypt(decodedBytes);
      return utf8.decode(decrypted).trim();
    } catch (e) {
      print('JioSaavn URL decryption failed: $e');
      return '';
    }
  }

  /// Map a quality label → target kbps
  static int _qualityToKbps(String quality) {
    switch (quality) {
      case 'Low':     return 48;
      case 'Normal':  return 96;
      case 'High':    return 160;
      case 'Lossless': return 320;
      default:        return 320;
    }
  }

  static SaavnStream? _bestStream(String encryptedUrl, bool has320, int targetKbps) {
    final decryptedUrl = _decryptUrl(encryptedUrl);
    if (decryptedUrl.isEmpty) return null;

    final regex = RegExp(r'_(48|96|160|320)\.(mp4|aac|mp3)$');
    final match = regex.firstMatch(decryptedUrl);
    final extension = match?.group(2) ?? 'mp4';

    // Clamp to what the song actually supports
    final maxKbps = has320 ? 320 : 160;
    final clampedTarget = targetKbps.clamp(48, maxKbps);

    // Pick the nearest available tier (48, 96, 160, 320)
    const tiers = [48, 96, 160, 320];
    int chosen = tiers.first;
    for (final tier in tiers) {
      if (tier <= clampedTarget) chosen = tier;
    }

    final newUrl = match != null
        ? decryptedUrl.replaceRange(match.start, match.end, '_$chosen.$extension')
        : decryptedUrl;

    print('[JioSaavn Quality] target=${targetKbps}kbps chosen=${chosen}kbps (max=${maxKbps}kbps)');
    return SaavnStream(newUrl, chosen);
  }

  Future<SaavnStream?> resolveTopStream(String title, String artist, {bool forceHighestQuality = false}) async {
    try {
      // Clean up the title aggressively
      String cleanTitle = title.replaceAll(RegExp(r'\s*\|.*?$'), '')
                               .replaceAll(RegExp(r'\s*\(.*?\)'), '')
                               .replaceAll(RegExp(r'\s*\[.*?\]'), '')
                               .replaceAll(RegExp(r'official video|music video|lyric video|audio|remix|feat|ft\.', caseSensitive: false), '')
                               .trim();
                               
      // Fix artists and remove things like VEVO or Records
      String cleanArtist = artist.replaceAll(r'$', 'S')
                                 .replaceAll(RegExp(r'vevo|records|music|official', caseSensitive: false), '')
                                 .trim();
      
      // Strip ALL special characters to avoid confusing JioSaavn's terrible search engine
      String query = '$cleanTitle $cleanArtist'.replaceAll(RegExp(r'[^\w\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      
      final searchUri = Uri.parse(_baseUrl).replace(queryParameters: {
        '__call': 'search.getResults',
        '_format': 'json',
        '_marker': '0',
        'api_version': '4',
        'ctx': 'android',
        'q': query,
        'p': '1',
        'n': '3'
      });

      final searchRes = await http.get(searchUri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/134.0.0.0',
        'Cookie': 'explicit_content=1'
      }).timeout(const Duration(seconds: 5));

      if (searchRes.statusCode != 200) return null;

      final searchData = jsonDecode(searchRes.body);
      final results = searchData['results'] as List<dynamic>?;
      
      if (results == null || results.isEmpty) return null;
      
      final topResult = results[0];
      
      // Strict Verification: Ensure the result actually matches the requested song!
      // If it's completely unrelated (like a Bhajan instead of a Rap song), reject it!
      // Remove special characters from validation strings so things like "!" don't break the match
      final resTitle = (topResult['title']?.toString() ?? '').toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
      final resSubtitle = (topResult['subtitle']?.toString() ?? topResult['description']?.toString() ?? '').toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
      
      final cleanTitleLower = cleanTitle.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
      final cleanArtistLower = cleanArtist.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
      
      bool titleMatch = cleanTitleLower.isNotEmpty && resTitle.contains(cleanTitleLower.split(' ').first);
      bool artistMatch = cleanArtistLower.isNotEmpty && (resSubtitle.contains(cleanArtistLower.split(' ').first) || resTitle.contains(cleanArtistLower.split(' ').first));
      
      if (!titleMatch && !artistMatch) {
        print('JioSaavn mismatch rejected: $resTitle by $resSubtitle');
        return null;
      }
      
      final songId = topResult['id'];
      if (songId == null) return null;

      final detailsUri = Uri.parse(_baseUrl).replace(queryParameters: {
        '__call': 'song.getDetails',
        '_format': 'json',
        '_marker': '0',
        'api_version': '4',
        'ctx': 'android',
        'pids': songId.toString()
      });

      final detailsRes = await http.get(detailsUri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/134.0.0.0',
        'Cookie': 'explicit_content=1'
      }).timeout(const Duration(seconds: 5));

      if (detailsRes.statusCode != 200) return null;

      final detailsData = jsonDecode(detailsRes.body);
      Map<String, dynamic>? songData;
      
      if (detailsData['songs'] != null && detailsData['songs'].isNotEmpty) {
        songData = detailsData['songs'][0];
      } else if (detailsData is Map<String, dynamic>) {
        songData = detailsData.values.whereType<Map<String, dynamic>>().firstOrNull;
      }
      
      if (songData == null) return null;

      final moreInfo = songData['more_info'];
      if (moreInfo == null) return null;

      final encryptedUrl = moreInfo['encrypted_media_url'];
      if (encryptedUrl == null || encryptedUrl.isEmpty) return null;

      final has320 = moreInfo['320kbps']?.toString().toLowerCase() == 'true';
      
      if (forceHighestQuality) {
        return _bestStream(encryptedUrl, has320, 320);
      }

      // Determine target quality from settings based on current network
      final connectivityResult = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 2), onTimeout: () => [ConnectivityResult.wifi]);
      final isWifi = connectivityResult.contains(ConnectivityResult.wifi) ||
          connectivityResult.contains(ConnectivityResult.ethernet);
      final qualityLabel = isWifi
          ? SettingsService().wifiQuality
          : SettingsService().mobileDataQuality;
      final targetKbps = _qualityToKbps(qualityLabel);
      
      return _bestStream(encryptedUrl, has320, targetKbps);

    } catch (e) {
      print('JioSaavn fetch error: $e');
      return null;
    }
  }
}
