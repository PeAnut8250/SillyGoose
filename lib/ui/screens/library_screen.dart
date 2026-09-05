import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_app/ui/screens/replay_screen.dart';
import '../../data/history_service.dart';
import '../../data/scroll_service.dart';
import 'settings_screen.dart';

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
            if (scrollInfo is UserScrollNotification) {
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset('assets/goosees.jpg', width: 32, height: 32, fit: BoxFit.cover),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.history, color: Colors.white),
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
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Library', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
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
                const Text('On Device', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                // On Device Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildDeviceCard(
                        context,
                        'Downloads',
                        'Downloaded songs',
                        Icons.download,
                        [const Color(0xFF2A2870), const Color(0xFF53245B)],
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
                
                const SizedBox(height: 64),
                
                // Sign in section
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Sign in to your Google account to see your YouTube Music liked songs, playlists and history.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
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
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
      ],
    );
  }
}
