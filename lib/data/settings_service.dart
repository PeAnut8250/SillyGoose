import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;
  bool _initialized = false;

  final ValueNotifier<String> themeNotifier = ValueNotifier<String>('Dynamic');

  // Booleans
  bool downloadOverWifi = true;
  bool automix = false;
  bool skipSilence = false;
  bool spatialAudio = false;
  bool showStats = true;
  bool stopVideoConversion = false;
  bool reduceAnimation = false;
  bool reduceBlur = false;
  bool fullScreenCover = true;
  bool animatedCover = true;
  bool liquidGlass = true;
  bool syncedLyrics = true;
  bool warnOutGenres = true;
  bool playNextOnSwipe = false;
  bool dontRepeatSession = false;
  bool stopMusicOnClose = false;
  bool hideVolumeBar = false;
  bool rickysAddon = true;
  bool jioSaavn = true;

  // Doubles / Strings
  double crossfade = 0.0;
  double songCacheLimit = 512.0;
  String downloadQuality = 'Lossless';
  String wifiQuality = 'High';
  String mobileDataQuality = 'High';
  String theme = 'Dynamic';
  String lyricsSources = 'YouTube, Musixmatch...';
  String appLanguage = 'English';
  String settingsBgColor = '#1C1C1C';
  double settingsGlassBlur = 0.0;
  double settingsIconOpacity = 0.35;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    
    // Force defaults for full screen and animated cover on first run after this update
    if (_prefs.getBool('v2_defaults_set') != true) {
      _prefs.setBool('fullScreenCover', true);
      _prefs.setBool('animatedCover', true);
      _prefs.setBool('v2_defaults_set', true);
    }
    
    downloadOverWifi = _prefs.getBool('downloadOverWifi') ?? true;
    automix = _prefs.getBool('automix') ?? false;
    skipSilence = _prefs.getBool('skipSilence') ?? false;
    spatialAudio = _prefs.getBool('spatialAudio') ?? false;
    showStats = _prefs.getBool('showStats') ?? true;
    stopVideoConversion = _prefs.getBool('stopVideoConversion') ?? false;
    reduceAnimation = _prefs.getBool('reduceAnimation') ?? false;
    reduceBlur = _prefs.getBool('reduceBlur') ?? false;
    fullScreenCover = _prefs.getBool('fullScreenCover') ?? true;
    animatedCover = _prefs.getBool('animatedCover') ?? true;
    liquidGlass = _prefs.getBool('liquidGlass') ?? true;
    syncedLyrics = _prefs.getBool('syncedLyrics') ?? true;
    warnOutGenres = _prefs.getBool('warnOutGenres') ?? true;
    playNextOnSwipe = _prefs.getBool('playNextOnSwipe') ?? false;
    dontRepeatSession = _prefs.getBool('dontRepeatSession') ?? false;
    stopMusicOnClose = _prefs.getBool('stopMusicOnClose') ?? false;
    hideVolumeBar = _prefs.getBool('hideVolumeBar') ?? false;
    rickysAddon = _prefs.getBool('rickysAddon') ?? true;
    jioSaavn = _prefs.getBool('jioSaavn') ?? true;

    crossfade = _prefs.getDouble('crossfade') ?? 0.0;
    songCacheLimit = _prefs.getDouble('songCacheLimit') ?? 512.0;
    settingsGlassBlur = _prefs.getDouble('settingsGlassBlur') ?? 0.0;
    settingsIconOpacity = _prefs.getDouble('settingsIconOpacity') ?? 0.35;
    
    downloadQuality = _prefs.getString('downloadQuality') ?? 'Lossless';
    wifiQuality = _prefs.getString('wifiQuality') ?? 'High';
    mobileDataQuality = _prefs.getString('mobileDataQuality') ?? 'High';
    theme = _prefs.getString('theme') ?? 'Dynamic';
    settingsBgColor = _prefs.getString('settingsBgColor') ?? '#1C1C1C';
    themeNotifier.value = theme;
    
    _initialized = true;
    notifyListeners();
  }

  void setBool(String key, bool value) {
    _prefs.setBool(key, value);
    switch (key) {
      case 'downloadOverWifi': downloadOverWifi = value; break;
      case 'automix': automix = value; break;
      case 'skipSilence': skipSilence = value; break;
      case 'spatialAudio': spatialAudio = value; break;
      case 'showStats': showStats = value; break;
      case 'stopVideoConversion': stopVideoConversion = value; break;
      case 'reduceAnimation': reduceAnimation = value; break;
      case 'reduceBlur': reduceBlur = value; break;
      case 'fullScreenCover': fullScreenCover = value; break;
      case 'animatedCover': animatedCover = value; break;
      case 'liquidGlass': liquidGlass = value; break;
      case 'syncedLyrics': syncedLyrics = value; break;
      case 'warnOutGenres': warnOutGenres = value; break;
      case 'playNextOnSwipe': playNextOnSwipe = value; break;
      case 'dontRepeatSession': dontRepeatSession = value; break;
      case 'stopMusicOnClose': stopMusicOnClose = value; break;
      case 'hideVolumeBar': hideVolumeBar = value; break;
      case 'rickysAddon': rickysAddon = value; break;
      case 'jioSaavn': jioSaavn = value; break;
    }
    notifyListeners();
  }

  void setDouble(String key, double value) {
    _prefs.setDouble(key, value);
    switch (key) {
      case 'crossfade': crossfade = value; break;
      case 'songCacheLimit': songCacheLimit = value; break;
      case 'settingsGlassBlur': settingsGlassBlur = value; break;
      case 'settingsIconOpacity': settingsIconOpacity = value; break;
    }
    notifyListeners();
  }

  void setString(String key, String value) {
    _prefs.setString(key, value);
    switch (key) {
      case 'downloadQuality': downloadQuality = value; break;
      case 'wifiQuality': wifiQuality = value; break;
      case 'mobileDataQuality': mobileDataQuality = value; break;
      case 'theme': 
        theme = value; 
        themeNotifier.value = value;
        break;
      case 'settingsBgColor': settingsBgColor = value; break;
      case 'lyricsSources': lyricsSources = value; break;
      case 'appLanguage': appLanguage = value; break;
    }
    notifyListeners();
  }
}
