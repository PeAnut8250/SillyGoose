import 'dart:ui';
import 'package:flutter/material.dart';
import '../../data/api/audio_service.dart';
import '../../data/api/lyrics_service.dart';
import 'package:palette_generator/palette_generator.dart';

class FullLyricsScreen extends StatefulWidget {
  final Map<String, String> track;
  final List<LyricLine> lyrics;

  const FullLyricsScreen({Key? key, required this.track, required this.lyrics}) : super(key: key);

  @override
  State<FullLyricsScreen> createState() => _FullLyricsScreenState();
}

class _FullLyricsScreenState extends State<FullLyricsScreen> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;
  Color _dominantColor = const Color(0xFF1E1E1E);
  bool _isUserScrolling = false;
  DateTime? _lastManualScrollTime;

  @override
  void initState() {
    super.initState();
    _extractColor();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _extractColor() async {
    final imageUrl = widget.track['imageUrl'];
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final PaletteGenerator generator = await PaletteGenerator.fromImageProvider(
          NetworkImage(imageUrl),
        );
        if (mounted) {
          setState(() {
            _dominantColor = generator.dominantColor?.color ?? generator.mutedColor?.color ?? const Color(0xFF1E1E1E);
          });
        }
      } catch (_) {}
    }
  }

  int _getActiveIndex(Duration currentPosition) {
    if (widget.lyrics.isEmpty) return -1;

    for (int i = widget.lyrics.length - 1; i >= 0; i--) {
      if (widget.lyrics[i].time <= currentPosition) {
        return i;
      }
    }
    return -1;
  }

  void _scrollToActiveIndex(int index) {
    if (index < 0 || !mounted || !_scrollController.hasClients) return;
    
    // If the user manually scrolled recently, don't auto-scroll and steal their focus
    if (_isUserScrolling || (_lastManualScrollTime != null && DateTime.now().difference(_lastManualScrollTime!).inSeconds < 3)) {
      return;
    }

    // Approximate height calculation: 60px per line (adjust based on font size/padding)
    // We aim to center the active item (so subtract half the screen height)
    final double screenHeight = MediaQuery.of(context).size.height;
    final double targetOffset = (index * 60.0) - (screenHeight / 2) + 100; // 100 is roughly half the header height + padding
    
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    String artist = widget.track['artist'] ?? widget.track['subtitle'] ?? 'Unknown';
    String title = widget.track['title'] ?? 'Unknown';

    // Clean up YouTube titles for the UI (remove "(Official Video)", etc)
    title = title.replaceAll(RegExp(r'\(.*?\)'), '');
    title = title.replaceAll(RegExp(r'\[.*?\]'), '');
    title = title.trim();

    // If the title contains a dash (e.g. "Artist - Song"), extract the true artist and title
    if (title.contains(' - ')) {
      final parts = title.split(' - ');
      if (parts.length >= 2) {
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      }
    } else if (artist.isNotEmpty && artist != 'Unknown' && title.toLowerCase().startsWith(artist.toLowerCase())) {
      title = title.substring(artist.length).trim();
      if (title.startsWith('-')) {
        title = title.substring(1).trim();
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification && notification.dragDetails != null) {
            _isUserScrolling = true;
            _lastManualScrollTime = DateTime.now();
          } else if (notification is ScrollEndNotification) {
            _isUserScrolling = false;
            _lastManualScrollTime = DateTime.now();
          }
          return false;
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _dominantColor.withOpacity(0.8),
                _dominantColor.withOpacity(0.3),
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Artist & Song)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.track['imageUrl'] ?? '',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[800],
                            child: const Icon(Icons.music_note, color: Colors.white54),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              artist,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(8),
                              child: const Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Scrolling Lyrics
                Expanded(
                  child: ListenableBuilder(
                    listenable: AudioService(),
                    builder: (context, _) {
                      final position = AudioService().position;
                      final activeIndex = _getActiveIndex(position);
                      
                      if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
                        _lastActiveIndex = activeIndex;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToActiveIndex(activeIndex);
                        });
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          left: 20.0,
                          right: 20.0,
                          top: 40.0,
                          bottom: MediaQuery.of(context).size.height / 2, // Allow scrolling the last line to center
                        ),
                        itemCount: widget.lyrics.length,
                        itemBuilder: (context, index) {
                          final isPast = index < activeIndex;
                          final isActive = index == activeIndex;
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              style: TextStyle(
                                fontSize: isActive ? 28 : 24,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                                color: isActive 
                                    ? Colors.white 
                                    : Colors.white.withOpacity(0.3),
                                height: 1.3,
                              ),
                              child: Text(
                                widget.lyrics[index].text,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
