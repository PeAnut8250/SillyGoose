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
import '../../data/history_service.dart';
import '../../data/download_service.dart';
import '../components/app_toast.dart';

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
    final id = widget.playlistData['id'] ?? '';
    
    if (id == 'downloads') {
      setState(() {
        _tracks = DownloadService().downloadedTracks;
        _isLoading = false;
      });
      return;
    }

    if (id == 'LM') {
      setState(() {
        _tracks = HistoryService().likedSongs;
        _isLoading = false;
      });
      return;
    }

    if (id.startsWith('custom_')) {
      final customPlaylist = HistoryService().playlists.firstWhere((p) => p['id'] == id, orElse: () => <String, dynamic>{});
      setState(() {
        _tracks = (customPlaylist['tracks'] as List?)?.map((t) => Map<String, String>.from(t as Map)).toList() ?? [];
        _isLoading = false;
      });
      return;
    }

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
                if (scrollInfo is UserScrollNotification && scrollInfo.metrics.axis == Axis.vertical) {
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.music_off_outlined, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    Text(
                      'No tracks found in this playlist.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if ((widget.playlistData['id'] ?? '').startsWith('custom_')) ...[
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _openAddSongsWindow(context),
                        icon: const Icon(Icons.add, color: Colors.black),
                        label: const Text('Add Songs', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            ListenableBuilder(
              listenable: DownloadService(),
              builder: (context, _) {
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = _tracks[index];
                      final trackId = track['id'] ?? '';
                      final isDownloaded = DownloadService().isDownloaded(trackId);
                      final downloadState = DownloadService().getDownloadState(trackId);
                      final isDownloading = downloadState?.isDownloading == true;

                      Widget tile = ListTile(
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
                            if (isDownloading)
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: downloadState?.progress,
                                  color: Colors.white,
                                ),
                              )
                            else if (isDownloaded)
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1DB954), // Spotify green crisp check
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, size: 12, color: Colors.black),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.download_for_offline_outlined, size: 20),
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  DownloadService().downloadTrack(
                                    track,
                                    onComplete: (msg) => showAppToast(context, msg),
                                    onError: (err) => showAppToast(context, err),
                                  );
                                },
                              ),
                            const SizedBox(width: 10),
                            if (track['duration'] != null && track['duration']!.isNotEmpty)
                              Text(
                                track['duration']!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.playlist_add),
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              tooltip: 'Add to Playlist',
                              onPressed: () {
                                showAddToPlaylistModal(context, track);
                              },
                            ),
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

                      if ((widget.playlistData['id'] ?? '').startsWith('custom_')) {
                        return Dismissible(
                          key: Key(track['id'] ?? index.toString()),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red.withValues(alpha: 0.8),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                            HistoryService().removeTrackFromPlaylist(widget.playlistData['id']!, track['id']!);
                            setState(() {
                              _tracks.removeAt(index);
                            });
                            showAppToast(context, 'Removed ${track['title']}');
                          },
                          child: tile,
                        );
                      }

                      return Dismissible(
                        key: ValueKey('swipe_pl_${track['id']}_$index'),
                        direction: DismissDirection.horizontal,
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.endToStart) {
                            AudioService().addTrackToQueue(track);
                            showAppToast(context, 'Added to queue: ${track['title']}');
                          } else if (direction == DismissDirection.startToEnd) {
                            showAddToPlaylistModal(context, track);
                          }
                          return false;
                        },
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 24),
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.playlist_add, color: Colors.white, size: 22),
                              SizedBox(width: 8),
                              Text('Add to Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                        secondaryBackground: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: const Color(0xFF2C2C2E),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.queue_music, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('Add to Queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                        child: tile,
                      );
                    },
                    childCount: _tracks.length,
                  ),
                );
              },
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
    final imageUrl = widget.playlistData['imageUrl'];
    final isLikedSongs = widget.playlistData['id'] == 'LM';
    
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: double.infinity,
          height: 380,
          decoration: BoxDecoration(
            gradient: (imageUrl == null || imageUrl.isEmpty)
                ? LinearGradient(
                    colors: isLikedSongs
                        ? [const Color(0xFF5E134C), const Color(0xFFF22744)]
                        : [Theme.of(context).colorScheme.onSurface.withOpacity(0.1), Theme.of(context).colorScheme.onSurface.withOpacity(0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            image: (imageUrl != null && imageUrl.isNotEmpty)
                ? DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  )
                : null,
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
                  if ((widget.playlistData['id'] ?? '').startsWith('custom_'))
                    IconButton(
                      icon: const Icon(Icons.playlist_add, color: Colors.white),
                      tooltip: 'Add Songs',
                      onPressed: () => _openAddSongsWindow(context),
                    ),
                  if (widget.playlistData['id'] == 'downloads')
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white),
                      tooltip: 'Delete All Downloads',
                      onPressed: _tracks.isEmpty
                          ? null
                          : () {
                              _showDeleteAllDownloadsDialog(context);
                            },
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: Colors.white),
                      onPressed: _tracks.isEmpty
                          ? null
                          : () {
                              int startedCount = 0;
                              for (final track in _tracks) {
                                final id = track['id'];
                                if (id != null && !DownloadService().isDownloaded(id)) {
                                  DownloadService().downloadTrack(track);
                                  startedCount++;
                                }
                              }
                              if (startedCount > 0) {
                                showAppToast(context, 'Downloading $startedCount songs...');
                              } else {
                                showAppToast(context, 'All songs already downloaded!');
                              }
                            },
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openAddSongsWindow(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: FloatingSearchWindow(
            contextName: 'Add to ${widget.playlistData['title']}',
            onTrackTap: (track) {
              final playlistId = widget.playlistData['id'];
              if (playlistId != null) {
                HistoryService().addTrackToPlaylist(playlistId, track);
                _loadTracks();
                showAppToast(context, 'Added ${track['title']} to playlist');
              }
            },
          ),
        );
      },
    );
  }

  void _showDeleteAllDownloadsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete All Downloads?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will remove all downloaded offline songs from your device storage.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              await DownloadService().deleteAllDownloads();
              if (mounted) {
                setState(() {
                  _tracks = [];
                });
                showAppToast(context, 'All downloaded songs deleted');
              }
            },
            child: const Text('Delete All', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
