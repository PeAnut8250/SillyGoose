import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart' as asrv;
import 'package:audio_session/audio_session.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'youtube_service.dart';
import 'jiosaavn_service.dart';
import '../history_service.dart';
import '../settings_service.dart';

class AudioService extends asrv.BaseAudioHandler with asrv.QueueHandler, asrv.SeekHandler, ChangeNotifier {
  static late AudioService _instance;
  final JioSaavnService _saavnService = JioSaavnService();
  
  static Future<void> initGlobal() async {
    _instance = await asrv.AudioService.init(
      builder: () => AudioService._create(),
      config: const asrv.AudioServiceConfig(
        androidNotificationChannelId: 'com.sillygoose.music.channel.audio',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationOngoing: true,
        androidShowNotificationBadge: true,
      ),
    );
  }
  
  factory AudioService() => _instance;
  
  AudioPlayer _activePlayer = AudioPlayer();
  AudioPlayer _secondaryPlayer = AudioPlayer();
  Timer? _crossfadeTimer;
  bool _isCrossfading = false;
  
  AudioPlayer get _player => _activePlayer;
  
  final YoutubeService _ytService = YoutubeService();  
  List<Map<String, String>> _queueData = [];
  int _currentIndex = -1;
  bool _isLoading = false;
  int _currentRequestId = 0;
  bool _hasPlayedCurrentTrack = false;
  bool _isRestoredAndUnloaded = false;
  String? _preloadedTrackId;

  bool isShuffleEnabled = false;
  int repeatMode = 0; // 0 = off, 1 = repeat all, 2 = repeat one
  bool isAutoplayEnabled = true;

  HttpServer? _proxyServer;
  String? _currentTargetUrl;

  List<Map<String, String>> get queueList => List.unmodifiable(_queueData);
  int get currentIndex => _currentIndex;

  Map<String, String>? get currentTrack => 
      (_currentIndex >= 0 && _currentIndex < _queueData.length) 
          ? _queueData[_currentIndex] 
          : null;

  bool get isPlaying => _player.playing;
  bool get isLoading => _isLoading;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  double get volume => _player.volume;
  
  void setVolume(double val) {
    _player.setVolume(val);
    notifyListeners();
  }
  bool get hasNext => _currentIndex < _queueData.length - 1 || isAutoplayEnabled;
  bool get hasPrevious => _currentIndex > 0;
  
  Duration _lastPosition = Duration.zero;
  int _accumulatedMs = 0;

  void _flushAccumulatedTime() {
    if (_accumulatedMs > 0 && currentTrack != null) {
      HistoryService().recordPlayTime(currentTrack!, _accumulatedMs, false);
      _accumulatedMs = 0;
    }
  }

  AudioService._create() {
    _init();
  }

  Future<void> _init() async {
    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isMacOS)) {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
      }
    } catch (e) {
      print('Audio session not supported on this platform: $e');
    }
    
    // Load persisted state
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedQueueStr = prefs.getString('saved_queue');
      final savedIndex = prefs.getInt('saved_index');
      if (savedQueueStr != null && savedIndex != null) {
        final List<dynamic> decoded = jsonDecode(savedQueueStr);
        final queue = decoded.map((e) {
          final track = Map<String, String>.from(e as Map);
          // Ensure any accidentally saved streamUrls from previous versions are wiped
          track.remove('streamUrl');
          return track;
        }).toList();
        
        if (queue.isNotEmpty && savedIndex >= 0 && savedIndex < queue.length) {
          _queueData = queue;
          _currentIndex = savedIndex;
          _isRestoredAndUnloaded = true;
          // Notify listeners so UI updates immediately
          notifyListeners();
        }
      }
    } catch (e) {
      print('Failed to restore playback state: $e');
    }

    _startProxyServer();

    _setupListeners(_activePlayer);
    _setupListeners(_secondaryPlayer);
  }

  void _setupListeners(AudioPlayer p) {
    p.playerStateStream.listen((state) {
      if (p != _activePlayer) return;
      
      if (state.processingState == ProcessingState.completed && !_isLoading && !_isCrossfading) {
        _flushAccumulatedTime();
        if (_hasPlayedCurrentTrack) {
          if (repeatMode == 2) {
            p.seek(Duration.zero);
            p.play();
            return; // Prevent broadcasting completed
          } else {
            skipToNext();
            return; // Prevent broadcasting completed
          }
        } else {
          p.pause();
        }
      }
      
      _broadcastState();
      notifyListeners();
    });

    p.positionStream.listen((pos) {
      if (p != _activePlayer) return;
      
      if (pos.inSeconds > 0) {
        if (!_hasPlayedCurrentTrack) {
          _hasPlayedCurrentTrack = true;
          if (currentTrack != null) {
            HistoryService().recordPlayTime(currentTrack!, 0, true);
          }
        }
      }

      final delta = pos.inMilliseconds - _lastPosition.inMilliseconds;
      if (delta > 0 && delta < 2000) {
        _accumulatedMs += delta;
        if (_accumulatedMs >= 5000) {
          _flushAccumulatedTime();
        }
      }
      _lastPosition = pos;
      
      // Crossfade logic
      final crossfadeSecs = SettingsService().crossfade;
      if (crossfadeSecs > 0 && !_isCrossfading && p.duration != null) {
        final remaining = p.duration!.inMilliseconds - pos.inMilliseconds;
        if (remaining <= crossfadeSecs * 1000 && remaining > 0 && hasNext && repeatMode != 2) {
          _triggerCrossfade();
        }
      }
      
      _broadcastState();
      notifyListeners();
    });

    p.durationStream.listen((duration) {
      if (p != _activePlayer) return;
      
      if (Platform.isWindows || Platform.isLinux) return;
      if (duration != null && mediaItem.hasValue) {
        final currentMediaItem = mediaItem.value;
        if (currentMediaItem != null) {
          mediaItem.add(currentMediaItem.copyWith(duration: duration));
        }
      }
    });
  }

  Future<void> _triggerCrossfade() async {
    if (_isCrossfading || !hasNext) return;
    _isCrossfading = true;
    
    final crossfadeMs = (SettingsService().crossfade * 1000).toInt();

    // Swap active player references
    final fadingOutPlayer = _activePlayer;
    _activePlayer = _secondaryPlayer;
    _secondaryPlayer = fadingOutPlayer;
    
    // Pre-mute the new active player
    await _activePlayer.setVolume(0.0);
    
    // Start crossfade loop
    final steps = (Platform.isWindows || Platform.isLinux) ? 10 : 20;
    final stepDuration = crossfadeMs ~/ steps;
    final volumeStep = 1.0 / steps;
    
    // Start playing next track concurrently
    skipToNext();
    
    for (int i = 1; i <= steps; i++) {
      if (!_isCrossfading) break;
      await Future.delayed(Duration(milliseconds: stepDuration));
      
      await fadingOutPlayer.setVolume(1.0 - (i * volumeStep));
      if (_activePlayer.playing) {
        await _activePlayer.setVolume(i * volumeStep);
      }
    }
    
    if (_isCrossfading) {
      await fadingOutPlayer.stop();
      await _activePlayer.setVolume(1.0);
      _isCrossfading = false;
    }
  }

  void _broadcastState() {
    if (Platform.isWindows || Platform.isLinux) return;
    
    bool playing = _player.playing;
    asrv.AudioProcessingState processingState = const {
      ProcessingState.idle: asrv.AudioProcessingState.idle,
      ProcessingState.loading: asrv.AudioProcessingState.loading,
      ProcessingState.buffering: asrv.AudioProcessingState.buffering,
      ProcessingState.ready: asrv.AudioProcessingState.ready,
      ProcessingState.completed: asrv.AudioProcessingState.completed,
    }[_player.processingState]!;

    // CRITICAL FIX: If we are fetching the next track URL (which requires a network request),
    // force playing=true and state=buffering. This tricks the native audio_service into 
    // maintaining the CPU WakeLock while the screen is off! Without this, Android immediately 
    // puts the CPU to sleep during the gap between songs, freezing the network request.
    if (_isLoading || _isCrossfading) {
      playing = true;
      processingState = asrv.AudioProcessingState.buffering;
    }

    final currentState = playbackState.hasValue ? playbackState.value : asrv.PlaybackState();

    playbackState.add(currentState.copyWith(
      controls: [
        asrv.MediaControl.skipToPrevious,
        if (playing) asrv.MediaControl.pause else asrv.MediaControl.play,
        asrv.MediaControl.skipToNext,
      ],
      systemActions: const {
        asrv.MediaAction.seek,
        asrv.MediaAction.skipToNext,
        asrv.MediaAction.skipToPrevious,
        asrv.MediaAction.setShuffleMode,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: playing,
      shuffleMode: isShuffleEnabled ? asrv.AudioServiceShuffleMode.all : asrv.AudioServiceShuffleMode.none,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
    ));
  }

  Future<void> _startProxyServer() async {
    try {
      _proxyServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _proxyServer!.listen((HttpRequest request) async {
        String? targetUrl = _currentTargetUrl;
        if (request.uri.queryParameters.containsKey('url')) {
          targetUrl = request.uri.queryParameters['url']; // URL-encoded
        }

        if (targetUrl == null || targetUrl.isEmpty) {
          request.response.statusCode = 404;
          await request.response.close();
          return;
        }

        try {
          final client = HttpClient()..autoUncompress = false;
          // ALWAYS use GET to YouTube because YouTube CDNs frequently block HEAD requests with 403 Forbidden.
          final clientRequest = await client.getUrl(Uri.parse(targetUrl));
          
          // Spoof headers to prevent YouTube 403 Forbidden
          clientRequest.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
          
          if (request.headers.value('range') != null) {
            clientRequest.headers.set('Range', request.headers.value('range')!);
          }

          final clientResponse = await clientRequest.close();
          request.response.statusCode = clientResponse.statusCode;
          
          // CRITICAL FIX: Windows Media Foundation crashes if an MP4 is served with chunked encoding!
          // We must explicitly disable it and pass the exact content length from YouTube.
          request.response.headers.chunkedTransferEncoding = false;
          if (clientResponse.contentLength >= 0) {
            request.response.contentLength = clientResponse.contentLength;
          }
          
          clientResponse.headers.forEach((name, values) {
            for (var value in values) {
              // Ignore headers that Dart's HttpServer handles internally
              if (name.toLowerCase() != 'content-length' && name.toLowerCase() != 'transfer-encoding') {
                try { request.response.headers.add(name, value); } catch (_) {}
              }
            }
          });

          if (request.method == 'HEAD') {
            // The media engine only wants headers. Drain the body to free the socket!
            clientResponse.listen((_) {}).cancel(); 
            await request.response.close();
          } else {
            await clientResponse.pipe(request.response);
          }
        } catch (e) {
          print('Proxy error: $e');
          try {
            request.response.statusCode = 500;
            await request.response.close();
          } catch (_) {}
        }
      });
    } catch (e) {
      print('Failed to start audio proxy: $e');
    }
  }

  /// Exposes the proxy server to other parts of the app (like the Video Player)
  String getProxyUrl(String targetUrl) {
    if (_proxyServer == null) return targetUrl;
    return 'http://127.0.0.1:${_proxyServer!.port}/stream?url=${Uri.encodeComponent(targetUrl)}';
  }

  Future<void> _fetchMoreRelatedTracks(String videoId) async {
    var related = await _ytService.getUpNext(videoId);
    
    // Small Algorithm: Blend YouTube's contextual suggestions with the user's personal favorites!
    final topSongsStats = HistoryService().getTopSongs();
    List<Map<String, String>> userFavorites = topSongsStats.map((e) {
      return {
        'id': e['id'].toString(),
        'title': e['title'].toString(),
        'subtitle': e['artist'].toString(),
        'imageUrl': e['imageUrl']?.toString() ?? '',
        'type': 'song'
      };
    }).toList();
    
    userFavorites.shuffle();
    
    if (related.isEmpty && userFavorites.isNotEmpty) {
      // Ultimate Fallback: If YouTube fails completely, loop through the user's top history!
      related = userFavorites.take(20).toList();
    }
    
    if (related.isNotEmpty) {
      List<Map<String, String>> newTracks = [];
      
      // Take a much larger chunk (20 instead of 5) to make the queue longer
      final relatedToAdd = related.take(20).toList();
      
      int favIndex = 0;
      for (int i = 0; i < relatedToAdd.length; i++) {
        // Add the contextual song
        newTracks.add(relatedToAdd[i]);
        
        // Every 4th song, inject a personal favorite from the user's history to tailor the queue
        if (i % 4 == 0 && favIndex < userFavorites.length) {
          newTracks.add(userFavorites[favIndex]);
          favIndex++;
        }
      }
      
      // Filter out songs that are already in the queue to prevent immediate duplicates
      // AND aggressively filter out podcasts/comedy that might have slipped through from history!
      List<Map<String, String>> uniqueNewTracks = [];
      for (final track in newTracks) {
        final title = (track['title'] ?? '').toLowerCase();
        final subtitle = (track['subtitle'] ?? '').toLowerCase();
        
        bool isPodcast = title.contains('comedy') || title.contains('podcast') || 
                         title.contains('episode') || title.contains('interview') || 
                         title.contains('vlog') || title.contains('stand up') ||
                         subtitle.contains('comedy') || subtitle.contains('podcast') ||
                         subtitle.contains('set india');
                         
        if (isPodcast) continue;
        
        if (!_queueData.any((t) => t['id'] == track['id']) && 
            !uniqueNewTracks.any((t) => t['id'] == track['id'])) {
          uniqueNewTracks.add(track);
        }
      }
      
      if (isShuffleEnabled) {
        uniqueNewTracks.shuffle();
      }
      
      _queueData.addAll(uniqueNewTracks);
      notifyListeners();
      
      // Kick off background preloading for the newly added tracks!
      _preloadNextUrls();
    }
  }

  /// Silently pre-fetches YouTube streaming URLs for the next few tracks in the background
  /// and natively buffers the immediate next track so that skipping is completely instantaneous!
  Future<void> _preloadNextUrls() async {
    if (_currentIndex < 0) return;
    
    final startRequestId = _currentRequestId;
    
    // Preload the next 3 tracks
    for (int i = _currentIndex + 1; i <= _currentIndex + 3 && i < _queueData.length; i++) {
      if (_currentRequestId != startRequestId) return; // Abort if user skipped/clicked a new song
      
      if (_queueData[i]['streamUrl'] == null) {
        try {
          final title = _queueData[i]['title'] ?? '';
          final artist = _queueData[i]['subtitle'] ?? '';
          
          SaavnStream? saavnStream;
          String? ytUrl;

          await Future.wait([
            _saavnService.resolveTopStream(title, artist).then((value) => saavnStream = value).catchError((_) => null),
            _ytService.getAudioStreamUrl(_queueData[i]['id']!).then((value) => ytUrl = value).catchError((_) => null),
          ]);
          
          if (saavnStream != null) {
            _queueData[i]['streamUrl'] = saavnStream!.url;
            _queueData[i]['audioSource'] = 'JioSaavn';
            _queueData[i]['audioQuality'] = saavnStream!.kbps?.toString() ?? '320';
            _queueData[i]['audioCodec'] = 'AAC';
          } else if (ytUrl != null) {
            _queueData[i]['streamUrl'] = ytUrl!;
            _queueData[i]['audioSource'] = 'YouTube';
            _queueData[i]['audioQuality'] = '160';
            _queueData[i]['audioCodec'] = 'Opus';
          }
        } catch (_) {}
      }
      
      // Pre-buffer the immediate next track into the secondary player natively!
      if (i == _currentIndex + 1 && _queueData[i]['streamUrl'] != null && _preloadedTrackId != _queueData[i]['id']) {
        try {
          final streamUrl = _queueData[i]['streamUrl']!;
          final finalUrl = getProxyUrl(streamUrl);
          
          final audioSource = AudioSource.uri(
            Uri.parse(finalUrl),
            tag: _queueData[i]['id'],
          );
          
          await _secondaryPlayer.setAudioSource(audioSource);
          _secondaryPlayer.pause(); // Ensure it pre-buffers but doesn't play
          _preloadedTrackId = _queueData[i]['id'];
        } catch (e) {
          print('Failed to pre-buffer next track natively: $e');
        }
      }
    }
  }

  /// Replaces the current queue with a new list of tracks and starts playing from the given index.
  Future<void> playPlaylist(List<Map<String, String>> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    
    _queueData = List.from(tracks);
    _currentIndex = -1; // Reset so playTrack handles the index
    _saveState();
    
    await playTrack(tracks[startIndex]);
  }

  void addTrackNext(Map<String, String> track) {
    if (_queueData.isEmpty) {
      playTrack(track);
      return;
    }
    _queueData.insert(_currentIndex + 1, track);
    _saveState();
    notifyListeners();
  }

  void addTrackToQueue(Map<String, String> track) {
    if (_queueData.isEmpty) {
      playTrack(track);
      return;
    }
    _queueData.add(track);
    _saveState();
    notifyListeners();
  }


  Future<void> playTrack(Map<String, String> track) async {
    // Automatically upgrade blurry legacy YouTube thumbnails from history
    if (track['imageUrl'] != null && track['imageUrl']!.contains('default.jpg') && track['id'] != null) {
      track = Map<String, String>.from(track);
      track['imageUrl'] = 'https://i.ytimg.com/vi/${track['id']}/hqdefault.jpg';
    }

    _currentRequestId++;
    final requestId = _currentRequestId;
    
    try {
      // Determine if this is a new track or resuming
    bool isNewTrack = true;
    if (_queueData.isNotEmpty && _currentIndex >= 0 && _currentIndex < _queueData.length) {
      if (_queueData[_currentIndex]['id'] == track['id'] && !_isRestoredAndUnloaded) {
        isNewTrack = false;
      }
    }

    if (isNewTrack) {
      // Flush any remaining accumulated time from previous track
      _flushAccumulatedTime();

      // Add to queue if not present
      if (!_queueData.any((t) => t['id'] == track['id'])) {
        _queueData.add(track);
        _currentIndex = _queueData.length - 1;
      } else {
        _currentIndex = _queueData.indexWhere((t) => t['id'] == track['id']);
      }
      
      _isLoading = true;
      _hasPlayedCurrentTrack = false;
      _lastPosition = Duration.zero;
      _accumulatedMs = 0;
      _isRestoredAndUnloaded = false;
      _preloadedTrackId = null; // Clear preloaded state as we are manually loading a track
      _saveState();
      notifyListeners();
      
      // Pause the previous song immediately so it doesn't keep playing 
      // while we wait for YouTube to fetch the new stream URL.
      // (Do not call stop() here, as it dismisses the Android notification!)
      if (_player.playing) {
        await _player.pause();
      }

      // Check if we already pre-fetched the URL in the background!
      String? streamUrl = _queueData[_currentIndex]['streamUrl'];
      
      if (streamUrl == null) {
        final title = track['title'] ?? '';
        final artist = track['subtitle'] ?? '';
        
        SaavnStream? saavnStream;
        String? ytUrl;

        await Future.wait([
          _saavnService.resolveTopStream(title, artist).then((value) => saavnStream = value).catchError((_) => null),
          _ytService.getAudioStreamUrl(track['id']!).then((value) => ytUrl = value).catchError((_) => null),
        ]);
        
        // IMMEDIATE check: If the user clicked Next while we were loading, abort this outdated request
        // BEFORE it can corrupt the queue data with its stale results!
        if (requestId != _currentRequestId) return;
        
        // Find the actual index of this track instead of relying on the global _currentIndex 
        // which might have been modified by a concurrent request.
        final trackIndex = _queueData.indexWhere((t) => t['id'] == track['id']);
        if (trackIndex == -1) return;
        
        if (saavnStream != null) {
          streamUrl = saavnStream!.url;
          _queueData[trackIndex]['streamUrl'] = streamUrl!;
          _queueData[trackIndex]['audioSource'] = 'JioSaavn';
          _queueData[trackIndex]['audioQuality'] = saavnStream!.kbps?.toString() ?? '320';
          _queueData[trackIndex]['audioCodec'] = 'AAC';
        } else if (ytUrl != null) {
          streamUrl = ytUrl!;
          _queueData[trackIndex]['streamUrl'] = streamUrl!;
          _queueData[trackIndex]['audioSource'] = 'YouTube';
          _queueData[trackIndex]['audioQuality'] = '160';
          _queueData[trackIndex]['audioCodec'] = 'Opus';
        }
      }
      
      // Add to history
      HistoryService().addTrack(track);
      
      if (streamUrl != null) {
        _currentTargetUrl = streamUrl;
        final proxyUrl = getProxyUrl(streamUrl);
        
        // Explicitly stop the previous track to reset the WMF state machine on Windows
        // WARNING: Do not call stop() if the player is idle, or WMF will break and ignore the next play()!
        if ((Platform.isWindows || Platform.isLinux) && _player.processingState != ProcessingState.idle) {
          await _player.stop();
        }
        
        // Add MediaItem metadata for background playback notifications!
        final item = asrv.MediaItem(
          id: track['id']!,
          title: track['title'] ?? 'Unknown Track',
          artist: track['subtitle'] ?? 'Unknown Artist',
          artUri: track['imageUrl'] != null ? Uri.parse(track['imageUrl']!) : null,
          duration: _player.duration,
        );
        
        if (!Platform.isWindows && !Platform.isLinux) {
          mediaItem.add(item);
        }
        
        final finalUrl = getProxyUrl(streamUrl);
        
        final audioSource = AudioSource.uri(
          Uri.parse(finalUrl),
          tag: track['id'],
        );
        
        await _player.setAudioSource(audioSource).timeout(const Duration(seconds: 15));
        
        // Check AGAIN after setAudioSource because setting the source takes time 
        // and the user might have rapidly clicked Next during the network buffering!
        if (requestId != _currentRequestId) return;
        
        _isLoading = false;
        notifyListeners();
        
        // Queue the play command immediately instead of waiting for buffering
        await _player.play();
        
        // Auto-fetch queue
        if (isAutoplayEnabled && _currentIndex >= _queueData.length - 2) {
          _fetchMoreRelatedTracks(track['id']!);
        } else {
          // If we didn't need to fetch more tracks, just ensure the next few are preloaded
          _preloadNextUrls();
        }
      } else {
        print('Could not extract stream URL for track');
        _isLoading = false;
        notifyListeners();
      }
    } else {
      // The track is already the current one. Just play it if it's paused.
      if (!_player.playing) {
        _player.play();
      }
    }
    } catch (e) {
      print('Error playing track: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  Future<void> play() async {
    if (_isRestoredAndUnloaded && currentTrack != null) {
      playTrack(currentTrack!);
      return;
    }
    _player.play();
  }

  @override
  Future<void> setShuffleMode(asrv.AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode == asrv.AudioServiceShuffleMode.all && !isShuffleEnabled) {
      toggleShuffle();
    } else if (shuffleMode == asrv.AudioServiceShuffleMode.none && isShuffleEnabled) {
      toggleShuffle();
    }
  }

  @override
  Future<void> pause() async {
    _player.pause();
  }
  
  void togglePlayPause() {
    if (_player.playing) {
      pause();
    } else {
      play();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    _player.seek(position);
  }
  
  void toggleShuffle() {
    isShuffleEnabled = !isShuffleEnabled;
    
    // If shuffle was turned on, instantly randomize the upcoming tracks in the queue
    if (isShuffleEnabled && _currentIndex >= 0 && _currentIndex < _queueData.length - 1) {
      final upcomingTracks = _queueData.sublist(_currentIndex + 1);
      upcomingTracks.shuffle();
      _queueData.replaceRange(_currentIndex + 1, _queueData.length, upcomingTracks);
      
      // Update the background preloader for the new next track
      _preloadNextUrls();
    }
    
    notifyListeners();
  }

  void toggleRepeat() {
    repeatMode = (repeatMode + 1) % 3;
    notifyListeners();
  }

  void toggleAutoplay() {
    isAutoplayEnabled = !isAutoplayEnabled;
    notifyListeners();
  }

  @override
  Future<void> skipToNext() async {
    if (_currentIndex < _queueData.length - 1) {
      final nextTrack = _queueData[_currentIndex + 1];
      
      // Perform instantaneous player swap if track is already pre-buffered!
      if (_preloadedTrackId != null && _preloadedTrackId == nextTrack['id']) {
        final temp = _activePlayer;
        _activePlayer = _secondaryPlayer;
        _secondaryPlayer = temp;
        
        _secondaryPlayer.stop(); // Stop old active player
        _activePlayer.play(); // Play instantly!
        _currentIndex++;
        _hasPlayedCurrentTrack = false;
        _preloadedTrackId = null;
        _isLoading = false;
        
        HistoryService().addTrack(nextTrack);
        
        final item = asrv.MediaItem(
          id: nextTrack['id']!,
          title: nextTrack['title'] ?? 'Unknown Track',
          artist: nextTrack['subtitle'] ?? 'Unknown Artist',
          artUri: nextTrack['imageUrl'] != null ? Uri.parse(nextTrack['imageUrl']!) : null,
          duration: _activePlayer.duration,
        );
        
        if (!Platform.isWindows && !Platform.isLinux) {
          mediaItem.add(item);
        }
        
        _saveState();
        notifyListeners();
        
        // Immediately start buffering the NEXT next track, or fetch more if autoplay is enabled
        if (isAutoplayEnabled && _currentIndex >= _queueData.length - 2) {
          _fetchMoreRelatedTracks(nextTrack['id']!);
        } else {
          _preloadNextUrls();
        }
      } else {
        // Fallback to slow loading if we skipped too fast
        playTrack(nextTrack);
      }
    } else if (isAutoplayEnabled && currentTrack != null) {
      // We are at the end of the queue, but autoplay is enabled. 
      // Force fetch more tracks explicitly before skipping!
      _isLoading = true;
      notifyListeners();
      
      try {
        await _fetchMoreRelatedTracks(currentTrack!['id']!);
      } catch (e) {
        print('Error fetching more tracks in skipToNext: $e');
      }
      
      if (_currentIndex < _queueData.length - 1) {
        playTrack(_queueData[_currentIndex + 1]);
      } else {
        _isLoading = false;
        notifyListeners();
      }
    } else if (repeatMode == 1 && _queueData.isNotEmpty) {
      playTrack(_queueData[0]);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (hasPrevious) {
      playTrack(_queueData[_currentIndex - 1]);
    }
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _queueData.removeAt(oldIndex);
    _queueData.insert(newIndex, item);
    
    // Update currentIndex to keep track of the playing song
    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
    
    _saveState();
    notifyListeners();
  }

  void removeTrack(int index) {
    if (index >= 0 && index < _queueData.length) {
      _queueData.removeAt(index);
      if (index < _currentIndex) {
        _currentIndex--;
      } else if (index == _currentIndex) {
        // If the removed track was the current one, play the next one
        if (hasNext) {
          playTrack(_queueData[_currentIndex]);
        } else {
          _player.stop();
          _currentIndex = -1;
        }
      }
      _saveState();
      notifyListeners();
    }
  }

  void clearQueue() {
    if (_currentIndex >= 0 && _queueData.isNotEmpty) {
      final current = _queueData[_currentIndex];
      _queueData.clear();
      _queueData.add(current);
      _currentIndex = 0;
      _saveState();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
  
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Strip out the streamUrl before saving to prevent loading expired YouTube links!
      final cleanQueue = _queueData.map((track) {
        final cleanTrack = Map<String, String>.from(track);
        cleanTrack.remove('streamUrl');
        return cleanTrack;
      }).toList();
      
      await prefs.setString('saved_queue', jsonEncode(cleanQueue));
      await prefs.setInt('saved_index', _currentIndex);
    } catch (e) {
      print('Error saving playback state: $e');
    }
  }
}
