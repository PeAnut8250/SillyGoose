import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../data/scroll_service.dart';

import '../components/liquid_glass.dart';
import '../../data/settings_service.dart';
import '../../data/api/youtube_service.dart';
import '../../data/models/explore_models.dart';
import 'settings_screen.dart';
import 'mood_genre_playlists_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;
  List<MoodGenreSection>? _sections;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
      ScrollService().setScrollOffset(_scrollController.offset);
    });
  }

  Future<void> _loadData() async {
    final sections = await YoutubeService().getMoodsAndGenres();
    if (mounted) {
      setState(() {
        _sections = sections;
        _isLoading = false;
      });
    }
    _loadArtworks(sections);
  }

  Future<void> _loadArtworks(List<MoodGenreSection> sections) async {
    for (var section in sections) {
      for (var item in section.items) {
        if (item.thumbnailUrl == null) {
          final artwork = await YoutubeService().getMoodGenreArtwork(item.browseId, item.params);
          if (artwork != null && mounted) {
            setState(() {
              item.thumbnailUrl = artwork;
            });
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                  child: SizedBox(height: MediaQuery.of(context).padding.top + 80),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverToBoxAdapter(
                    child: Opacity(
                      opacity: (1 - (_scrollOffset / 50)).clamp(0.0, 1.0),
                      child: Text(
                        'Explore',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface)),
                    ),
                  )
                else if (_sections != null)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final section = _sections![index];
                        return Padding(
                          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Text(
                                  section.title,
                                  style: const TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12.0,
                                  crossAxisSpacing: 12.0,
                                  childAspectRatio: 2.2,
                                ),
                                itemCount: section.items.length,
                                itemBuilder: (context, i) {
                                  final item = section.items[i];
                                  final colors = [
                                    Colors.purple, Colors.blue, Colors.teal, 
                                    Colors.orange, Colors.red, Colors.pink, Colors.deepPurple
                                  ];
                                  final color = colors[item.title.hashCode % colors.length];
                                  
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => MoodGenrePlaylistsScreen(
                                            title: item.title,
                                            browseId: item.browseId,
                                            params: item.params,
                                          ),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: color,
                                        ),
                                        child: Stack(
                                          children: [
                                            if (item.thumbnailUrl != null)
                                              Positioned(
                                                right: -14,
                                                bottom: -10,
                                                child: Transform.rotate(
                                                  angle: 16 * 3.14159 / 180,
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: Image.network(
                                                      item.thumbnailUrl!,
                                                      width: 72,
                                                      height: 72,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Positioned(
                                              top: 12,
                                              left: 12,
                                              right: 32,
                                              child: Text(
                                                item.title,
                                                style: const TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
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
                        );
                      },
                      childCount: _sections!.length,
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 120),
                ),
              ],
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
                  // Logo & Title Pill (Animates from left to center)
                  AnimatedAlign(
                    alignment: _scrollOffset > 50 ? Alignment.center : Alignment.centerLeft,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: ListenableBuilder(
                        listenable: SettingsService(),
                        builder: (context, _) => Stack(
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
                              padding: EdgeInsets.symmetric(
                                horizontal: _scrollOffset > 50 ? 16 : 10,
                                vertical: _scrollOffset > 50 ? 8 : 10,
                              ),
                              color: Colors.transparent,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      'assets/goosees.jpg', 
                                      width: _scrollOffset > 50 ? 28 : 24, 
                                      height: _scrollOffset > 50 ? 28 : 24, 
                                      fit: BoxFit.cover
                                    ),
                                  ),
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                    child: _scrollOffset > 50 
                                      ? Padding(
                                          padding: const EdgeInsets.only(left: 12.0),
                                          child: const Text(
                                            'Explore',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.onSurface),
                                            maxLines: 1,
                                            overflow: TextOverflow.visible,
                                          ),
                                        )
                                      : const SizedBox(width: 0, height: 28),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                        builder: (context, _) => Stack(
                          alignment: Alignment.center,
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
                                child: Icon(Icons.person, color: Theme.of(context).colorScheme.onSurface70, size: 24),
                              ),
                            ),
                          ],
                        ),
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
