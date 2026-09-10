import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../ui/components/liquid_glass.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String releaseTitle;
  final String releaseNotes;
  final String downloadUrl;
  final String htmlUrl;
  final bool hasUpdate;

  AppUpdateInfo({
    required this.latestVersion,
    required this.releaseTitle,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.htmlUrl,
    required this.hasUpdate,
  });
}

class UpdateService {
  static const String repoOwner = "PeAnut8250";
  static const String repoName = "SillyGoose";

  /// Shared notifier for UI elements (e.g. badge next to profile icon)
  static final ValueNotifier<AppUpdateInfo?> updateNotifier = ValueNotifier(null);

  /// Checks GitHub releases API for a newer tag than currently installed version.
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version; // e.g. "1.0.0"

      final Uri url = Uri.parse(
        "https://api.github.com/repos/$repoOwner/$repoName/releases/latest",
      );

      final response = await http.get(
        url,
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String tag = (data['tag_name'] ?? '').toString().replaceAll('v', '').trim();
        final String title = data['name'] ?? 'SillyGoose $tag Update';
        final String rawNotes = (data['body'] ?? '').toString();
        final String cleanedNotes = rawNotes.replaceAll(RegExp(r'\*\*Full Changelog\*\*:.*'), '').trim();
        final String notes = cleanedNotes.isEmpty 
            ? '🚀 Performance improvements, new features, and bug fixes.' 
            : cleanedNotes;
        final String htmlUrl = data['html_url'] ?? '';

        String downloadUrl = htmlUrl;
        final List assets = data['assets'] ?? [];
        final apkAsset = assets.firstWhere(
          (a) => a['name'].toString().toLowerCase().endsWith('.apk'),
          orElse: () => null,
        );

        if (apkAsset != null && apkAsset['browser_download_url'] != null) {
          downloadUrl = apkAsset['browser_download_url'];
        }

        bool isNewer = _isVersionNewer(tag, currentVersion);

        final updateInfo = AppUpdateInfo(
          latestVersion: tag,
          releaseTitle: title,
          releaseNotes: notes,
          downloadUrl: downloadUrl,
          htmlUrl: htmlUrl,
          hasUpdate: isNewer,
        );

        updateNotifier.value = updateInfo;
        return updateInfo;
      }
    } catch (e) {
      debugPrint("UpdateService error: $e");
    }
    return null;
  }

  static bool _isVersionNewer(String latest, String current) {
    if (latest.isEmpty) return false;
    List<int> latestParts = latest.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
    List<int> currentParts = current.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();

    int maxLen = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;
    for (int i = 0; i < maxLen; i++) {
      int l = i < latestParts.length ? latestParts[i] : 0;
      int c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  /// Shows LiquidGlass modal dialog if update is available
  static void showUpdateDialogIfAvailable(BuildContext context) async {
    final updateInfo = await checkForUpdate();
    if (updateInfo != null && updateInfo.hasUpdate && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => _UpdateDialog(info: updateInfo),
      );
    }
  }
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;

  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusText = '';

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusText = 'Starting download...';
    });

    try {
      final uri = Uri.parse(widget.info.downloadUrl);
      
      // On non-Android or fallback, launch browser/external downloader directly
      if (kIsWeb || !Platform.isAndroid) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final request = http.Request('GET', uri);
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('Server returned status ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/SillyGoose-v${widget.info.latestVersion}.apk';
      final file = File(filePath);
      final sink = file.openWrite();

      int downloaded = 0;
      await response.stream.listen(
        (chunk) {
          downloaded += chunk.length;
          sink.add(chunk);
          if (mounted) {
            setState(() {
              _downloadProgress = contentLength > 0 ? (downloaded / contentLength) : 0.5;
              final percent = (_downloadProgress * 100).toInt();
              final mb = (downloaded / (1024 * 1024)).toStringAsFixed(1);
              final totalMb = contentLength > 0 ? (contentLength / (1024 * 1024)).toStringAsFixed(1) : '?';
              _statusText = 'Downloading: $percent% ($mb MB / $totalMb MB)';
            });
          }
        },
        cancelOnError: true,
      ).asFuture();

      await sink.close();

      if (mounted) {
        setState(() {
          _statusText = 'Download complete! Launching installer...';
          _downloadProgress = 1.0;
        });
      }

      // Launch native Android package installer for downloaded APK
      final fileUri = Uri.file(filePath);
      if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback open via url_launcher scheme
        final apkUri = Uri.parse('file://$filePath');
        await launchUrl(apkUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('In-app download error: $e');
      // Fallback to opening external download URL if streamed download fails
      final uri = Uri.parse(widget.info.downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: LiquidGlass(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.system_update_rounded,
                        color: colorScheme.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update Available! 🚀',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Version v${widget.info.latestVersion}',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isDownloading)
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title / Changelog header
                Text(
                  widget.info.releaseTitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Changelog scroll area / Progress Area
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: _isDownloading
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _statusText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _downloadProgress > 0 ? _downloadProgress : null,
                                minHeight: 8,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Text(
                            widget.info.releaseNotes,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                if (!_isDownloading)
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Later',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _startDownloadAndInstall,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download_rounded, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Update Now',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
