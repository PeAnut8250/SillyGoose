import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../components/dynamic_background.dart';
import '../../data/history_service.dart';
import '../../data/api/audio_service.dart';
import '../replay/replay_poster_widget.dart';
import '../components/animated_equalizer.dart';
import 'package:palette_generator/palette_generator.dart';
import 'replay_story_screen.dart';
import 'artist_screen.dart';
import 'settings_screen.dart';
class ReplayScreen extends StatefulWidget {
  const ReplayScreen({super.key});

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  String _selectedFilter = 'This year';
  bool _isReady = false;
  
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isReady = true);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DynamicBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([HistoryService(), AudioService()]),
            builder: (context, _) {
              final hs = HistoryService();
              
              String bucketKey = 'allTime';
              String subtitle = 'All time';
              final now = DateTime.now();
              
              if (_selectedFilter == 'This month') {
                bucketKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
                subtitle = DateFormat('MMMM yyyy').format(now);
              } else if (_selectedFilter == 'This year') {
                bucketKey = '${now.year}';
                subtitle = '${now.year}';
              }

              if (!_isReady) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }

              final topSongs = hs.getTopSongs(bucketKey: bucketKey);
              final topArtists = hs.getTopArtists(bucketKey: bucketKey);
              
              final totalMinutes = hs.getTotalMinutesListened(bucketKey: bucketKey);
              final totalPlays = hs.getTotalPlays(bucketKey: bucketKey);
              final topArtist = topArtists.isNotEmpty ? topArtists.first : null;
              
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.transparent,
                              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
                            ),
                          ),
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
                    ),
                    
                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Replay', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                          Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Segmented Filters
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildFilterChip('This month'),
                              _buildFilterChip('This year'),
                              _buildFilterChip('All time'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Horizontal Scrollable Cards
                    SizedBox(
                      height: 200,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                                builder: (_) => ReplayStoryScreen(startPage: ReplayStoryPage.minutes, bucketKey: bucketKey, subtitle: subtitle)
                              ));
                            },
                            child: _buildStatCard(
                              'YOUR LISTENING\nEXPERIENCE',
                              '$totalMinutes',
                              'MINUTES LISTENED',
                              'SILLYGOOSE LISTENER\n$totalPlays plays · $subtitle',
                              'MEMBER\nSINCE\n09/26',
                              const [Color(0xFF2B1D6D), Color(0xFF5E134C)],
                            ),
                          ),
                          ...topArtists.take(5).toList().asMap().entries.map((e) {
                            final artist = e.value;
                            // Assign different colors based on rank
                            final colors = [
                              const [Color(0xFF4A341E), Color(0xFF261D15)],
                              const [Color(0xFF1E3A4A), Color(0xFF152632)],
                              const [Color(0xFF4A1E3A), Color(0xFF321526)],
                              const [Color(0xFF1E4A2A), Color(0xFF15321A)],
                              const [Color(0xFF4A451E), Color(0xFF322E15)],
                            ];
                            final gradient = colors[e.key % colors.length];
                            
                            return Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                                    builder: (_) => ReplayStoryScreen(startPage: ReplayStoryPage.artists, bucketKey: bucketKey, subtitle: subtitle)
                                  ));
                                },
                                child: _buildStatCard(
                                  'YOUR LISTENING\nEXPERIENCE',
                                  artist['name'],
                                  'TOP ARTIST #${e.key + 1}',
                                  'SILLYGOOSE LISTENER\n${artist['minutes']} min · ${artist['plays']} plays',
                                  '',
                                  gradient,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Play Replay Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                            builder: (_) => ReplayStoryScreen(startPage: ReplayStoryPage.intro, bucketKey: bucketKey, subtitle: subtitle)
                          ));
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Play your Replay', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Top Songs
                    if (topSongs.isNotEmpty) ...[
                      _buildSectionTitle('Top songs'),
                      ...topSongs.take(5).toList().asMap().entries.map((e) {
                        final isPlaying = AudioService().currentTrack?['id'] == e.value['id']?.toString();
                        return _buildSongItem(
                          e.key + 1, 
                          e.value['title'], 
                          '${e.value['artist']} · ${e.value['plays'] * 3} min', 
                          e.value['imageUrl'] ?? '',
                          isPlaying: isPlaying,
                          onTap: () {
                            final track = {
                              'id': e.value['id']?.toString() ?? '',
                              'title': e.value['title']?.toString() ?? '',
                              'subtitle': e.value['artist']?.toString() ?? '',
                              'imageUrl': e.value['imageUrl']?.toString() ?? '',
                            };
                            AudioService().playTrack(track);
                          }
                        );
                      }),
                      const SizedBox(height: 32),
                    ],
                    
                    // Top Artists
                    if (topArtists.isNotEmpty) ...[
                      _buildSectionTitle('Top artists'),
                      ...topArtists.take(5).toList().asMap().entries.map((e) {
                        return _buildArtistItem(
                          e.key + 1, 
                          e.value['name'], 
                          '${e.value['minutes']} min', 
                          e.value['imageUrl'],
                          onTap: () {
                            Navigator.of(context, rootNavigator: true).push(
                              CupertinoPageRoute(builder: (context) => ArtistScreen(artistData: {'title': e.value['name'] as String})),
                            );
                          }
                        );
                      }),
                      const SizedBox(height: 32),
                    ],
                    const SizedBox(height: 32),
                    
                    // The Shape of it
                    _buildSectionTitle('The shape of it'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        children: [
                          Expanded(child: _buildShapeCard('${hs.getTotalUniqueSongs(bucketKey: bucketKey)}', 'Songs')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildShapeCard('${hs.getTotalUniqueArtists(bucketKey: bucketKey)}', 'Artists')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildShapeCard('46', 'Albums')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('You listen most around 2 am.', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                          const SizedBox(height: 8),
                          Text('Your biggest day was ${DateTime.now().day} — ${totalMinutes} min of it.', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Share Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: GestureDetector(
                        onTap: () => _showShareBottomSheet(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.ios_share, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Share my Replay', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              Spacer(),
                              Icon(Icons.chevron_right, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 200), // Bottom padding
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String header, String bigText, String subText, String footer, String rightFooter, List<Color> gradient) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(header, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset('assets/goosees.jpg', width: 24, height: 24, fit: BoxFit.cover),
              ),
            ],
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  bigText, 
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.1),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(subText, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(footer, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              if (rightFooter.isNotEmpty)
                Text(rightFooter, textAlign: TextAlign.right, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 8, letterSpacing: 1.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, bottom: 16.0),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSongItem(int rank, String title, String subtitle, String imageUrl, {VoidCallback? onTap, bool isPlaying = false}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Row(
          children: [
          SizedBox(
            width: 24,
            child: isPlaying 
                ? AnimatedEqualizer(isAudioPlaying: AudioService().isPlaying, color: const Color(0xFFF22744))
                : Text('$rank', style: const TextStyle(color: Color(0xFFF22744), fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(imageUrl, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 48, height: 48, color: Colors.grey)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    ));
  }
  
  Widget _buildAlbumItem(int rank, String title, String subtitle, String imageUrl) {
    return _buildSongItem(rank, title, subtitle, imageUrl); // Reuse song item layout for albums
  }

  Widget _buildArtistItem(int rank, String name, String min, String? imageUrl, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Row(
          children: [
          SizedBox(
            width: 24,
            child: Text('$rank', style: const TextStyle(color: Color(0xFFF22744), fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey,
            ),
            clipBehavior: Clip.antiAlias,
            child: (imageUrl != null && imageUrl.isNotEmpty) 
              ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.person, color: Colors.white))
              : const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(min, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildGenreItem(int rank, String letter, String name, String min, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('$rank', style: const TextStyle(color: Color(0xFFF22744), fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(letter, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(min, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShapeCard(String numStr, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(numStr, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }

  void _showShareBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReplayShareSheet(
        historyService: HistoryService(),
      ),
    );
  }
}

class ReplayShareSheet extends StatefulWidget {
  final HistoryService historyService;
  final ReplayStoryPage? page;

  const ReplayShareSheet({Key? key, required this.historyService, this.page}) : super(key: key);

  @override
  State<ReplayShareSheet> createState() => _ReplayShareSheetState();
}

class _ReplayShareSheetState extends State<ReplayShareSheet> {
  final GlobalKey _posterKey = GlobalKey();
  bool _isSaving = false;
  Future<PaletteGenerator>? _paletteFuture;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isReady = true);
    });
    final currentTrack = AudioService().currentTrack;
    if (currentTrack != null && currentTrack['imageUrl'] != null) {
      _paletteFuture = PaletteGenerator.fromImageProvider(
        NetworkImage(currentTrack['imageUrl']!),
      );
    }
  }

  Future<void> _captureAndSave(BuildContext context, bool share) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final boundary = _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/replay_share.png');
      await file.writeAsBytes(bytes);

      if (share) {
        await Share.shareXFiles([XFile(file.path)], text: 'Check out my Replay on SillyGoose!');
        if (context.mounted) Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image saved to cache!')));
      }
    } catch (e) {
      debugPrint('Error saving share image: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate image.')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PaletteGenerator>(
      future: _paletteFuture,
      builder: (context, snapshot) {
        List<Color> gradientColors = [Colors.black, Colors.black87];
        Color accentColor = const Color(0xFFF22744);
        if (snapshot.hasData && snapshot.data != null) {
          final palette = snapshot.data!;
          final swatches = palette.paletteColors.take(3).toList();
          if (swatches.isNotEmpty) {
            accentColor = swatches[0].color;
            gradientColors = [
              swatches[0].color.withOpacity(0.9),
              swatches.length > 1 ? swatches[1].color.withOpacity(0.6) : Colors.black87,
              Colors.black,
            ];
          }
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.70,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: !_isReady 
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Builder(
                builder: (context) {
                  final topSongs = widget.historyService.getTopSongs();
                  final topArtists = widget.historyService.getTopArtists();
                  final topSong = topSongs.isNotEmpty ? topSongs.first : null;
                  final totalMinutes = widget.historyService.getTotalMinutesListened();
                  final totalPlays = widget.historyService.getTotalPlays();
                  final distinctSongs = widget.historyService.getTotalUniqueSongs();
                  final distinctArtists = widget.historyService.getTotalUniqueArtists();

                  return Column(
                    children: [
          const Icon(Icons.drag_handle, color: Colors.white54),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Share my Replay', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('One picture with the whole year on it.', style: TextStyle(color: Colors.white54, fontSize: 14)),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Stack(
                      children: [
                      // Off-screen full-size rendering
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate scale to fit the 1080x1920 layout into the preview AspectRatio
                          final scale = constraints.maxWidth / 1080.0;
                          return OverflowBox(
                            maxWidth: 1080,
                            maxHeight: 1920,
                            alignment: Alignment.topLeft,
                            child: Transform.scale(
                              scale: scale,
                              alignment: Alignment.topLeft,
                              child: RepaintBoundary(
                                key: _posterKey,
                                child: ReplayPosterWidget(
                                  page: widget.page,
                                  topSong: topSong,
                                  topSongs: topSongs,
                                  topArtists: topArtists,
                                  totalMinutes: totalMinutes,
                                  totalPlays: totalPlays,
                                  distinctSongs: distinctSongs,
                                  distinctArtists: distinctArtists,
                                  label: '2026',
                                ),
                              ),
                            ),
                          );
                        }
                      ),
                    ],
                  ),
                ),
              ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _captureAndSave(context, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.download, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text('Save', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => _captureAndSave(context, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.ios_share, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text('Share', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      );
      }),
        );
      }
    );
  }
}
