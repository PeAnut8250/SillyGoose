import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../data/scroll_service.dart';
import '../../data/api/youtube_service.dart';
import '../../data/models/explore_models.dart';
import 'playlist_screen.dart';
import '../components/liquid_glass.dart';
import '../../data/settings_service.dart';
import '../widgets/floating_search_window.dart';

class MoodGenrePlaylistsScreen extends StatefulWidget {
  final String title;
  final String browseId;
  final String params;

  const MoodGenrePlaylistsScreen({
    super.key,
    required this.title,
    required this.browseId,
    required this.params,
  });

  @override
  State<MoodGenrePlaylistsScreen> createState() => _MoodGenrePlaylistsScreenState();
}

class _MoodGenrePlaylistsScreenState extends State<MoodGenrePlaylistsScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;
  List<ExplorePlaylistShelf>? _shelves;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  Future<void> _loadData() async {
    final shelves = await YoutubeService().getMoodGenrePlaylists(widget.browseId, widget.params);
    if (mounted) {
      setState(() {
        _shelves = shelves;
        _isLoading = false;
      });
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
      backgroundColor: Colors.transparent, // Inherit mesh gradient
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
                child: SizedBox(height: MediaQuery.of(context).padding.top + 70),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    widget.title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ),
              if (_isLoading)
            SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface),
              ),
            )
          else if (_shelves == null || _shelves!.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text('Nothing to explore right now', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final shelf = _shelves![index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            shelf.title,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (shelf.strapline != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            child: Text(
                              shelf.strapline!,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14),
                            ),
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 240,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            itemCount: shelf.items.length,
                            itemBuilder: (context, i) {
                              final item = shelf.items[i];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => PlaylistScreen(
                                        playlistData: {
                                          'id': item.browseId.replaceFirst('VL', ''),
                                          'title': item.title,
                                          'subtitle': item.subtitle,
                                          'imageUrl': item.thumbnailUrl,
                                          'type': 'playlist',
                                        },
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 160,
                                  margin: const EdgeInsets.symmetric(horizontal: 6.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: AspectRatio(
                                          aspectRatio: 1,
                                          child: item.thumbnailUrl.isNotEmpty
                                              ? Image.network(item.thumbnailUrl, fit: BoxFit.cover)
                                              : Container(color: Colors.grey[800]),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item.title,
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.subtitle,
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
                childCount: _shelves!.length,
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 100), // Padding for bottom bar
          ),
        ],
      ),
    ),
      // Custom Fixed Back Button
      Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16.0,
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
                    child: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).colorScheme.onSurface, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Custom Fixed Search Button
      Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        right: 16.0,
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
                          child: FloatingSearchWindow(contextName: widget.title),
                        );
                      },
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.transparent,
                    child: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ],
      ),
    );
  }
}
