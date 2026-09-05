import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import '../../data/history_service.dart';
import 'replay_screen.dart';

enum ReplayStoryPage {
  intro,
  minutes,
  artists,
  songs,
  habits,
  summary
}

class ReplayStoryScreen extends StatefulWidget {
  final ReplayStoryPage startPage;
  final String bucketKey;
  final String subtitle;

  const ReplayStoryScreen({
    super.key,
    required this.startPage,
    required this.bucketKey,
    required this.subtitle,
  });

  @override
  State<ReplayStoryScreen> createState() => _ReplayStoryScreenState();
}

class _ReplayStoryScreenState extends State<ReplayStoryScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  
  List<ReplayStoryPage> _pages = [];
  bool _isPaused = false;
  
  // Data
  int _totalPlays = 0;
  int _totalMinutes = 0;
  int _uniqueSongs = 0;
  int _uniqueArtists = 0;
  List<Map<String, dynamic>> _topSongs = [];
  List<Map<String, dynamic>> _topArtists = [];

  @override
  void initState() {
    super.initState();
    
    // Load Data
    final history = HistoryService();
    _totalPlays = history.getTotalPlays(bucketKey: widget.bucketKey);
    _totalMinutes = history.getTotalMinutesListened(bucketKey: widget.bucketKey);
    _uniqueSongs = history.getTotalUniqueSongs(bucketKey: widget.bucketKey);
    _uniqueArtists = history.getTotalUniqueArtists(bucketKey: widget.bucketKey);
    _topSongs = history.getTopSongs(bucketKey: widget.bucketKey);
    _topArtists = history.getTopArtists(bucketKey: widget.bucketKey);
    
    _pages = ReplayStoryPage.values.where((page) {
      if (page == ReplayStoryPage.songs && _topSongs.isEmpty) return false;
      if (page == ReplayStoryPage.artists && _topArtists.isEmpty) return false;
      return true;
    }).toList();
    
    int initialIndex = _pages.indexOf(widget.startPage);
    if (initialIndex == -1) initialIndex = 0;

    _pageController = PageController(initialPage: initialIndex);
    
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextPage();
      }
    });
    
    _progressController.forward();
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _nextPage() {
    final double currentPage = _pageController.hasClients && _pageController.position.haveDimensions 
        ? (_pageController.page ?? _pageController.initialPage.toDouble()) 
        : _pageController.initialPage.toDouble();
    if (currentPage.round() < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _previousPage() {
    final double currentPage = _pageController.hasClients && _pageController.position.haveDimensions 
        ? (_pageController.page ?? _pageController.initialPage.toDouble()) 
        : _pageController.initialPage.toDouble();
    if (currentPage.round() > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  void _onTapDown(TapDownDetails details, BoxConstraints constraints) {
    _isPaused = true;
    _progressController.stop();
  }

  void _onTapUp(TapUpDetails details, BoxConstraints constraints) {
    _isPaused = false;
    final double dx = details.localPosition.dx;
    if (dx < constraints.maxWidth * 0.32) {
      _previousPage();
    } else {
      _nextPage();
    }
    _progressController.forward(from: 0);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _isPaused = true;
    _progressController.stop();
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _isPaused = false;
    _progressController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            color: const Color(0xFF17171A),
            child: SafeArea(
              child: Stack(
                children: [
                  // Linear gradient background based on current page
                      AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          double page = _pageController.hasClients && _pageController.position.haveDimensions 
                              ? (_pageController.page ?? _pageController.initialPage.toDouble()) 
                              : _pageController.initialPage.toDouble();
                          
                          int currentIndex = page.round();
                          Color startColor = _getColorForPage(_pages[currentIndex]);
                          
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  startColor.withOpacity(0.45),
                                  Colors.black.withOpacity(0.10),
                                  startColor.withOpacity(0.34),
                                ],
                                stops: const [0.0, 0.35, 1.0],
                              ),
                            ),
                          );
                        },
                      ),
                      
                      // Story Content
                      GestureDetector(
                        onTapDown: (details) => _onTapDown(details, constraints),
                        onTapUp: (details) => _onTapUp(details, constraints),
                        onLongPressStart: _onLongPressStart,
                        onLongPressEnd: _onLongPressEnd,
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _pages.length,
                          onPageChanged: (index) {
                            _progressController.forward(from: 0);
                          },
                          itemBuilder: (context, index) {
                            return _buildPageContent(_pages[index]);
                          },
                        ),
                      ),
                      
                      // Chrome overlay
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _buildChrome(),
                      ),
                    ],
                  ),
                ),
          );
        },
      ),
    );
  }

  Color _getColorForPage(ReplayStoryPage page) {
    switch (page) {
      case ReplayStoryPage.intro: return Colors.blue;
      case ReplayStoryPage.minutes: return Colors.orange;
      case ReplayStoryPage.songs: return Colors.green;
      case ReplayStoryPage.artists: return Colors.red;
      case ReplayStoryPage.habits: return Colors.purple;
      case ReplayStoryPage.summary: return Colors.pink;
    }
  }

  Widget _buildChrome() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedBuilder(
            animation: Listenable.merge([_pageController, _progressController]),
            builder: (context, child) {
              double currentPage = _pageController.hasClients && _pageController.position.haveDimensions 
                  ? (_pageController.page ?? _pageController.initialPage.toDouble()) 
                  : _pageController.initialPage.toDouble();
              
              return Row(
                children: List.generate(_pages.length, (index) {
                  double progress = 0;
                  if (index < currentPage.round()) {
                    progress = 1;
                  } else if (index == currentPage.round()) {
                    progress = _progressController.value;
                  }
                  
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Container(
                          height: 2.5,
                          color: Colors.white.withOpacity(0.28),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.subtitle.contains('2026') ? "Replay'26" : "Replay · ${widget.subtitle}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Row(
                children: [
                  Image.asset('assets/goosees.jpg', width: 20, height: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'SillyGoose',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(ReplayStoryPage page) {
    return Padding(
      padding: const EdgeInsets.only(top: 96, bottom: 18, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildStorySlide(page),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                _progressController.stop();
                showModalBottomSheet(
                  context: context,
                  useRootNavigator: true,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => ReplayShareSheet(
                    historyService: HistoryService(),
                    page: page,
                  ),
                ).then((_) {
                  if (mounted) _progressController.forward();
                });
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.18),
                ),
                child: const Icon(Icons.ios_share, color: Colors.white, size: 20),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStorySlide(ReplayStoryPage page) {
    switch (page) {
      case ReplayStoryPage.intro:
        return _buildIntro();
      case ReplayStoryPage.minutes:
        return _buildMinutes();
      case ReplayStoryPage.songs:
        return _buildLeaderboard("You played ", "$_totalPlays songs", ", one was your anthem.", _topSongs, circular: false);
      case ReplayStoryPage.artists:
        return _buildLeaderboard("There was one ", "artist", " you never got tired of.", _topArtists, circular: true);
      case ReplayStoryPage.habits:
        return _buildHabits();
      case ReplayStoryPage.summary:
        return _buildSummary();
    }
  }

  Widget _buildHeadline(String p1, String boldPart, String p2) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 30, height: 1.2),
        children: [
          TextSpan(text: p1, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.62))),
          TextSpan(text: boldPart, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          TextSpan(text: p2, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.62))),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeadline("This is your ", "Replay", " — the year in music you actually played."),
        const Spacer(),
        _buildArtworkCollage(),
        const Spacer(),
        Text(
          "Counted here on your phone. Nothing was sent anywhere to work it out.",
          style: TextStyle(color: Colors.white.withOpacity(0.5)),
        )
      ],
    );
  }

  Widget _buildMinutes() {
    final format = NumberFormat('#,###');
    final hours = _totalMinutes ~/ 60;
      
    String text;
    if (hours >= 1) {
      text = "That's ${format.format(hours)} hours across ${format.format(_totalPlays)} plays.";
    } else {
      text = "Across ${format.format(_totalPlays)} plays.";
    }
      
    // Add peak hour (mocked for now)
    const peakHour = 20; // 8 PM
    final amPm = peakHour >= 12 ? 'PM' : 'AM';
    final formattedHour = peakHour > 12 ? peakHour - 12 : (peakHour == 0 ? 12 : peakHour);
    text += " Mostly around $formattedHour $amPm.";
      
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeadline("You listened to ", "${NumberFormat.decimalPattern('en_US').format(_totalMinutes)} minutes", " of music."),
        const Spacer(),
        _buildArtworkCollage(),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              fontSize: 16,
            ),
          ),
        )
      ],
    );
  }

  Widget _buildArtworkCollage() {
    final List<String> songUrls = _topSongs.map((e) => e['imageUrl'] as String?).where((e) => e != null && e.isNotEmpty).cast<String>().take(3).toList();
    final List<String> artistUrls = _topArtists.map((e) => e['imageUrl'] as String?).where((e) => e != null && e.isNotEmpty).cast<String>().take(3).toList();
    
    if (songUrls.isEmpty && artistUrls.isEmpty) return const SizedBox();

    final squares = [
      {'pos': const Offset(0.26, 0.34), 'size': 168.0, 'angle': -3.0},
      {'pos': const Offset(0.05, 0.10), 'size': 88.0, 'angle': -9.0},
      {'pos': const Offset(0.62, 0.04), 'size': 72.0, 'angle': 7.0},
    ];
    final circles = [
      {'pos': const Offset(0.02, 0.62), 'size': 62.0, 'angle': 0.0},
      {'pos': const Offset(0.70, 0.34), 'size': 76.0, 'angle': 0.0},
      {'pos': const Offset(0.44, 0.78), 'size': 66.0, 'angle': 0.0},
    ];
    
    return SizedBox(
      height: 300,
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
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(2, 6))
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
                          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(2, 6))
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

  Widget _buildLeaderboard(String p1, String boldPart, String p2, List<Map<String, dynamic>> items, {required bool circular}) {
    if (items.isEmpty) return const SizedBox();
    final lead = items.first;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeadline(p1, boldPart, p2),
        const SizedBox(height: 18),
        Row(
          children: [
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: circular ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: circular ? null : BorderRadius.circular(10),
                image: DecorationImage(
                  image: NetworkImage(lead['imageUrl'] ?? ''),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lead['title'] ?? lead['name'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.1),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (lead['artist'] != null)
                    Text(lead['artist'], style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    "${lead['plays']} plays",
                    style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14),
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
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children: [
                Text("#${index + 1}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: circular ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: circular ? null : BorderRadius.circular(4),
                    image: DecorationImage(
                      image: NetworkImage(row['imageUrl'] ?? ''),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row['title'] ?? row['name'] ?? '',
                    style: TextStyle(color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.w600, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildHabits() {
    final format = NumberFormat.decimalPattern('en_US');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeadline("You got through ", "${format.format(_uniqueSongs)} songs", " by ${format.format(_uniqueArtists)} artists."),
        const Spacer(),
        _buildArtworkCollage(),
        const Spacer(),
      ],
    );
  }

  Widget _buildSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeadline("That was ", widget.subtitle, "."),
        const SizedBox(height: 20),
        _buildRecapLine("Minutes", NumberFormat.decimalPattern('en_US').format(_totalMinutes)),
        if (_topSongs.isNotEmpty) _buildRecapLine("Top song", _topSongs.first['title'] ?? ''),
        if (_topArtists.isNotEmpty) _buildRecapLine("Top artist", _topArtists.first['name'] ?? ''),
        const Spacer(),
        Text(
          "Tap share to turn all of this into one picture.",
          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 16),
        )
      ],
    );
  }
  
  Widget _buildRecapLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9.0),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
    );
  }
}
