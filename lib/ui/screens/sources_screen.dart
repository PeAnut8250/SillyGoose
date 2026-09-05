import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../data/settings_service.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  bool _rickysAddon = true;
  bool _jioSaavn = true;

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
            title: Text('Sources', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
            centerTitle: true,
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
                      index: '1',
                      icon: Icons.extension,
                      title: "Ricky's Addon",
                      subtitle: "Can't reach it right now — Unable to resolve host 'monochrome.rickyaddons.dpdns.org': No address",
                      trailing: Switch(
                        value: _rickysAddon,
                        onChanged: (v) => setState(() => _rickysAddon = v),
                        activeColor: Colors.white,
                        activeTrackColor: Colors.redAccent,
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    _buildSourceTile(
                      index: '2',
                      icon: Icons.graphic_eq,
                      title: "JioSaavn",
                      subtitle: "High Quality • 320kbps",
                      trailing: Switch(
                        value: _jioSaavn,
                        onChanged: (v) => setState(() => _jioSaavn = v),
                        activeColor: Colors.white,
                        activeTrackColor: Colors.redAccent,
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    _buildSourceTile(
                      index: '3',
                      icon: Icons.play_circle_fill,
                      title: "YouTube Music",
                      subtitle: "Lossy - Full catalogue - Radio",
                      trailing: Text(
                        'Always on',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    _buildSourceTile(
                      index: '+',
                      icon: Icons.add,
                      title: "Add custom module",
                      subtitle: "Your own compatible module index. Tried before the built-in one.",
                      trailing: Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        size: 20,
                      ),
                      isLast: true,
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
    required String index,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Icon(
                icon,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                size: 24,
              ),
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
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 13,
                        height: 1.3,
                      ),
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
    );
  }

  Color _hexToColor(String hex) {
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
