import 'package:flutter/material.dart';
import '../../data/api/audio_service.dart';
import '../../data/api/youtube_service.dart';
import '../../data/settings_service.dart';
import '../../data/history_service.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'thin_slider.dart';
import 'dart:ui';
import '../widgets/song_options_menu.dart';
import 'synced_lyrics_view.dart';
import 'package:flutter/cupertino.dart';
import '../screens/artist_screen.dart';
import '../screens/queue_screen.dart';
import '../widgets/audio_device_dropdown.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  OverlayEntry? _volumeOverlay;
  VideoPlayerController? _videoController;
  String? _currentVideoId;
  bool _isVideoActive = false;
  final YoutubeService _ytService = YoutubeService();
  
  double _dragDistanceX = 0;
  double _dragDistanceY = 0;
  bool _isPopping = false;

  String? _uiTrackId;

  @override
  void initState() {
    super.initState();
    _uiTrackId = AudioService().currentTrack?['id'];
    _checkVideoTrack();
    AudioService().addListener(_onAudioServiceUpdate);
    SettingsService().addListener(_checkVideoTrack);
  }

  void _onAudioServiceUpdate() {
    _checkVideoTrack();
    final newTrackId = AudioService().currentTrack?['id'];
    if (newTrackId != _uiTrackId) {
      if (mounted) {
        setState(() {
          _uiTrackId = newTrackId;
        });
      }
    }
  }

  void _checkVideoTrack() {
    final track = AudioService().currentTrack;
    final wantsVideo = SettingsService().fullScreenCover && 
                       SettingsService().animatedCover && 
                       !SettingsService().reduceAnimation && 
                       track != null;
    
    if (track?['id'] != _currentVideoId || wantsVideo != _isVideoActive) {
      _currentVideoId = track?['id'];
      _isVideoActive = wantsVideo;
      
      _disposeVideo();
      
      if (wantsVideo && _currentVideoId != null) {
        _initVideo(_currentVideoId!);
      }
    }
  }

  Future<void> _initVideo(String videoId) async {
    try {
      final track = AudioService().currentTrack;
      if (track == null) return;
      
      final artist = track['artist'] ?? '';
      final title = track['title'] ?? '';
      
      print('DEBUG: Fetching background video URL for $artist - $title');
      
      // Instead of getting the static image from the "Official Audio" video ID,
      // we explicitly search for the "Music Video" version just for the background!
      final url = await _ytService.getBackgroundVideoUrl(artist, title);
      if (url == null) {
        print('DEBUG: URL is null for $videoId, videoStreams might be empty!');
        return;
      }
      
      if (url != null && mounted && _currentVideoId == videoId && _isVideoActive) {
        VideoPlayerController controller;

        if (Platform.isWindows) {
          // Windows Media Foundation completely ignores HTTP headers (like User-Agent) when streaming natively,
          // which causes YouTube to reject the connection with a 403 Forbidden.
          // To bypass this and create a true Spotify Canvas, we securely download it to a local cache file.
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/canvas_v2_$videoId.mp4');
          
          if (!await file.exists()) {
            print('DEBUG: Downloading video cache to ${file.path}');
            final client = HttpClient();
            final request = await client.getUrl(Uri.parse(url));
            request.headers.add('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
            final response = await request.close();
            
            final sink = file.openWrite();
            await for (final chunk in response) {
              if (!mounted || _currentVideoId != videoId || !_isVideoActive) {
                print('DEBUG: Aborting download for $videoId as track changed');
                await sink.close();
                if (await file.exists()) {
                  await file.delete();
                }
                return;
              }
              sink.add(chunk);
            }
            await sink.close();
            print('DEBUG: Download complete, file size: ${await file.length()}');
          } else {
            print('DEBUG: Using existing video cache: ${file.path}');
          }
          
          if (!mounted || _currentVideoId != videoId || !_isVideoActive) return;
          controller = VideoPlayerController.file(
            file,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        } else {
          // Android and iOS fully support streaming with HTTP headers!
          // We can stream instantly without downloading the entire file first.
          print('DEBUG: Streaming natively on mobile');
          controller = VideoPlayerController.networkUrl(
            Uri.parse(url),
            httpHeaders: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'},
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        }

        print('DEBUG: Initializing VideoPlayerController');
        await controller.initialize();
        print('DEBUG: Controller initialized successfully. Duration: ${controller.value.duration}');
        controller.setVolume(0);
        
        // The user wants a much longer animated background! 
        // We set it to natively loop the entire music video flawlessly!
        controller.setLooping(true); 
        
        if (mounted && _currentVideoId == videoId && _isVideoActive) {
          setState(() {
            _videoController = controller;
          });
          controller.play();
          print('DEBUG: Video is playing on screen!');
        } else {
          controller.dispose();
        }
      }
    } catch (e) {
      print('DEBUG Error init video: $e');
    }
  }

  void _disposeVideo({bool isDisposing = false}) {
    _videoController?.dispose();
    _videoController = null;
    if (mounted && !isDisposing) setState(() {});
  }

  @override
  void dispose() {
    AudioService().removeListener(_onAudioServiceUpdate);
    SettingsService().removeListener(_checkVideoTrack);
    _disposeVideo(isDisposing: true);
    _volumeOverlay?.remove();
    _volumeOverlay = null;
    super.dispose();
  }

  void _toggleVolumeSlider(BuildContext buttonContext) {
    if (_volumeOverlay != null) {
      _volumeOverlay!.remove();
      _volumeOverlay = null;
      return;
    }

    final RenderBox renderBox = buttonContext.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    _volumeOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _volumeOverlay?.remove();
                  _volumeOverlay = null;
                },
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: position.dx + (renderBox.size.width - 36) / 2,
              top: position.dy - 120,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: 120,
                  width: 36,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ListenableBuilder(
                    listenable: AudioService(),
                    builder: (context, _) {
                      return _ThinVolumeSlider(
                        value: AudioService().volume,
                        onChanged: (val) {
                          AudioService().setVolume(val);
                        },
                      );
                    }
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(buttonContext).insert(_volumeOverlay!);
  }


  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final track = AudioService().currentTrack;
        if (track == null) return const SizedBox.shrink();

        final isDynamic = SettingsService().theme == 'Dynamic' || SettingsService().theme == 'Shuffle Dynamic';
        final isCool = SettingsService().theme == 'Cool';
        final fgColor = isDynamic || isCool ? Colors.white : Theme.of(context).colorScheme.onSurface;

        return Scaffold(
          backgroundColor: isDynamic || isCool ? Colors.transparent : null,
          body: GestureDetector(
            onPanStart: (details) {
              _dragDistanceX = 0;
              _dragDistanceY = 0;
              _isPopping = false;
            },
            onPanUpdate: (details) {
              _dragDistanceX += details.delta.dx;
              _dragDistanceY += details.delta.dy;
              
              // Make swipe down to close easier (threshold 70 instead of 100)
              if (_dragDistanceY > 70 && !_isPopping) {
                _isPopping = true;
                Navigator.of(context).pop();
              }
            },
            onPanEnd: (details) {
              if (_isPopping) return;
              
              // Require a much firmer horizontal swipe to skip (threshold 180 instead of 100)
              if (_dragDistanceX.abs() > _dragDistanceY.abs() && _dragDistanceX.abs() > 180) {
                if (_dragDistanceX < 0) {
                  AudioService().skipToNext();
                } else {
                  AudioService().skipToPrevious();
                }
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
              // Base solid background so it doesn't turn transparent while loading
              Container(color: isDynamic || isCool ? Colors.black : null),
              
              if (isCool && !SettingsService().reduceAnimation)
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF273833), // Dark teal
                        Color(0xFF281816), // Dark brownish red
                        Color(0xFF121212), // Deep black
                      ],
                      stops: [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              
              if (isDynamic && !SettingsService().reduceAnimation) ...[
                // Background (either blurred, full-screen clear, or animated video)
                if (_videoController != null && _videoController!.value.isInitialized)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  )
                else
                  Image.network(
                    track['imageUrl']!,
                    fit: BoxFit.cover,
                    cacheWidth: SettingsService().fullScreenCover ? null : 8,
                  ),
                if (!SettingsService().fullScreenCover)
                  Container(
                    color: Colors.black.withOpacity(0.7),
                  ),
                if (SettingsService().fullScreenCover)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.8),
                        ],
                        stops: const [0.0, 0.8],
                      ),
                    ),
                  ),
              ],
          
          SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                // Drag handle
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: fgColor.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 8),
                const AudioDeviceDropdown(),
                Builder(
                  builder: (context) {
                    final audioQuality = track['audioQuality'] ?? '160';
                    final audioCodec = track['audioCodec'] ?? 'Opus';
                    final sampleRate = audioCodec == 'AAC' ? '44.1 kHz' : '48.0 kHz';
                    final currentKey = ValueKey('${audioCodec}_${track['id']}');
                    
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      switchInCurve: Curves.easeInOutCubic,
                      switchOutCurve: Curves.easeInOutCubic,
                      transitionBuilder: (child, animation) {
                        final isIncoming = child.key == currentKey;
                        final slideTween = Tween<Offset>(
                          begin: Offset(isIncoming ? 1.0 : -1.0, 0.0),
                          end: Offset.zero,
                        );
                        return SlideTransition(
                          position: slideTween.animate(animation),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        key: currentKey,
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          "$audioCodec · $audioQuality kbps · $sampleRate · Stereo",
                          style: TextStyle(
                            color: fgColor.withOpacity(0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }
                ),
                
                const Spacer(flex: 1),
                
                // Artwork (Stays the same size, unless fullScreenCover is true)
                if (!SettingsService().fullScreenCover)
                  Flexible(
                    flex: 4,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.network(
                            track['imageUrl']!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                
                const Spacer(flex: 1),
                
                // Title and Artist
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track['title']!,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: fgColor,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                // The player is often a full screen modal, so pushing onto its context
                                // will overlay the artist screen on top of the player.
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => ArtistScreen(
                                      artistData: {
                                        'title': track['subtitle']!,
                                        'subtitle': 'Artist',
                                        // We don't have the artist's actual profile pic here, 
                                        // so we gracefully fallback to the track's image
                                        'imageUrl': track['imageUrl']!,
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                track['subtitle']!,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: fgColor.withOpacity(0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_horiz),
                        color: fgColor,
                        onPressed: () {
                          showSongOptionsMenu(context, track);
                        },
                      ),
                    ],
                  ),
                ),
                
                // Synced Lyrics View (Only visible if lyrics are found)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: SyncedLyricsView(track: track),
                ),
                
                // Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: ListenableBuilder(
                    listenable: AudioService(),
                    builder: (context, _) {
                      final position = AudioService().position;
                      final duration = AudioService().duration;
                      
                      return Column(
                        children: [
                          ThinSlider(
                            position: position,
                            duration: duration,
                            onChanged: (newPosition) {
                              AudioService().seek(newPosition);
                            },
                          ),
                          const SizedBox(height: 8),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: TextStyle(
                                      color: fgColor.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '-' + _formatDuration(duration - position),
                                    style: TextStyle(
                                      color: fgColor.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                switchInCurve: Curves.easeInOutCubic,
                                switchOutCurve: Curves.easeInOutCubic,
                                transitionBuilder: (child, animation) {
                                  final isIncoming = child.key == ValueKey('hi_quality_${track['id']}');
                                  final slideTween = Tween<Offset>(
                                    begin: Offset(isIncoming ? 1.0 : -1.0, 0.0),
                                    end: Offset.zero,
                                  );
                                  return SlideTransition(
                                    position: slideTween.animate(animation),
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Row(
                                  key: ValueKey('hi_quality_${track['id']}'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.headphones, color: fgColor.withOpacity(0.5), size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Hi-Quality",
                                      style: TextStyle(
                                        color: fgColor.withOpacity(0.5),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Transport Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ListenableBuilder(
                        listenable: AudioService(),
                        builder: (context, _) {
                          final hasPrevious = AudioService().hasPrevious;
                          return IconButton(
                            icon: const Icon(Icons.fast_rewind_rounded),
                            color: hasPrevious ? fgColor : fgColor.withOpacity(0.3),
                            iconSize: 42,
                            onPressed: hasPrevious ? () {
                              AudioService().skipToPrevious();
                            } : null,
                          );
                        }
                      ),
                      const SizedBox(width: 32),
                      ListenableBuilder(
                        listenable: AudioService(),
                        builder: (context, _) {
                          final isPlaying = AudioService().isPlaying;
                          final isLoading = AudioService().isLoading;
                          
                          if (isLoading) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                                ),
                              ),
                            );
                          }
                          
                          return IconButton(
                            icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                            color: fgColor,
                            iconSize: 56,
                            onPressed: () {
                              AudioService().togglePlayPause();
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 32),
                      ListenableBuilder(
                        listenable: AudioService(),
                        builder: (context, _) {
                          final hasNext = AudioService().hasNext;
                          return IconButton(
                            icon: const Icon(Icons.fast_forward_rounded),
                            color: hasNext ? fgColor : fgColor.withOpacity(0.3),
                            iconSize: 42,
                            onPressed: hasNext ? () {
                              AudioService().skipToNext();
                            } : null,
                          );
                        }
                      ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Bottom tools (Shuffle, Repeat, Autoplay, Queue)
                ListenableBuilder(
                  listenable: Listenable.merge([AudioService(), HistoryService()]),
                  builder: (context, _) {
                    final audioService = AudioService();
                    final currentTrack = audioService.currentTrack;
                    final isLiked = currentTrack != null && HistoryService().isLiked(currentTrack['id']!);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                            color: isLiked ? const Color(0xFFE91E63) : fgColor,
                            onPressed: () {
                              if (currentTrack != null) {
                                HistoryService().toggleLike(currentTrack);
                                final action = isLiked ? 'Removed from' : 'Added to';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$action Liked Songs'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.shuffle_rounded),
                            color: audioService.isShuffleEnabled ? fgColor : fgColor.withOpacity(0.4),
                            onPressed: () => audioService.toggleShuffle(),
                          ),
                          IconButton(
                            icon: Icon(audioService.repeatMode == 2 ? Icons.repeat_one_rounded : Icons.repeat_rounded),
                            color: audioService.repeatMode != 0 ? fgColor : fgColor.withOpacity(0.4),
                            onPressed: () => audioService.toggleRepeat(),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: audioService.isAutoplayEnabled ? fgColor.withOpacity(0.15) : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.all_inclusive_rounded),
                              color: audioService.isAutoplayEnabled ? fgColor : fgColor.withOpacity(0.4),
                              onPressed: () => audioService.toggleAutoplay(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.queue_music_rounded),
                            color: fgColor.withOpacity(0.7),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => const FractionallySizedBox(
                                  heightFactor: 0.6,
                                  child: QueueScreen(),
                                ),
                              );
                            },
                          ),
                          if (!SettingsService().hideVolumeBar)
                            Builder(
                              builder: (buttonContext) {
                                return IconButton(
                                  icon: Icon(
                                    AudioService().volume == 0
                                        ? CupertinoIcons.speaker_slash_fill
                                        : CupertinoIcons.speaker_2_fill,
                                  ),
                                  color: fgColor.withOpacity(0.7),
                                  onPressed: () {
                                    _toggleVolumeSlider(buttonContext);
                                  },
                                );
                              }
                            ),
                        ],
                      ),
                    );
                  }
                ),
                
                const SizedBox(height: 32),
              ],
            ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
},
    );
  }
}

class _ThinVolumeSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _ThinVolumeSlider({required this.value, required this.onChanged});

  @override
  State<_ThinVolumeSlider> createState() => _ThinVolumeSliderState();
}

class _ThinVolumeSliderState extends State<_ThinVolumeSlider> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    final double value = _isDragging ? _dragValue : widget.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double height = constraints.maxHeight;
        final double width = _isDragging ? 8.0 : 2.0;
        final double fraction = value.clamp(0.0, 1.0);

        return GestureDetector(
          onVerticalDragStart: (details) {
            setState(() {
              _isDragging = true;
              _dragValue = 1.0 - (details.localPosition.dy / height).clamp(0.0, 1.0);
            });
            widget.onChanged(_dragValue);
          },
          onVerticalDragUpdate: (details) {
            setState(() {
              _dragValue = 1.0 - (details.localPosition.dy / height).clamp(0.0, 1.0);
            });
            widget.onChanged(_dragValue);
          },
          onVerticalDragEnd: (details) {
            setState(() {
              _isDragging = false;
            });
          },
          onTapDown: (details) {
            setState(() {
              _isDragging = true;
              _dragValue = 1.0 - (details.localPosition.dy / height).clamp(0.0, 1.0);
            });
            widget.onChanged(_dragValue);
          },
          onTapUp: (details) {
            setState(() {
              _isDragging = false;
            });
          },
          child: Container(
            width: 36, // Touch target width
            color: Colors.transparent,
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              width: width,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(width / 2),
              ),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  FractionallySizedBox(
                    heightFactor: fraction,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(width / 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
