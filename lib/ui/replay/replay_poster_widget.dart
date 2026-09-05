import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../data/history_service.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../screens/replay_story_screen.dart';

class ReplayPosterWidget extends StatefulWidget {
  final ReplayStoryPage? page;
  final Map<String, dynamic>? topSong;
  final List<Map<String, dynamic>> topSongs;
  final List<Map<String, dynamic>> topArtists;
  final int totalMinutes;
  final int totalPlays;
  final int distinctSongs;
  final int distinctArtists;
  final String label;

  const ReplayPosterWidget({
    Key? key,
    this.page,
    required this.topSong,
    required this.topSongs,
    required this.topArtists,
    required this.totalMinutes,
    required this.totalPlays,
    required this.distinctSongs,
    required this.distinctArtists,
    required this.label,
  }) : super(key: key);

  @override
  State<ReplayPosterWidget> createState() => _ReplayPosterWidgetState();
}

class _ReplayPosterWidgetState extends State<ReplayPosterWidget> {
  List<Color> _paletteColors = [
    const Color(0xFF3A1C71),
    const Color(0xFFD76D77),
    const Color(0xFF2B5876),
    const Color(0xFFFFAF7B),
  ];

  @override
  void initState() {
    super.initState();
    _extractColors();
  }

  Future<void> _extractColors() async {
    if (widget.topSong == null || widget.topSong!['imageUrl'] == null) return;
    try {
      final imageProvider = NetworkImage(widget.topSong!['imageUrl']);
      final palette = await PaletteGenerator.fromImageProvider(imageProvider);
      
      final swatches = palette.paletteColors.take(4).toList();
      if (swatches.isNotEmpty) {
        setState(() {
          _paletteColors = [
            swatches.isNotEmpty ? _tuneColor(swatches[0].color) : _paletteColors[0],
            swatches.length > 1 ? _tuneColor(swatches[1].color) : _paletteColors[1],
            swatches.length > 2 ? _tuneColor(swatches[2].color) : _paletteColors[2],
            swatches.length > 3 ? _tuneColor(swatches[3].color) : _paletteColors[3],
          ];
        });
      }
    } catch (e) {
      debugPrint('Error generating palette: $e');
    }
  }

  Color _tuneColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withSaturation((hsl.saturation * 1.35).clamp(0.0, 1.0)).withLightness(hsl.lightness.clamp(0.28, 0.58)).toColor();
  }

  Color _dimColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness(0.10).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      height: 1920,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: _dimColor(_paletteColors[0]),
      ),
      child: Stack(
        children: [
          // Background Mesh
          ...List.generate(_paletteColors.length, (index) {
            final color = _paletteColors[index];
            final anchors = [
              const Offset(0.20, 0.16),
              const Offset(0.84, 0.22),
              const Offset(0.76, 0.66),
              const Offset(0.18, 0.78),
            ];
            final anchor = anchors[index];
            final cx = 1080 * anchor.dx;
            final cy = 1920 * anchor.dy;
            final radius = 1080 * 0.95;

            return Positioned(
              left: cx - radius,
              top: cy - radius,
              width: radius * 2,
              height: radius * 2,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withOpacity(210 / 255),
                      color.withOpacity(0.0),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            );
          }),

          // Scrim
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.55),
                  Colors.black.withOpacity(0.35),
                  Colors.black.withOpacity(0.8),
                ],
                stops: const [0.0, 0.42, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Content
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(72.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(),
                  
                  const SizedBox(height: 150),
                  
                  if (widget.page == null) ...[
                    // Totals
                    _buildTotals(),

                    const SizedBox(height: 100),

                    // Columns
                    Expanded(
                      child: _buildColumns(),
                    ),
                  ] else ...[
                    Expanded(
                      child: _buildStoryCard(widget.page!),
                    ),
                  ],

                  // Footer
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Replay · ${widget.label}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 46,
                fontWeight: FontWeight.w900,
                fontFamily: 'Inter',
              ),
            ),
            Row(
              children: [
                Image.asset('assets/goosees.jpg', width: 44, height: 44),
                const SizedBox(width: 20),
                Text(
                  'SillyGoose',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            )
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'USER',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildTotals() {
    final format = NumberFormat('#,###');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          format.format(widget.totalMinutes),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 148,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'MINUTES LISTENED',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 30,
            fontWeight: FontWeight.w600,
            letterSpacing: 4.2,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '${format.format(widget.totalPlays)} plays · ${format.format(widget.distinctSongs)} songs · ${format.format(widget.distinctArtists)} artists',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 30,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildColumns() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOP SONGS',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4.5,
                ),
              ),
              const SizedBox(height: 40),
              ...widget.topSongs.take(5).toList().asMap().entries.map((e) => _buildRow(e.key + 1, e.value, false)).toList(),
            ],
          ),
        ),
        const SizedBox(width: 36),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOP ARTISTS',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4.5,
                ),
              ),
              const SizedBox(height: 40),
              ...widget.topArtists.take(5).toList().asMap().entries.map((e) => _buildRow(e.key + 1, e.value, true)).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(int rank, Map<String, dynamic> item, bool circular) {
    final format = NumberFormat('#,###');
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '$rank',
              style: TextStyle(
                color: rank == 1 ? const Color(0xFFFA2D48) : Colors.white.withOpacity(0.45),
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: circular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: circular ? null : BorderRadius.circular(8.4),
              color: Colors.white12,
              image: item['imageUrl'] != null
                  ? DecorationImage(
                      image: NetworkImage(item['imageUrl']),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: item['imageUrl'] == null
                ? const Icon(Icons.music_note, color: Colors.white24, size: 40)
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item['artist'] != null ? "${item['artist']} · ${format.format((item['playedMs'] ?? 0) ~/ 60000)}m" : "${format.format((item['playedMs'] ?? 0) ~/ 60000)}m",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 25,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0.0),
      child: Text(
        'Counted on device with SillyGoose',
        style: TextStyle(
          color: Colors.white.withOpacity(0.45),
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildStoryCard(ReplayStoryPage page) {
    switch (page) {
      case ReplayStoryPage.intro:
        return _buildIntroCard();
      case ReplayStoryPage.minutes:
        return _buildMinutesCard();
      case ReplayStoryPage.songs:
        return _buildLeaderboardCard("You played ", "${widget.totalPlays} songs", ", one was your anthem.", widget.topSongs, circular: false);
      case ReplayStoryPage.artists:
        return _buildLeaderboardCard("There was one ", "artist", " you never got tired of.", widget.topArtists, circular: true);
      case ReplayStoryPage.habits:
        return _buildHabitsCard();
      case ReplayStoryPage.summary:
        return _buildSummaryCard();
    }
  }

  Widget _buildHeadlineText(String p1, String boldPart, String p2) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 88, height: 1.2, fontFamily: 'Inter'),
        children: [
          TextSpan(text: p1, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.62))),
          TextSpan(text: boldPart, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
          TextSpan(text: p2, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.62))),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeadlineText("This is your ", "Replay", " — the year in music you actually played."),
        const Spacer(),
        _buildArtworkCollage(),
        const Spacer(),
        Text(
          "Counted here on your phone. Nothing was sent anywhere to work it out.",
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 44),
        )
      ],
    );
  }

  Widget _buildMinutesCard() {
    final format = NumberFormat.decimalPattern('en_US');
    final hours = widget.totalMinutes ~/ 60;
    
    String text;
    if (hours >= 1) {
      text = "That's ${format.format(hours)} hours across ${format.format(widget.totalPlays)} plays.";
    } else {
      text = "Across ${format.format(widget.totalPlays)} plays.";
    }
    
    const peakHour = 20; // 8 PM
    final amPm = peakHour >= 12 ? 'PM' : 'AM';
    final formattedHour = peakHour > 12 ? peakHour - 12 : (peakHour == 0 ? 12 : peakHour);
    text += " Mostly around $formattedHour $amPm.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeadlineText("You listened to ", "${format.format(widget.totalMinutes)} minutes", " of music."),
        const Spacer(),
        _buildArtworkCollage(),
        const Spacer(),
        Text(
          text,
          style: TextStyle(color: Colors.white.withOpacity(0.62), fontSize: 48),
        )
      ],
    );
  }

  Widget _buildArtworkCollage() {
    final List<String> songUrls = widget.topSongs.map((e) => e['imageUrl'] as String?).where((e) => e != null && e.isNotEmpty).cast<String>().take(3).toList();
    final List<String> artistUrls = widget.topArtists.map((e) => e['imageUrl'] as String?).where((e) => e != null && e.isNotEmpty).cast<String>().take(3).toList();
    
    if (songUrls.isEmpty && artistUrls.isEmpty) return const SizedBox();

    final squares = [
      {'pos': const Offset(0.26, 0.34), 'size': 168.0 * 3.0, 'angle': -3.0},
      {'pos': const Offset(0.05, 0.10), 'size': 88.0 * 3.0, 'angle': -9.0},
      {'pos': const Offset(0.62, 0.04), 'size': 72.0 * 3.0, 'angle': 7.0},
    ];
    final circles = [
      {'pos': const Offset(0.02, 0.62), 'size': 62.0 * 3.0, 'angle': 0.0},
      {'pos': const Offset(0.70, 0.34), 'size': 76.0 * 3.0, 'angle': 0.0},
      {'pos': const Offset(0.44, 0.78), 'size': 66.0 * 3.0, 'angle': 0.0},
    ];
    
    return SizedBox(
      height: 900,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (int i = 0; i < songUrls.length; i++)
                Positioned(
                  left: w * (squares[i]['pos'] as Offset).dx,
                  top: h * (squares[i]['pos'] as Offset).dy,
                  child: Transform.rotate(
                    angle: (squares[i]['angle'] as double) * pi / 180,
                    child: Container(
                      width: squares[i]['size'] as double,
                      height: squares[i]['size'] as double,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 36, offset: const Offset(6, 18))
                        ],
                        image: DecorationImage(
                          image: NetworkImage(songUrls[i]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              for (int i = 0; i < artistUrls.length; i++)
                Positioned(
                  left: w * (circles[i]['pos'] as Offset).dx,
                  top: h * (circles[i]['pos'] as Offset).dy,
                  child: Transform.rotate(
                    angle: (circles[i]['angle'] as double) * pi / 180,
                    child: Container(
                      width: circles[i]['size'] as double,
                      height: circles[i]['size'] as double,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 36, offset: const Offset(6, 18))
                        ],
                        image: DecorationImage(
                          image: NetworkImage(artistUrls[i]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildLeaderboardCard(String p1, String boldPart, String p2, List<Map<String, dynamic>> items, {required bool circular}) {
    if (items.isEmpty) return const SizedBox();
    final lead = items.first;
    final format = NumberFormat.decimalPattern('en_US');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeadlineText(p1, boldPart, p2),
        const SizedBox(height: 56),
        Row(
          children: [
            Container(
              width: 348,
              height: 348,
              decoration: BoxDecoration(
                shape: circular ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: circular ? null : BorderRadius.circular(34),
                image: DecorationImage(
                  image: NetworkImage(lead['imageUrl'] ?? ''),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 48),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lead['title'] ?? lead['name'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 78, fontWeight: FontWeight.w900, height: 1.1),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (lead['artist'] != null) ...[
                    const SizedBox(height: 12),
                    Text(lead['artist'], style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 50)),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    "${format.format((lead['playedMs'] ?? 0) ~/ 60000)}m · ${lead['plays']} plays",
                    style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 44),
                  )
                ],
              ),
            )
          ],
        ),
        const Spacer(),
        ...items.skip(1).take(4).map((row) {
          int index = items.indexOf(row);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Row(
              children: [
                SizedBox(
                  width: 62,
                  child: Text("${index + 1}", style: TextStyle(color: Colors.white.withOpacity(0.45), fontWeight: FontWeight.bold, fontSize: 44)),
                ),
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: circular ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: circular ? null : BorderRadius.circular(10),
                    image: DecorationImage(
                      image: NetworkImage(row['imageUrl'] ?? ''),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: Text(
                    row['title'] ?? row['name'] ?? '',
                    style: TextStyle(color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.bold, fontSize: 48),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  "${format.format((row['playedMs'] ?? 0) ~/ 60000)}m",
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 38),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildHabitsCard() {
    final format = NumberFormat.decimalPattern('en_US');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeadlineText("You got through ", "${format.format(widget.distinctSongs)} songs", " by ${format.format(widget.distinctArtists)} artists."),
        const Spacer(),
        _buildArtworkCollage(),
        const Spacer(),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final format = NumberFormat.decimalPattern('en_US');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeadlineText("That was ", widget.label, "."),
        const SizedBox(height: 100),
        _buildRecapLine("Minutes", format.format(widget.totalMinutes)),
        if (widget.topSongs.isNotEmpty) _buildRecapLine("Top song", widget.topSongs.first['title'] ?? ''),
        if (widget.topArtists.isNotEmpty) _buildRecapLine("Top artist", widget.topArtists.first['name'] ?? ''),
      ],
    );
  }

  Widget _buildRecapLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        children: [
          SizedBox(
            width: 320,
            child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 42)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 52), maxLines: 1, overflow: TextOverflow.ellipsis),
          )
        ],
      ),
    );
  }
}
