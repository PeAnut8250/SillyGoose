import 'package:flutter/material.dart';
import '../../data/api/audio_service.dart';
import '../../data/api/lyrics_service.dart';
import 'full_lyrics_screen.dart';
import '../../data/api/lyrics_service.dart';

class SyncedLyricsView extends StatefulWidget {
  final Map<String, String> track;

  const SyncedLyricsView({Key? key, required this.track}) : super(key: key);

  @override
  _SyncedLyricsViewState createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  List<LyricLine>? _lyrics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track['id'] != widget.track['id']) {
      _fetchLyrics();
    }
  }

  Future<void> _fetchLyrics() async {
    setState(() {
      _isLoading = true;
      _lyrics = null;
    });

    String artist = widget.track['artist'] ?? '';
    String title = widget.track['title'] ?? '';

    // Clean up YouTube titles (e.g. remove "(Official Video)", "[Lyric Video]", etc)
    title = title.replaceAll(RegExp(r'\(.*?\)'), '');
    title = title.replaceAll(RegExp(r'\[.*?\]'), '');
    title = title.trim();

    // If the title contains a dash (e.g. "Lana Del Rey - Cinnamon Girl"), 
    // the YouTube channel name is usually wrong. We must extract the true artist from the title!
    if (title.contains(' - ')) {
      final parts = title.split(' - ');
      if (parts.length >= 2) {
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      }
    } else if (artist.isNotEmpty && title.toLowerCase().startsWith(artist.toLowerCase())) {
      // Sometimes it's just "Artist SongName"
      title = title.substring(artist.length).trim();
      if (title.startsWith('-')) {
        title = title.substring(1).trim();
      }
    }

    final lyrics = await LyricsService().getLyrics(artist, title);

    if (mounted) {
      setState(() {
        _lyrics = lyrics;
        _isLoading = false;
      });
    }
  }

  String _getActiveLyric(Duration currentPosition) {
    if (_lyrics == null || _lyrics!.isEmpty) return '';

    // Find the last lyric line that has a timestamp <= currentPosition
    for (int i = _lyrics!.length - 1; i >= 0; i--) {
      if (_lyrics![i].time <= currentPosition) {
        return _lyrics![i].text;
      }
    }
    
    // If we haven't reached the first line yet, show nothing or a subtle hint
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 24);
    }

    if (_lyrics == null || _lyrics!.isEmpty) {
      return const SizedBox(height: 24); // Fallback: empty space if no lyrics found
    }

    return ListenableBuilder(
      listenable: AudioService(),
      builder: (context, _) {
        final position = AudioService().position;
        final activeLyric = _getActiveLyric(position);

        if (activeLyric.isEmpty) {
          return const SizedBox(height: 24);
        }

        return GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.transparent,
              builder: (context) => FullLyricsScreen(
                track: widget.track,
                lyrics: _lyrics!,
              ),
            );
          },
          child: SizedBox(
            height: 24,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.5),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(
                activeLyric,
                key: ValueKey<String>(activeLyric),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      blurRadius: 4.0,
                      color: Colors.black54,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
              ),
            ),
          ),
        );
      },
    );
  }
}
