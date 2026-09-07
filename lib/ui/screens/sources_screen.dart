import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/settings_service.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  String _jioSaavnStatus = 'Checking...';

  @override
  void initState() {
    super.initState();
    _checkSources();
  }

  Future<void> _checkSources() async {
    _checkUrl(
      'https://www.jiosaavn.com',
      onSuccess: () { if (mounted) setState(() => _jioSaavnStatus = 'High Quality • 320kbps'); },
      onError: (e) { if (mounted) setState(() => _jioSaavnStatus = "Can't reach it — $e"); },
    );
  }

  Future<void> _checkUrl(
    String url, {
    required VoidCallback onSuccess,
    required void Function(String) onError,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final uri = Uri.parse(url);
      final req = await client.headUrl(uri);
      final resp = await req.close();
      await resp.drain<void>();
      client.close();
      if (resp.statusCode < 500) {
        onSuccess();
      } else {
        onError('HTTP ${resp.statusCode}');
      }
    } on SocketException catch (e) {
      client.close();
      onError(e.message);
    } catch (e) {
      client.close();
      onError(e.toString().split(':').last.trim());
    }
  }

  Color _hexToColor(String hex) {
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final settings = SettingsService();
        final bgColor = _hexToColor(settings.settingsBgColor);

        return Theme(
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: bgColor,
            colorScheme: const ColorScheme.dark().copyWith(
              surface: bgColor,
              onSurface: Colors.white,
            ),
          ),
          child: Builder(
            builder: (context) {
              return Scaffold(
                backgroundColor: bgColor,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Text('Sources',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
                  centerTitle: true,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      tooltip: 'Re-check sources',
                      onPressed: () {
                        setState(() {
                          _jioSaavnStatus = 'Checking...';
                        });
                        _checkSources();
                      },
                    ),
                  ],
                ),
                body: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'Sources',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'SOURCES — TRIED IN THIS ORDER',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          _buildSourceTile(
                            context: context,
                            enabled: settings.jioSaavn,
                            index: '1',
                            icon: Icons.graphic_eq,
                            title: "JioSaavn",
                            subtitle: _jioSaavnStatus,
                            subtitleColor: _jioSaavnStatus.startsWith('High Quality')
                                ? Colors.white.withOpacity(0.6)
                                : _jioSaavnStatus == 'Checking...'
                                    ? Colors.white38
                                    : Colors.redAccent,
                            isChecking: _jioSaavnStatus == 'Checking...',
                            trailing: Switch(
                              value: settings.jioSaavn,
                              onChanged: (v) => settings.setBool('jioSaavn', v),
                              activeColor: Colors.black,
                              activeTrackColor: Colors.white,
                              inactiveThumbColor: Colors.grey,
                              inactiveTrackColor: Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          _buildSourceTile(
                            context: context,
                            enabled: true,
                            index: '2',
                            icon: Icons.play_circle_fill,
                            title: "YouTube Music",
                            subtitle: "Lossy · Full catalogue · Radio",
                            subtitleColor: Colors.white.withOpacity(0.6),
                            isLast: true,
                            trailing: Text(
                              'Always on',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "A source that doesn't have the track, or can't be reached, is stepped over rather than failing playback — the next one down plays it instead. Anything ranked above YouTube is offered a YouTube track's recording first, and keeps it if what it returns is better than what YouTube would have served.",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSourceTile({
    required BuildContext context,
    required String index,
    required IconData icon,
    required String title,
    required String subtitle,
    Color? subtitleColor,
    bool isChecking = false,
    bool enabled = true,
    required Widget trailing,
    bool isLast = false,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: enabled ? 1.0 : 0.35,
      child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  index,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(icon, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8), size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isChecking)
                          const Padding(
                            padding: EdgeInsets.only(right: 6.0),
                            child: SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white38),
                            ),
                          )
                        else if (subtitleColor != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 5.0),
                            child: Icon(
                              subtitle.contains("Can't") ? Icons.error_outline : Icons.circle,
                              color: subtitleColor,
                              size: subtitle.contains("Can't") ? 13 : 7,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              color: subtitleColor ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              fontSize: 13,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              trailing,
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withOpacity(0.05),
            indent: 64,
          ),
      ],
      ),
    );
  }
}
