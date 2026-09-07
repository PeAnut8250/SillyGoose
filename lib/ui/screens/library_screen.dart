import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import '../components/liquid_glass.dart';
import '../../data/history_service.dart';
import '../../data/scroll_service.dart';
import 'settings_screen.dart';
import 'playlist_screen.dart';
import '../../data/api/youtube_service.dart';
import '../components/app_toast.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (scrollInfo) {
            ScrollService().setScrollOffset(scrollInfo.metrics.pixels);
            if (scrollInfo is UserScrollNotification && scrollInfo.metrics.axis == Axis.vertical) {
              if (scrollInfo.direction == ScrollDirection.reverse) {
                ScrollService().setScrolledDown(true);
              } else if (scrollInfo.direction == ScrollDirection.forward) {
                ScrollService().setScrolledDown(false);
              }
            }
            return false;
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Custom AppBar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Builder(
                      builder: (context) {
                        Widget logo = Image.asset('assets/goosees.jpg', width: 32, height: 32, fit: BoxFit.cover);
                        if (Theme.of(context).brightness == Brightness.light) {
                          logo = ColorFiltered(
                            colorFilter: const ColorFilter.matrix([
                              -1, 0, 0, 0, 255,
                              0, -1, 0, 0, 255,
                              0, 0, -1, 0, 255,
                              0, 0, 0, 1, 0,
                            ]),
                            child: logo,
                          );
                        }
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: logo,
                        );
                      }
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.history, color: Theme.of(context).colorScheme.onSurface),
                          onPressed: () {},
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(builder: (context) => const SettingsScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.person, color: Theme.of(context).colorScheme.onSurface, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Library', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                
                // Your Replay Card
                ListenableBuilder(
                  listenable: HistoryService(),
                  builder: (context, _) {
                    final totalMinutes = HistoryService().getTotalMinutesListened();
                    final totalPlays = HistoryService().getTotalPlays();
                    
                    return GestureDetector(
                      onTap: () {
                        context.push('/library/replay');
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2B1D6D), Color(0xFF5E134C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Your Replay', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  '$totalMinutes minutes listened · $totalPlays plays · ${DateTime.now().year}',
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                ),
                              ],
                            ),
                            const Icon(Icons.chevron_right, color: Colors.white),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 32),
                Text('On Device', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                // On Device Grid
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const PlaylistScreen(
                                playlistData: {
                                  'id': 'downloads',
                                  'title': 'Downloads',
                                  'subtitle': 'Downloaded songs',
                                },
                              ),
                            ),
                          );
                        },
                        child: _buildDeviceCard(
                          context,
                          'Downloads',
                          'Downloaded songs',
                          Icons.download,
                          [const Color(0xFF2A2870), const Color(0xFF53245B)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDeviceCard(
                        context,
                        'Local Music',
                        'Audio files on device',
                        Icons.library_music,
                        [const Color(0xFF215E5E), const Color(0xFF482D5C)],
                      ),
                    ),
                  ],
                ),
                
                // Playlists Section
                ListenableBuilder(
                  listenable: HistoryService(),
                  builder: (context, _) {
                    final likedSongsCount = HistoryService().likedSongs.length;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Playlists', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.link),
                                  tooltip: 'Import Playlist Link',
                                  color: Theme.of(context).colorScheme.onSurface,
                                  onPressed: () {
                                    _showImportPlaylistDialog(context);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  tooltip: 'Create Playlist',
                                  color: Theme.of(context).colorScheme.onSurface,
                                  onPressed: () {
                                    _showCreatePlaylistDialog(context);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Liked Songs Tile
                        _buildPlaylistTile(
                          context: context,
                          title: 'Liked Songs',
                          subtitle: '$likedSongsCount songs',
                          icon: Icons.favorite,
                          playlistId: 'LM',
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5E134C), Color(0xFFF22744)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onDelete: null, // Cannot delete Liked Songs
                        ),
                        const SizedBox(height: 8),
                        
                        // Custom Playlists
                        ...HistoryService().playlists.map((playlist) {
                          final tracksList = (playlist['tracks'] as List?);
                          final tracksCount = tracksList?.length ?? 0;
                          final coverUrl = playlist['coverUrl']?.toString() ?? 
                              (tracksList != null && tracksList.isNotEmpty ? tracksList.first['imageUrl']?.toString() : null);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: _buildPlaylistTile(
                              context: context,
                              title: playlist['title'],
                              subtitle: '$tracksCount songs',
                              icon: Icons.queue_music,
                              playlistId: playlist['id'],
                              coverUrl: coverUrl,
                              gradient: LinearGradient(
                                colors: [Theme.of(context).colorScheme.onSurface.withOpacity(0.1), Theme.of(context).colorScheme.onSurface.withOpacity(0.2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              onDelete: () {
                                _showDeletePlaylistDialog(context, playlist['id'], playlist['title']);
                              },
                            ),
                          );
                        }),
                      ],
                    );
                  }
                ),
                
                const SizedBox(height: 64),
                // Sign in section
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Sign in to your Google account to see your YouTube Music liked songs, playlists and history.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF22744),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text('Sign in', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100), // Space for bottom bar
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, String title, String subtitle, IconData icon, List<Color> colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Icon(icon, color: Colors.white, size: 48),
          ),
        ),
        const SizedBox(height: 12),
        Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
      ],
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: LiquidGlass(
            forceOpaque: false,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create Playlist', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'My Awesome Mix',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        HistoryService().createPlaylist(controller.text.trim());
                      }
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }

  void _showImportPlaylistDialog(BuildContext context) {
    final TextEditingController urlController = TextEditingController();
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        bool isImporting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: LiquidGlass(
                forceOpaque: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Import Playlist Link', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Paste YouTube, YT Music or Spotify playlist URL:', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: urlController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'https://open.spotify.com/playlist/... or YT link',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Playlist Name (Optional)',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isImporting
                                ? null
                                : () async {
                                    final url = urlController.text.trim();
                                    if (url.isEmpty) return;

                                    setDialogState(() {
                                      isImporting = true;
                                    });

                                    final result = await YoutubeService().importPlaylistFromUrl(url);
                                    final tracks = (result['tracks'] as List<dynamic>?)?.cast<Map<String, String>>() ?? [];
                                    if (context.mounted) {
                                      if (tracks.isNotEmpty) {
                                        final extractedTitle = result['title']?.toString() ?? '';
                                        final title = nameController.text.trim().isNotEmpty
                                            ? nameController.text.trim()
                                            : (extractedTitle.isNotEmpty ? extractedTitle : 'Imported Mix (${tracks.length} tracks)');
                                        final coverUrl = result['coverUrl']?.toString() ?? '';
                                        
                                        HistoryService().createPlaylist(title, coverUrl: coverUrl);

                                        // Find created playlist and add tracks
                                        final created = HistoryService().playlists.lastWhere((p) => p['title'] == title, orElse: () => <String, dynamic>{});
                                        if (created.isNotEmpty) {
                                          for (var t in tracks) {
                                            HistoryService().addTrackToPlaylist(created['id'], t);
                                          }
                                        }
                                        Navigator.pop(context);
                                        showAppToast(context, 'Imported ${tracks.length} tracks into $title!');
                                      } else {
                                        setDialogState(() {
                                          isImporting = false;
                                        });
                                        showAppToast(context, 'Could not fetch songs from that link.');
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: isImporting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Import', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

  void _showDeletePlaylistDialog(BuildContext context, String id, String title) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: LiquidGlass(
            forceOpaque: false,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Delete Playlist', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to delete "$title"? This action cannot be undone.',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      HistoryService().deletePlaylist(id);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.2),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }

  Widget _buildPlaylistTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required String playlistId,
    String? coverUrl,
    VoidCallback? onDelete,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(context,
          MaterialPageRoute(
            builder: (context) => PlaylistScreen(
              playlistData: {
                'id': playlistId,
                'title': title,
                'imageUrl': coverUrl ?? '',
                'subtitle': subtitle,
              },
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: gradient,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (coverUrl != null && coverUrl.isNotEmpty)
                    ? Image.network(
                        coverUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(icon, color: Colors.white, size: 28),
                      )
                    : Icon(icon, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    useRootNavigator: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 16),
                            Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            ListTile(
                              leading: const Icon(Icons.delete_outline, color: Colors.red),
                              title: const Text('Delete Playlist', style: TextStyle(color: Colors.red)),
                              onTap: () {
                                Navigator.pop(context);
                                onDelete();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
