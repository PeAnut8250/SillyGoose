import 'package:flutter/material.dart';
import 'dart:ui';
import '../../data/api/audio_service.dart';
import '../../data/api/youtube_service.dart';
import '../../data/history_service.dart';
import '../screens/artist_screen.dart';

void showSongOptionsMenu(BuildContext context, Map<String, String> track) {
  final parentContext = context;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.85),
                Theme.of(context).colorScheme.surface.withOpacity(0.85),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Header with track info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          track['imageUrl'] ?? '',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 48,
                            height: 48,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.onSurface),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track['title'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track['subtitle'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
                const SizedBox(height: 8),
                
                // Menu Items
                Builder(
                  builder: (context) {
                    final isLiked = HistoryService().isLiked(track['id'] ?? '');
                    return _buildMenuItem(
                      context, 
                      isLiked ? Icons.remove_circle_outline_rounded : Icons.favorite_border_rounded, 
                      isLiked ? 'Remove from Liked Songs' : 'Add to Liked Songs', 
                      () {
                        Navigator.pop(context);
                        HistoryService().toggleLike(track);
                        final action = isLiked ? 'Removed from' : 'Added to';
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$action Liked Songs')));
                      }
                    );
                  }
                ),
                _buildMenuItem(context, Icons.download_rounded, 'Download', () {
                  Navigator.pop(context);
                }),
                _buildMenuItem(context, Icons.playlist_play_rounded, 'Play next', () {
                  Navigator.pop(context);
                  AudioService().addTrackNext(track);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Playing next: ${track['title']}')));
                }),
                _buildMenuItem(context, Icons.queue_music_rounded, 'Add to queue', () {
                  Navigator.pop(context);
                  AudioService().addTrackToQueue(track);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to queue: ${track['title']}')));
                }),
                if (HistoryService().playlists.isNotEmpty)
                  _buildMenuItem(context, Icons.playlist_add_rounded, 'Add to playlist', () {
                    Navigator.pop(context);
                    _showAddToPlaylistModal(parentContext, track);
                  }),
                _buildMenuItem(context, Icons.album_rounded, 'Open album', () {
                  Navigator.pop(context);
                }),
                _buildMenuItem(context, Icons.person_rounded, 'Open artist', () {
                  Navigator.pop(context);
                  Navigator.of(parentContext).push(
                    MaterialPageRoute(
                      builder: (context) => ArtistScreen(artistData: {
                        'id': '',
                        'title': track['subtitle'] ?? 'Unknown Artist',
                        'imageUrl': '',
                        'type': 'artist'
                      }),
                    ),
                  );
                }),
                _buildMenuItem(context, Icons.bedtime_rounded, 'Sleep timer', () {
                  Navigator.pop(context);
                }),
                _buildMenuItem(context, Icons.share_rounded, 'Share', () {
                  Navigator.pop(context);
                }),
                _buildMenuItem(context, Icons.bug_report_rounded, 'Copy Log', () {
                  Navigator.pop(context);
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildMenuItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 22),
          const SizedBox(width: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    ),
  );
}

void _showAddToPlaylistModal(BuildContext context, Map<String, String> track) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text('Add to Playlist', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                flex: 0,
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: HistoryService().playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = HistoryService().playlists[index];
                    return ListTile(
                      leading: const Icon(Icons.queue_music_rounded),
                      title: Text(playlist['title']),
                      onTap: () {
                        Navigator.pop(context);
                        HistoryService().addTrackToPlaylist(playlist['id'], track);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to ${playlist['title']}')));
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    },
  );
}
