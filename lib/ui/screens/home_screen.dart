import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../data/api/audio_service.dart';
import '../../data/api/youtube_service.dart';
import '../../data/history_service.dart';
import '../../data/settings_service.dart';
import '../../data/scroll_service.dart';
import 'package:flutter/rendering.dart';
import '../components/liquid_glass.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/update_service.dart';
import 'settings_screen.dart';
import 'playlist_screen.dart';
import 'artist_screen.dart';
import 'dart:ui';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  double _scrollOffset = 0.0;
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _shelves = [];
  final YoutubeService _ytService = YoutubeService();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
      ScrollService().setScrollOffset(_scrollController.offset);
    });
    _loadData();
  }

  Future<void> _loadData() async {
    final history = HistoryService().history;
    final List<Map<String, dynamic>> newShelves = [];

    try {
      if (history.isEmpty) {
        // First time user
        final topGlobal = await _ytService.searchSongs('Top 50 Global', filterType: 'Playlists');
        List<Map<String, String>> topTracks = [];
        if (topGlobal.isNotEmpty) {
          topTracks = await _ytService.getPlaylistTracks(topGlobal.first['id']!);
        }
        
        if (topTracks.isEmpty) {
          topTracks = await _ytService.searchSongs('Top Hit Songs 2024');
        }

        newShelves.add({
          'title': 'Global Top Hits',
          'subtitle': 'The most popular songs right now',
          'isHero': true,
          'items': topTracks.take(10).toList(),
        });

        final trending = await _ytService.searchSongs('Trending Music');
        newShelves.add({
          'title': 'Trending Now',
          'subtitle': 'Catch up with the latest trends',
          'isHero': false,
          'items': trending.take(15).toList(),
        });
      } else {
        // Returning user
        newShelves.add({
          'title': 'Jump Back In',
          'subtitle': 'Your recent favorites',
          'isHero': true,
          'items': history.take(10).toList(),
        });

        // Pick a random recent song to seed the "Songs You Might Like"
        final randomHistoryTrack = history[DateTime.now().millisecond % (history.length > 5 ? 5 : history.length)];
        List<Map<String, String>> mightLike = await _ytService.getUpNext(randomHistoryTrack['id']!);
        
        if (mightLike.isEmpty) {
          final artistName = randomHistoryTrack['subtitle']?.split(' - ').first ?? 'Trending Music';
          mightLike = await _ytService.searchSongs(artistName);
          mightLike.removeWhere((track) => track['id'] == randomHistoryTrack['id']);
        }

        // Section 2: Recommended for You (Based on Top Artist)
        final topArtists = HistoryService().getTopArtists();
        if (topArtists.isNotEmpty) {
          final topArtistName = topArtists.first['name'] as String;
          final recommended = await _ytService.searchSongs('$topArtistName music');
          
          if (recommended.isNotEmpty) {
            newShelves.add({
              'title': 'Recommended for You',
              'subtitle': 'Because you listen to $topArtistName',
              'isHero': false,
              'items': recommended.take(15).toList(),
            });
          }
        } else {
          // Fallback if they have no top artist data yet
          newShelves.add({
            'title': 'Recommended for You',
            'subtitle': 'Based on your listening history',
            'isHero': false,
            'items': mightLike.take(15).toList(), // Share the list
          });
        }
        
        // Section 3: Songs You Might Like (Algorithm learning)
        if (mightLike.isNotEmpty && topArtists.isNotEmpty) {
          // Shuffle the mightLike list a bit so it feels different from Recommended if they share items
          mightLike.shuffle();
          newShelves.add({
            'title': 'Songs You Might Like',
            'subtitle': 'Discover something new',
            'isHero': false,
            'items': mightLike.take(15).toList(),
          });
        }
      }
    } catch (e) {
      print('Failed to load home screen data: $e');
    }

    if (mounted) {
      setState(() {
        _shelves = newShelves;
        _isLoading = false;
      });
    }
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
      highlightColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.1),
      child: ListView(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + kToolbarHeight + 16, bottom: 100),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Skeleton for Hero Section
          Padding(
            padding: const EdgeInsets.only(bottom: 26.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 220, height: 28, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                      const SizedBox(height: 8),
                      Container(width: 150, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: 3,
                    separatorBuilder: (context, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      return AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18))),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Skeleton for Normal Shelf
          Padding(
            padding: const EdgeInsets.only(bottom: 26.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 180, height: 28, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                      const SizedBox(height: 8),
                      Container(width: 120, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: 4,
                    separatorBuilder: (context, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      return SizedBox(
                        width: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                            ),
                            const SizedBox(height: 10),
                            Container(width: 120, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(height: 6),
                            Container(width: 80, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _isLoading 
        ? _buildSkeletonLoader()
        : RefreshIndicator(
            onRefresh: _loadData,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: NotificationListener<ScrollNotification>(
              onNotification: (scrollInfo) {
                if (scrollInfo.metrics.axis == Axis.vertical) {
                  setState(() {
                    _scrollOffset = scrollInfo.metrics.pixels;
                  });
                }
                if (scrollInfo is UserScrollNotification) {
                  if (scrollInfo.direction == ScrollDirection.reverse) {
                    ScrollService().setScrolledDown(true);
                  } else if (scrollInfo.direction == ScrollDirection.forward) {
                    ScrollService().setScrolledDown(false);
                  }
                }
                return false;
              },
              child: ListView.builder(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + kToolbarHeight + 16, bottom: 100),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _shelves.length,
              itemBuilder: (context, index) {
                final shelf = _shelves[index];
              final isHero = shelf['isHero'] as bool;
              final items = shelf['items'] as List<Map<String, String>>;
              
              if (items.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 26.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: shelf['title'],
                      subtitle: shelf['subtitle'],
                    ),
                    SizedBox(
                      height: isHero ? 220 : 200,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: items.length,
                        separatorBuilder: (context, _) => const SizedBox(width: 14),
                        itemBuilder: (context, itemIndex) {
                          final item = items[itemIndex];
                          if (isHero) {
                            return HeroCard(item: item, shelfItems: items, itemIndex: itemIndex);
                          } else {
                            return ShelfCard(item: item, shelfItems: items, itemIndex: itemIndex);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      // Custom Fixed Header
      Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16.0,
        right: 16.0,
        child: SizedBox(
          height: 44,
          child: Stack(
            children: [
              // Title Pill (Animates to center when scrolling)
              AnimatedAlign(
                alignment: _scrollOffset > 10 ? Alignment.center : Alignment.centerLeft,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: ListenableBuilder(
                    listenable: SettingsService(),
                    builder: (context, _) {
                      final isLightMode = Theme.of(context).brightness == Brightness.light;
                      
                      final dynamicColor = isLightMode 
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.white;

                      Widget logo = Image.asset('assets/goosees.jpg', width: 28, height: 28, fit: BoxFit.cover);
                      if (isLightMode) {
                        // Always invert logo to black in light mode
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

                      return Stack(
                        children: [
                          // Background
                          Positioned.fill(
                            child: AnimatedOpacity(
                              opacity: _scrollOffset > 10 ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: LiquidGlass(
                                forceOpaque: !SettingsService().liquidGlass,
                                child: Container(),
                              ),
                            ),
                          ),
                          // Foreground
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: Colors.transparent,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: logo,
                                ),
                                const SizedBox(width: 12),
                                Text('Listen Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: dynamicColor)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              
              // Profile Pill (Always on the right)
              Align(
                alignment: Alignment.centerRight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: ListenableBuilder(
                    listenable: SettingsService(),
                    builder: (context, _) {
                      final isLightMode = Theme.of(context).brightness == Brightness.light;
                      final dynamicColor = isLightMode 
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.white70;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background (visible when scrolled)
                          Positioned.fill(
                            child: AnimatedOpacity(
                              opacity: _scrollOffset > 10 ? 1.0 : 0.0,
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
                              Navigator.of(context, rootNavigator: true).push(
                                PageRouteBuilder(
                                  pageBuilder: (context, animation1, animation2) => const SettingsScreen(),
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              color: Colors.transparent,
                              child: ValueListenableBuilder<AppUpdateInfo?>(
                                valueListenable: UpdateService.updateNotifier,
                                builder: (context, updateInfo, child) {
                                  final hasUpdate = updateInfo?.hasUpdate ?? false;
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Icon(Icons.person, color: dynamicColor, size: 24),
                                      if (hasUpdate)
                                        Positioned(
                                          top: -2,
                                          right: -2,
                                          child: Container(
                                            width: 9,
                                            height: 9,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.black, width: 1.5),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                                                  blurRadius: 4,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const SectionHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 22
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class HeroCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final List<Map<String, String>> shelfItems;
  final int itemIndex;

  const HeroCard({super.key, required this.item, required this.shelfItems, required this.itemIndex});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (item['type'] == 'song') {
          AudioService().playPlaylist(shelfItems, startIndex: itemIndex);
        } else if (item['type'] == 'playlist' || item['type'] == 'album') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => PlaylistScreen(playlistData: Map<String, String>.from(item))),
          );
        } else if (item['type'] == 'artist') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => ArtistScreen(artistData: Map<String, String>.from(item))),
          );
        }
      },
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                item['imageUrl'],
                fit: BoxFit.cover,
                cacheWidth: 600,
                errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900]),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.78),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'],
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item['subtitle'],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShelfCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final List<Map<String, String>> shelfItems;
  final int itemIndex;

  const ShelfCard({super.key, required this.item, required this.shelfItems, required this.itemIndex});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (item['type'] == 'song') {
          AudioService().playPlaylist(shelfItems, startIndex: itemIndex);
        } else if (item['type'] == 'playlist' || item['type'] == 'album') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => PlaylistScreen(playlistData: Map<String, String>.from(item))),
          );
        } else if (item['type'] == 'artist') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => ArtistScreen(artistData: Map<String, String>.from(item))),
          );
        }
      },
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  item['imageUrl'],
                  fit: BoxFit.cover,
                  cacheWidth: 300,
                  errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item['title'],
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              item['subtitle'],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
