import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
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

class _UpdateDialog extends StatelessWidget {
  final AppUpdateInfo info;

  const _UpdateDialog({required this.info});

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
                        'Version v${info.latestVersion}',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
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
              info.releaseTitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // Changelog scroll area
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
              child: SingleChildScrollView(
                child: Text(
                  info.releaseNotes.replaceAll(RegExp(r'https?://[^\s]+'), '').trim().isEmpty 
                    ? '⚡ Performance improvements, new features, and bug fixes.'
                    : info.releaseNotes,
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
                    onPressed: () async {
                      final uri = Uri.parse(info.downloadUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
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
        ), // Column
      ), // Container
    ), // LiquidGlass
  ), // ClipRRect
  ); // Dialog
  }
}
