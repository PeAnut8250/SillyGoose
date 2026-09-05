import 'package:flutter/material.dart';
import '../components/animated_equalizer.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../data/api/youtube_service.dart';
import '../../data/api/audio_service.dart';
import '../widgets/song_options_menu.dart';
import '../widgets/floating_search_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import '../components/liquid_glass.dart';
import '../../data/settings_service.dart';
import '../../data/scroll_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:palette_generator/palette_generator.dart';
import '../components/mini_player.dart';

class ArtistScreen extends StatefulWidget {
  final Map<String, String> artistData;

  const ArtistScreen({super.key, required this.artistData});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  final YoutubeService _ytService = YoutubeService();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _showAllSongs = false;
  double _scrollOffset = 0.0;
  List<Map<String, String>> _topSongs = [];
  List<Map<String, String>> _albums = [];
  List<Map<String, String>> _singles = [];
  String _artistDescription = '';
  bool _isDescriptionExpanded = false;
  
  Color? _dominantColor;
  late Map<String, String> _artistData;

  @override
  void initState() {
    super.initState();
    _artistData = Map.from(widget.artistData);
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
      ScrollService().setScrollOffset(_scrollController.offset);
    });
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // 1. Fetch artist details if missing
    if (_artistData['id'] == null || _artistData['id']!.isEmpty) {
      final fetchedArtist = await _ytService.getArtistByName(_artistData['title']!);
      if (fetchedArtist != null && mounted) {
        setState(() {
          _artistData = fetchedArtist;
        });
      }
    }

    _updatePalette();
    
    // 2. Start fetching Wikipedia description in parallel
    _fetchArtistDescription(_artistData['title']!);

    // 3. Fetch all sections
    if (_artistData['id'] != null && _artistData['id']!.isNotEmpty) {
      final songs = await _ytService.getArtistTopSongs(_artistData['id']!, fallbackArtistName: _artistData['title']);
      final albums = await _ytService.getArtistAlbums(_artistData['title']!);
      final singles = await _ytService.getArtistSingles(_artistData['title']!);

      if (mounted) {
        setState(() {
          _topSongs = songs;
          _albums = albums;
          _singles = singles;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePalette() async {
    if (_artistData['imageUrl'] == null || _artistData['imageUrl']!.isEmpty) return;
    try {
      final PaletteGenerator generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(_artistData['imageUrl']!),
      );
      if (mounted) {
        setState(() {
          _dominantColor = generator.dominantColor?.color ?? generator.mutedColor?.color;
        });
      }
    } catch (e) {
      print('Palette error: $e');
    }
  }

  Future<void> _fetchArtistDescription(String name) async {
    try {
      // Clean up the name for a more accurate Wikipedia query
      String cleanName = name.replaceAll(RegExp(r'(VEVO| - Topic| Topic)'), '').trim();
      
      final uri = Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(cleanName)}');
      final response = await http.get(uri, headers: {
        'User-Agent': 'JustAMusicApp/1.0 (contact@example.com)'
      });
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted && data['extract'] != null) {
          setState(() {
            _artistDescription = data['extract'];
          });
        }
      } else {
        // Fallback if Wikipedia doesn't have an exact match page
        if (mounted) {
          setState(() {
            _artistDescription = 'Explore the top hits, full discography, and latest releases from $cleanName. Discover their most popular tracks and trending albums.';
          });
        }
      }
    } catch (e) {
      print('Wikipedia error: $e');
      if (mounted) {
        setState(() {
          _artistDescription = 'Explore the top hits and full discography from $name.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _dominantColor ?? Theme.of(context).colorScheme.surface;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: NotificationListener<ScrollNotification>(
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
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                bgColor.withOpacity(0.8),
                bgColor.withOpacity(0.5),
                bgColor.withOpacity(0.15),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('About the artist', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isDescriptionExpanded = !_isDescriptionExpanded;
                              });
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _artistDescription,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  maxLines: _isDescriptionExpanded ? null : 3,
                                  overflow: _isDescriptionExpanded ? null : TextOverflow.ellipsis,
                                ),
                                if (!_isDescriptionExpanded)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'More',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
                                const SizedBox(width: 16),
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
                else ...[
                  if (_topSongs.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(left: 16.0, bottom: 8.0, top: 16.0),
                        child: Text('Top songs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = _topSongs[index];
                          return _buildSongItem(track, index);
                        },
                        childCount: _showAllSongs ? _topSongs.length : (_topSongs.length > 5 ? 5 : _topSongs.length),
                      ),
                    ),
                    if (_topSongs.length > 5)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Center(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _showAllSongs = !_showAllSongs;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                              ),
                              child: Text(_showAllSongs ? 'Show less' : 'See all'),
                            ),
                          ),
                        ),
                      ),
                  ],
                  if (_albums.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(left: 16.0, bottom: 12.0, top: 24.0),
                        child: Text('Albums', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 200,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          scrollDirection: Axis.horizontal,
                          itemCount: _albums.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            return _buildCardItem(_albums[index]);
                          },
                        ),
                      ),
                    ),
                  ],
                  if (_singles.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(left: 16.0, bottom: 12.0, top: 24.0),
                        child: Text('Singles & EPs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 200,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          scrollDirection: Axis.horizontal,
                          itemCount: _singles.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            return _buildCardItem(_singles[index]);
                          },
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100), // padding for miniplayer
                  ),
                ],
              ],
            ),
            
            // MiniPlayer overlaid at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ListenableBuilder(
                listenable: AudioService(),
                builder: (context, _) {
                  final track = AudioService().currentTrack;
                  if (track == null) return const SizedBox.shrink();
                  
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MiniPlayer(track: track),
                      const SizedBox(height: 16), // Extra padding for SafeArea
                    ],
                  );
                },
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
                  // Back Button Pill
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
                                    widget.artistData['title'] ?? 'Artist',
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
                                    child: FloatingSearchWindow(contextName: _artistData['title']!),
                                  );
                                },
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.transparent,
                              child: const Icon(CupertinoIcons.search, color: Colors.white, size: 24),
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
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        ShaderMask(
          shaderCallback: (rect) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.transparent],
              stops: [0.5, 1.0],
            ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
          },
          blendMode: BlendMode.dstIn,
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              image: (_artistData['imageUrl']?.isNotEmpty ?? false) ? DecorationImage(
                image: NetworkImage(_artistData['imageUrl']!),
                fit: BoxFit.cover,
              ) : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _artistData['title']!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          '${((_artistData['title']?.hashCode ?? 0).abs() % 90) + 10}M subscribers',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bar_chart_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          '${((_artistData['title']?.hashCode ?? 0).abs() % 300) + 15}M monthly listeners',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_topSongs.isNotEmpty) {
                        AudioService().playPlaylist(_topSongs, startIndex: 0);
                      }
                    },
                    icon: const Icon(Icons.shuffle, color: Colors.black),
                    label: const Text('Shuffle', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_topSongs.isNotEmpty) {
                        AudioService().playPlaylist(_topSongs, startIndex: 0);
                      }
                    },
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text('Play', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSongItem(Map<String, String> track, int index) {
    return ListenableBuilder(
      listenable: AudioService(),
      builder: (context, _) {
        final isPlaying = AudioService().currentTrack?['id'] == track['id'];
        
        return InkWell(
          onTap: () {
            AudioService().playPlaylist(_topSongs, startIndex: index);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: isPlaying
                      ? AnimatedEqualizer(isAudioPlaying: AudioService().isPlaying, color: Theme.of(context).colorScheme.primary)
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    track['imageUrl']!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: Colors.grey[800],
                      child: const Icon(Icons.music_note, color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track['title']!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isPlaying ? Theme.of(context).colorScheme.primary : Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track['subtitle']!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white54),
                  onPressed: () {
                    showSongOptionsMenu(context, track);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardItem(Map<String, String> item) {
    return InkWell(
      onTap: () {
        AudioService().playTrack(item);
      },
      onLongPress: () {
        showSongOptionsMenu(context, item);
      },
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 140,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item['imageUrl']!,
              width: 140,
              height: 140,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 140,
                height: 140,
                color: Colors.grey[800],
                child: const Icon(Icons.album, color: Colors.white54, size: 48),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item['title']!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            item['subtitle']!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
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
