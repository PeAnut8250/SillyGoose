import 'package:flutter/material.dart';
import '../../data/api/youtube_service.dart';
import '../../data/api/audio_service.dart';
import '../widgets/song_options_menu.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:shimmer/shimmer.dart';
import '../components/liquid_glass.dart';
import '../../data/settings_service.dart';
import '../../data/scroll_service.dart';
import '../widgets/floating_search_window.dart';

class PlaylistScreen extends StatefulWidget {
  final Map<String, String> playlistData;

  const PlaylistScreen({super.key, required this.playlistData});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final YoutubeService _ytService = YoutubeService();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  double _scrollOffset = 0.0;
  List<Map<String, String>> _tracks = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
    _loadTracks();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTracks() async {
    final tracks = await _ytService.getPlaylistTracks(
      widget.playlistData['id']!,
      fallbackQuery: widget.playlistData['title']!,
    );
    setState(() {
      _tracks = tracks;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (scrollInfo) {
                if (scrollInfo is UserScrollNotification) {
                  if (scrollInfo.direction == ScrollDirection.reverse) {
                    ScrollService().setScrolledDown(true);
                  } else if (scrollInfo.direction == ScrollDirection.forward) {
                    ScrollService().setScrolledDown(false);
                  }
                }
                return false;
              },
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(),
                ),
          if (_isLoading)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Shimmer.fromColors(
                    baseColor: Colors.white.withOpacity(0.05),
                    highlightColor: Colors.white.withOpacity(0.15),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 16,
                                margin: const EdgeInsets.only(right: 60),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 100,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  );
                },
                childCount: 8,
              ),
            )
          else if (_tracks.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'No tracks found.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = _tracks[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        track['imageUrl']!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 50,
                          height: 50,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.music_note),
                        ),
                      ),
                    ),
                    title: Text(
                      track['title']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      track['subtitle']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (track['duration'] != null && track['duration']!.isNotEmpty)
                          Text(
                            track['duration']!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.more_vert),
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          onPressed: () {
                            showSongOptionsMenu(context, track);
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      // Overwrite the entire queue with this playlist, starting at the tapped index!
                      AudioService().playPlaylist(_tracks, startIndex: index);
                    },
                  );
                },
                childCount: _tracks.length,
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100), // padding for miniplayer
            ),
        ],
      ),
      ),
      // Custom Fixed Header
      Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16.0,
        right: 16.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back Button
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
                        opacity: _scrollOffset > 50 ? 1.0 : 0.0,
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
                        padding: const EdgeInsets.all(12),
                        color: Colors.transparent,
                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Floating Title Pill
            Expanded(
              child: AnimatedOpacity(
                opacity: _scrollOffset > 300 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Align(
                    alignment: Alignment.center,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: ListenableBuilder(
                        listenable: SettingsService(),
                        builder: (context, _) => LiquidGlass(
                          forceOpaque: !SettingsService().liquidGlass,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            color: Colors.transparent,
                            child: Text(
                              widget.playlistData['title']!,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
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
            
            // Search Pill
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
                        opacity: _scrollOffset > 50 ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: LiquidGlass(
                          forceOpaque: !SettingsService().liquidGlass,
                          child: Container(),
                        ),
                      ),
                    ),
                    // Foreground
                    GestureDetector(
                      onTap: () {
                        showGeneralDialog(
                          context: context,
                          barrierColor: Colors.transparent,
                          transitionDuration: const Duration(milliseconds: 300),
                          pageBuilder: (context, animation, secondaryAnimation) {
                            return FadeTransition(
                              opacity: animation,
                              child: FloatingSearchWindow(contextName: widget.playlistData['title']!),
                            );
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.transparent,
                        child: const Icon(Icons.search, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ],
      ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: double.infinity,
          height: 380,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(widget.playlistData['imageUrl']!),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.4),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.playlistData['title']!,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.playlistData['subtitle']!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _tracks.isEmpty
                          ? null
                          : () {
                              AudioService().playPlaylist(_tracks, startIndex: 0);
                            },
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                      label: const Text(
                        'Play All',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.shuffle, color: Colors.white),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.favorite_border, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
