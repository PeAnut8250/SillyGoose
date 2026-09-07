import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import '../../data/settings_service.dart';
import '../../data/api/audio_service.dart';
import '../../data/history_service.dart';
import '../../data/network_service.dart';
import '../../data/app_localizations.dart';
import '../../data/update_service.dart';
import '../../data/song_cache_service.dart';
import '../components/liquid_glass.dart';
import '../components/mini_player.dart';
import '../components/app_toast.dart';
import 'sources_screen.dart';
import 'replay_screen.dart';
import '../../data/data_backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

Color _hexToColor(String hex) {
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;
  double _songCacheSizeMB = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  void _loadCacheSize() {
    SongCacheService().getSongCacheSizeMB().then((sz) {
      if (mounted) {
        setState(() {
          _songCacheSizeMB = sz;
        });
      }
    });
  }

  void _showCustomToast(String message) {
    if (!mounted) return;
    showAppToast(context, message);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showLanguagePicker(BuildContext context) {
    final currentLang = SettingsService().appLanguage;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Language',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: kSupportedLanguages.length,
                  itemBuilder: (_, i) {
                    final lang = kSupportedLanguages[i];
                    final isSelected = lang.displayName == currentLang;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.08),
                        child: Text(
                          lang.locale.languageCode.toUpperCase().substring(0, 2),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.black : Colors.white70,
                          ),
                        ),
                      ),
                      title: Text(
                        lang.displayName,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        lang.nativeName,
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.white)
                          : null,
                      onTap: () {
                        SettingsService().setString('appLanguage', lang.displayName);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([SettingsService(), AudioService(), NetworkService()]),
      builder: (context, _) {
        final settings = SettingsService();
        final network = NetworkService();
        final track = AudioService().currentTrack;
        final bgColor = _hexToColor(settings.settingsBgColor);
        final l10n = AppLocalizations.of(context);
        
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
                body: Stack(
            children: [
              ListView(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  left: 16.0, 
                  right: 16.0, 
                  bottom: track != null ? (24.0 + 48.0 + 16.0) : 16.0, // Padding for MiniPlayer
                  top: MediaQuery.of(context).padding.top + 80 // Padding for Custom Header
                ),
                children: [
              _SettingsGroup(
                children: [
                  _SettingsNavTile(
                    icon: Icons.person,
                    title: 'Account & Integrations',
                    subtitle: 'last.fm, etc.',
                  ),
                ],
              ),
              
              _SettingsHeader(l10n.audioQuality.toUpperCase()),
              _SettingsGroup(
                children: [
                  _SettingsNavTile(
                    icon: Icons.graphic_eq, 
                    title: 'Sources', 
                    subtitle: 'Where audio comes from, and in what order',
                    onTap: () {
                      Navigator.push(context, PageRouteBuilder(
                        pageBuilder: (context, animation1, animation2) => const SourcesScreen(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ));
                    },
                  ),
                  _SettingsNavTile(
                    icon: Icons.wifi, 
                    title: l10n.onWifi, 
                    subtitle: network.isWifi ? '● Active' : 'Not connected', 
                    subtitleColor: network.isWifi ? Colors.white.withOpacity(0.6) : null,
                    valueText: settings.wifiQuality,
                    onTap: () => _showSelectionDialog(context, l10n.onWifi, ['Low', 'Normal', 'High', 'Lossless'], settings.wifiQuality, (val) => settings.setString('wifiQuality', val)),
                  ),
                  _SettingsNavTile(
                    icon: Icons.signal_cellular_alt, 
                    title: l10n.onMobileData, 
                    subtitle: network.isMobile ? '● Active' : 'Not connected',
                    subtitleColor: network.isMobile ? Colors.white.withOpacity(0.6) : null,
                    valueText: settings.mobileDataQuality,
                    onTap: () => _showSelectionDialog(context, l10n.onMobileData, ['Low', 'Normal', 'High', 'Lossless'], settings.mobileDataQuality, (val) => settings.setString('mobileDataQuality', val)),
                  ),
                ],
              ),

              _SettingsHeader(l10n.downloads.toUpperCase()),
              _SettingsGroup(
                children: [
                  _SettingsNavTile(
                    icon: Icons.download_rounded, 
                    title: 'Download quality', 
                    subtitle: '128 kbps opub audio, whether it\'s supported or not', 
                    valueText: settings.downloadQuality,
                    onTap: () => _showSelectionDialog(context, 'Download quality', ['Low', 'Normal', 'High', 'Lossless'], settings.downloadQuality, (val) => settings.setString('downloadQuality', val)),
                  ),
                  _SettingsSwitchTile(title: 'Download over Wi-Fi only', value: settings.downloadOverWifi, onChanged: (v) => settings.setBool('downloadOverWifi', v)),
                ],
              ),

              _SettingsHeader('PLAYBACK'),
              _SettingsGroup(
                children: [
                  _SettingsSliderTile(icon: Icons.shuffle, title: 'Crossfade', subtitle: 'Smooth transition from one song...', value: settings.crossfade, max: 10, format: (v) => v == 0 ? 'Off' : '${v.toInt()}s', onChanged: (v) => settings.setDouble('crossfade', v)),
                  _SettingsSwitchTile(icon: Icons.auto_awesome, title: 'Automix BETA', subtitle: 'Let algorithm dynamically mix automatically...', value: settings.automix, onChanged: (v) => settings.setBool('automix', v)),
                  _SettingsSwitchTile(icon: Icons.volume_off, title: 'Skip silence', subtitle: 'This feature is often inaccurate', value: settings.skipSilence, onChanged: (v) => settings.setBool('skipSilence', v)),
                  _SettingsSwitchTile(icon: Icons.surround_sound, title: 'Spatial audio', subtitle: 'Virtual surround sound (requires compatible headset)', value: settings.spatialAudio, onChanged: (v) => settings.setBool('spatialAudio', v)),
                  _SettingsNavTile(icon: Icons.tune, title: 'Equalizer', subtitle: 'Your device\'s equalizer app'),
                  _SettingsSwitchTile(icon: Icons.data_object, title: 'Show stats for nerds', subtitle: 'Codecs, bitrates and timestamps info on the player', value: settings.showStats, onChanged: (v) => settings.setBool('showStats', v)),
                  _SettingsSwitchTile(icon: Icons.music_video, title: 'Stop converting video songs to audio version', subtitle: 'Replaces zero-bitrate upload/unofficial video mappings...', value: settings.stopVideoConversion, onChanged: (v) => settings.setBool('stopVideoConversion', v)),
                ],
              ),

              _SettingsHeader('APPEARANCE'),
              _SettingsGroup(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.palette, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 22),
                            SizedBox(width: 16),
                            Text('Theme', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        SizedBox(height: 12),
                        _SegmentedThemeSelector(
                          currentTheme: settings.theme,
                          onThemeChanged: (newTheme) => settings.setString('theme', newTheme),
                        ),
                      ],
                    ),
                  ),
                  _SettingsSwitchTile(icon: Icons.animation, title: 'Reduce animation', subtitle: 'Disables the player background gradient...', value: settings.reduceAnimation, onChanged: (v) => settings.setBool('reduceAnimation', v)),
                  _SettingsSwitchTile(icon: Icons.blur_off, title: 'Reduce dynamic blur', subtitle: 'Stops UI blocks from blurring reliably...', value: settings.reduceBlur, onChanged: (v) => settings.setBool('reduceBlur', v)),
                  _SettingsSwitchTile(
                    icon: Icons.fullscreen, 
                    title: 'Full-screen cover art', 
                    subtitle: 'Scales cover to the edges of the player instead of...', 
                    value: settings.fullScreenCover, 
                    onChanged: (v) {
                      settings.setBool('fullScreenCover', v);
                      if (!v) {
                        settings.setBool('animatedCover', false);
                      }
                    }
                  ),
                  _SettingsSwitchTile(
                    icon: Icons.gif_box, 
                    title: 'Animated cover art', 
                    subtitle: settings.fullScreenCover 
                      ? 'Plays the looping video when streaming...'
                      : 'Requires Full-screen cover art to be enabled first', 
                    value: settings.animatedCover, 
                    onChanged: settings.fullScreenCover ? (v) => settings.setBool('animatedCover', v) : null
                  ),
                  _SettingsSwitchTile(
                    icon: Icons.blur_linear,
                    title: 'Liquid Glass Navbar',
                    subtitle: 'Enable Apple-style physical frosted glass on the navigation bar',
                    value: settings.liquidGlass,
                    onChanged: (v) => settings.setBool('liquidGlass', v),
                  ),
                  _SettingsSwitchTile(icon: Icons.lyrics, title: 'Synced lyrics', subtitle: '...of the up the words as they\'re sung...', value: settings.syncedLyrics, onChanged: (v) => settings.setBool('syncedLyrics', v)),
                  _SettingsNavTile(
                    icon: Icons.source, 
                    title: 'Lyrics sources', 
                    subtitle: settings.activeLyricsSources.join(', ') + '...',
                    onTap: () => _showLyricsSourcesDialog(context),
                  ),
                ],
              ),

              _SettingsHeader('STORAGE'),
              _SettingsGroup(
                children: [
                  _SettingsSliderTile(
                    icon: Icons.storage,
                    title: 'Song cache limit',
                    subtitle: _songCacheSizeMB > 0 
                        ? 'Disk space used for instant loading... (${_songCacheSizeMB.toStringAsFixed(1)} MB used)'
                        : 'Disk space used to keep audio for instant loading...',
                    value: settings.songCacheLimit,
                    max: 2048,
                    format: (v) => '${v.toInt()} MB',
                    onChanged: (v) {
                      settings.setDouble('songCacheLimit', v);
                      SongCacheService().enforceCacheLimit();
                      _loadCacheSize();
                    },
                  ),
                  _SettingsNavTile(
                    icon: Icons.cleaning_services,
                    title: 'Clear song cache',
                    subtitle: 'Frees space used by downloaded audio',
                    onTap: () async {
                      await SongCacheService().clearSongCache();
                      _loadCacheSize();
                      _showCustomToast('Song cache cleared');
                    },
                  ),
                  _SettingsNavTile(
                    icon: Icons.delete_outline,
                    title: 'Clear image cache',
                    subtitle: 'Frees space used by album artwork',
                    onTap: () async {
                      await SongCacheService().clearImageCache();
                      _showCustomToast('Image cache cleared');
                    },
                  ),
                ],
              ),

              _SettingsHeader('DATA / STATS'),
              _SettingsGroup(
                children: [
                  _SettingsNavTile(
                    icon: Icons.bar_chart,
                    title: 'Replay',
                    subtitle: 'Your top songs, artists, albums, genres',
                    onTap: () {
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (context) => const ReplayScreen()),
                      );
                    },
                  ),
                  _SettingsSwitchTile(icon: Icons.warning_amber, title: 'Warn out genres', subtitle: 'Hide Lofi/Ambient in artists plays...', value: settings.warnOutGenres, onChanged: (v) => settings.setBool('warnOutGenres', v)),
                  _SettingsNavTile(
                    icon: Icons.file_upload_outlined,
                    title: 'Export data',
                    subtitle: 'Settings and listening history as a JSON file',
                    onTap: () => DataBackupService().exportData(context),
                  ),
                  _SettingsNavTile(
                    icon: Icons.file_download_outlined,
                    title: 'Import data',
                    subtitle: 'Restores the settings and history on this device',
                    onTap: () => DataBackupService().importData(context),
                  ),
                ],
              ),

              _SettingsHeader('MISCELLANEOUS'),
              _SettingsGroup(
                children: [
                  _SettingsSwitchTile(icon: Icons.swipe_right, title: 'Play next on swipe', subtitle: 'Setting a song plays it automatically the next time...', value: settings.playNextOnSwipe, onChanged: (v) => settings.setBool('playNextOnSwipe', v)),
                  _SettingsSwitchTile(icon: Icons.repeat_one, title: 'Don\'t repeat songs in current session', subtitle: 'AutoPlay won\'t suggest a song already played...', value: settings.dontRepeatSession, onChanged: (v) => settings.setBool('dontRepeatSession', v)),
                  _SettingsSwitchTile(icon: Icons.stop_circle, title: 'Stop music on close from recents', subtitle: 'Stops playback when you swipe away the recent apps', value: settings.stopMusicOnClose, onChanged: (v) => settings.setBool('stopMusicOnClose', v)),
                  _SettingsSwitchTile(icon: Icons.volume_mute, title: 'Hide volume bar', subtitle: 'Removes the volume slider from the player', value: settings.hideVolumeBar, onChanged: (v) => settings.setBool('hideVolumeBar', v)),
                ],
              ),

              _SettingsHeader('SETTINGS CUSTOMIZATION'),
              _SettingsGroup(
                children: [
                  _SettingsNavTile(
                    icon: Icons.color_lens,
                    title: 'Background Color',
                    subtitle: 'Base color for the settings screen',
                    valueText: const {
                      '#1C1C1C': 'Classic Grey',
                      '#121212': 'Deep Black',
                      '#1B263B': 'Midnight Blue',
                      '#3D2323': 'Crimson Red',
                      '#233D2D': 'Forest Green',
                    }[settings.settingsBgColor] ?? 'Custom',
                    onTap: () {
                      final optionsMap = {
                        'Classic Grey': '#1C1C1C',
                        'Deep Black': '#121212',
                        'Midnight Blue': '#1B263B',
                        'Crimson Red': '#3D2323',
                        'Forest Green': '#233D2D',
                      };
                      _showSelectionDialog(
                        context,
                        'Background Color',
                        optionsMap.keys.toList(),
                        const {
                          '#1C1C1C': 'Classic Grey',
                          '#121212': 'Deep Black',
                          '#1B263B': 'Midnight Blue',
                          '#3D2323': 'Crimson Red',
                          '#233D2D': 'Forest Green',
                        }[settings.settingsBgColor] ?? 'Classic Grey',
                        (val) => settings.setString('settingsBgColor', optionsMap[val]!),
                      );
                    },
                  ),
                  _SettingsSliderTile(
                    icon: Icons.blur_on,
                    title: 'Glass Blur Amount',
                    subtitle: 'Intensity of the background blur',
                    value: settings.settingsGlassBlur,
                    max: 20.0,
                    format: (v) => v.toStringAsFixed(1),
                    onChanged: (v) => settings.setDouble('settingsGlassBlur', v),
                  ),
                  _SettingsSliderTile(
                    icon: Icons.opacity,
                    title: 'Icon Opacity',
                    subtitle: 'Transparency of the frosted icons',
                    value: settings.settingsIconOpacity,
                    max: 1.0,
                    format: (v) => '${(v * 100).toInt()}%',
                    onChanged: (v) => settings.setDouble('settingsIconOpacity', v),
                  ),
                  ],
                ),

                _SettingsHeader('ALGORITHM'),
                _SettingsGroup(
                  children: [
                    _SettingsNavTile(
                      icon: Icons.auto_awesome, 
                      title: 'Reset Algorithm', 
                      subtitle: 'Clear playback history and algorithm memory',
                      onTap: () {
                        HistoryService().clearHistory();
                        showAppToast(context, 'Algorithm learning history cleared!');
                      },
                    ),
                  ],
                ),

                _SettingsHeader('LANGUAGE'),
              _SettingsGroup(
                children: [
                  ListenableBuilder(
                    listenable: SettingsService(),
                    builder: (context, _) {
                      final currentLang = SettingsService().appLanguage;
                      final native = kSupportedLanguages
                          .firstWhere((l) => l.displayName == currentLang,
                              orElse: () => kSupportedLanguages.first)
                          .nativeName;
                      final l = AppLocalizations.of(context);
                      return _SettingsNavTile(
                        icon: Icons.language,
                        title: l.appLanguage,
                        subtitle: '$currentLang ($native)',
                        onTap: () => _showLanguagePicker(context),
                      );
                    },
                  ),
                ],
              ),

                _SettingsHeader('ABOUT & UPDATES'),
                _SettingsGroup(
                  children: [
                    _SettingsNavTile(
                      icon: Icons.system_update,
                      title: 'Check for Updates',
                      subtitle: 'Version 1.0.2 • Tap to check GitHub releases',
                      onTap: () {
                        showAppToast(context, 'Checking for updates...');
                        UpdateService.checkForUpdate().then((info) {
                          if (!context.mounted) return;
                          if (info != null && info.hasUpdate) {
                            UpdateService.showUpdateDialogIfAvailable(context);
                          } else {
                            showAppToast(context, 'SillyGoose is up to date! 🎉');
                          }
                        });
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Center(
                    child: Text(
                      'SillyGoose v1.0.2',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 50),
            ],
              ),
              // Custom Fixed Header
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16.0,
                right: 16.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button Pill
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: ListenableBuilder(
                        listenable: SettingsService(),
                        builder: (context, _) => Stack(
                          alignment: Alignment.center,
                          children: [
                            // Background
                            Positioned.fill(
                              child: AnimatedOpacity(
                                opacity: _scrollOffset > 10 ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: LiquidGlass(
                                  forceOpaque: !SettingsService().liquidGlass,
                                  child: Container(),
                                ),
                              ),
                            ),
                            // Foreground
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: EdgeInsets.all(12),
                                color: Colors.transparent,
                                child: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).colorScheme.onSurface, size: 24),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Floating Title Pill
                    Expanded(
                      child: AnimatedOpacity(
                        opacity: _scrollOffset > 50 ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Align(
                            alignment: Alignment.center,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: ListenableBuilder(
                                listenable: SettingsService(),
                                builder: (context, _) => LiquidGlass(
                                  forceOpaque: !SettingsService().liquidGlass,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    color: Colors.transparent,
                                    child: Text(
                                      'Settings',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Invisible placeholder for symmetry
                    SizedBox(width: 48),
                  ],
                ),
              ),
              if (track != null)
                Positioned(
                  left: 47,
                  right: 47,
                  bottom: 24,
                  height: 42,
                  child: MiniPlayer(
                    track: track,
                    isInline: true,
                  ),
                ),
            ],
          ),
        );
            },
          ),
        );
      },
    );
  }


  void _showLyricsSourcesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _LyricsSourcesDialogContent(),
    );
  }

  void _showSelectionDialog(BuildContext context, String title, List<String> options, String currentValue, ValueChanged<String> onSelected) {
    showDialog(
      context: context,
      builder: (context) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
          margin: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            title,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                        ...options.asMap().entries.map((entry) {
                          final index = entry.key;
                          final option = entry.value;
                          final isSelected = option == currentValue;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () {
                                  onSelected(option);
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        option,
                                        style: TextStyle(
                                          color: isSelected ? Colors.redAccent : Theme.of(context).colorScheme.onSurface,
                                          fontSize: 18,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        SizedBox(width: 8),
                                        Icon(Icons.check, color: Colors.redAccent, size: 20),
                                      ]
                                    ],
                                  ),
                                ),
                              ),
                              if (index < options.length - 1)
                                Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                      alignment: Alignment.center,
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
        ),
        );
      },
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  final String title;
  const _SettingsHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            Theme.of(context).colorScheme.onSurface.withOpacity(0.01),
          ],
        ),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08), width: 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SettingsSwitchTile({
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: icon != null ? FrostedIcon(icon!) : null,
      title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis) : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.black,
        activeTrackColor: Colors.white,
        inactiveThumbColor: Colors.grey,
        inactiveTrackColor: Colors.grey.withOpacity(0.3),
      ),
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final String? valueText;
  final VoidCallback? onTap;

  const _SettingsNavTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.valueText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: FrostedIcon(icon),
      title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: TextStyle(
                color: subtitleColor ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                fontSize: 13,
                fontWeight: subtitleColor != null ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (valueText != null) ...[
            Text(valueText!, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14)),
            SizedBox(width: 8),
          ],
          Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), size: 20),
        ],
      ),
      onTap: onTap ?? () {},
    );
  }
}

class _SettingsSliderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final double max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  const _SettingsSliderTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.max,
    required this.format,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: FrostedIcon(icon),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)),
                    Text(format(value), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14)),
                  ],
                ),
                SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 8.0,
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withOpacity(0.12),
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 9,
                      elevation: 4,
                      pressedElevation: 6,
                    ),
                    overlayColor: Colors.white.withOpacity(0.15),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: value,
                    min: 0,
                    max: max,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class FrostedIcon extends StatelessWidget {
  final IconData icon;
  const FrostedIcon(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    final opacity = SettingsService().settingsIconOpacity;
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Theme.of(context).colorScheme.onSurface.withOpacity(opacity),
          Theme.of(context).colorScheme.onSurface.withOpacity(opacity * 0.2),
        ],
        stops: const [0.0, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 22),
    );
  }
}

class _SegmentedThemeSelector extends StatefulWidget {
  final String currentTheme;
  final ValueChanged<String> onThemeChanged;

  const _SegmentedThemeSelector({
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<_SegmentedThemeSelector> createState() => _SegmentedThemeSelectorState();
}

class _SegmentedThemeSelectorState extends State<_SegmentedThemeSelector> {
  late String _selectedTheme;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentTheme;
  }

  @override
  void didUpdateWidget(covariant _SegmentedThemeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTheme != widget.currentTheme) {
      _selectedTheme = widget.currentTheme;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const themes = ['System', 'Light', 'Dark', 'Dynamic'];
    final selectedIndex = themes.indexOf(_selectedTheme).clamp(0, 3);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: onSurface.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final itemWidth = totalWidth / themes.length;

          return RepaintBoundary(
            child: Stack(
              children: [
                // Smooth Sliding Pill Highlight
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.fastOutSlowIn,
                  left: selectedIndex * itemWidth,
                  top: 0,
                  bottom: 0,
                  width: itemWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: onSurface,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),

                // Theme Options Row
                Positioned.fill(
                  child: Row(
                    children: List.generate(themes.length, (index) {
                      final label = themes[index];
                      final isSelected = index == selectedIndex;

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (_selectedTheme == label) return;
                            _debounceTimer?.cancel();
                            setState(() {
                              _selectedTheme = label;
                            });
                            // Delay heavy full-app theme rebuild until sliding animation finishes smoothly
                            _debounceTimer = Timer(const Duration(milliseconds: 230), () {
                              if (mounted) {
                                widget.onThemeChanged(label);
                              }
                            });
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                color: isSelected ? surface : onSurface,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 13,
                              ),
                              child: Text(label),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LyricsSourcesDialogContent extends StatefulWidget {
  const _LyricsSourcesDialogContent();

  @override
  State<_LyricsSourcesDialogContent> createState() => _LyricsSourcesDialogContentState();
}

class _LyricsSourcesDialogContentState extends State<_LyricsSourcesDialogContent> {
  static const Map<String, String> kSourceDetails = {
    'LyricsPlus': 'Syllable by syllable, on community mirrors',
    'PaxSenix': 'Apple Music timings again, on a second host',
    'BetterLyrics': 'Apple Music timings, word by word',
    'SimpMusic': 'Matched on the video, so never the wrong edit',
    'KuGou': 'Whole lines, strong outside the English catalogue',
    'LRCLIB': 'Whole lines only, and always up',
    'Musixmatch': 'Whole lines, from the biggest lyrics database there is',
    'Genius': 'Plain text fallback, massive web catalogue',
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final settings = SettingsService();
        final order = settings.lyricsSourceOrder;
        final selected = settings.activeLyricsSources;
        final prioritizeSyllable = settings.prioritizeSyllableSync;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: 360,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                      child: Column(
                        children: [
                          Text(
                            'Lyrics sources',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Drag handle to set priority order. Uncheck to disable source.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                              fontSize: 12,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12)),
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 440),
                        child: ReorderableListView(
                          shrinkWrap: true,
                          buildDefaultDragHandles: false,
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) newIndex--;
                            final list = List<String>.from(order);
                            final item = list.removeAt(oldIndex);
                            list.insert(newIndex, item);
                            settings.setLyricsSourceOrder(list);
                          },
                          children: [
                            for (int i = 0; i < order.length; i++)
                              ListTile(
                                key: ValueKey(order[i]),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                leading: ReorderableDragStartListener(
                                  index: i,
                                  child: Icon(
                                    Icons.drag_handle_rounded,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  order[i],
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  kSourceDetails[order[i]] ?? 'Lyrics database source',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: selected.contains(order[i])
                                    ? Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      )
                                    : null,
                                onTap: () {
                                  final checked = selected.contains(order[i]);
                                  if (checked && selected.length <= 1) return;
                                  final newSelected = checked
                                      ? (List<String>.from(selected)..remove(order[i]))
                                      : (List<String>.from(selected)..add(order[i]));
                                  settings.setLyricsSources(newSelected);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12)),
                    InkWell(
                      onTap: () {
                        settings.setPrioritizeSyllableSync(!prioritizeSyllable);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Prioritize syllable sync',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Hold out for word-by-word synced sources',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (prioritizeSyllable)
                              const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12)),
                    InkWell(
                      onTap: () {
                        settings.resetLyricsSourceSettings();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        child: Text(
                          'Reset to Default',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12)),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
