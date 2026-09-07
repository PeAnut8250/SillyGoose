import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../data/api/youtube_service.dart';
import '../../data/api/audio_service.dart';
import 'song_options_menu.dart';
import '../components/app_toast.dart';

class FloatingSearchWindow extends StatefulWidget {
  final String contextName;

  const FloatingSearchWindow({super.key, required this.contextName});

  @override
  State<FloatingSearchWindow> createState() => _FloatingSearchWindowState();
}

class _FloatingSearchWindowState extends State<FloatingSearchWindow> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, String>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // Auto focus the search bar when the window opens
    Future.delayed(const Duration(milliseconds: 100), () {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Implicitly append the context name to narrow the search!
      final searchQuery = '${widget.contextName} $query';
      final ytService = YoutubeService();
      final results = await ytService.searchSongs(searchQuery);
      
      if (mounted) {
        setState(() {
          // Filter to only show songs
          _searchResults = results.where((r) => r['type'] == 'song').toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dismiss when tapping outside the main search area
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
            ),
          ),
          
          // Floating Search UI
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Hero(
                    tag: 'search_bar_${widget.contextName}',
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            const Icon(CupertinoIcons.search, color: Colors.white70, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _focusNode,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'Search in ${widget.contextName}...',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onSubmitted: _performSearch,
                                onChanged: (val) {
                                  // Optionally implement debounce here
                                },
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(CupertinoIcons.clear_circled_solid, color: Colors.white54, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchResults = [];
                                  });
                                },
                              ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Results Area
                Expanded(
                  child: _isSearching
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : _searchResults.isNotEmpty
                          ? ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final song = _searchResults[index];
                                return Dismissible(
                                  key: ValueKey('swipe_q_${song['id']}_$index'),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (direction) async {
                                    AudioService().addTrackToQueue(song);
                                    showAppToast(context, 'Added to queue');
                                    return false;
                                  },
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 24),
                                    color: const Color(0xFF2C2C2E),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.queue_music, color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Text('Add to Queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        song['imageUrl']!,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    title: Text(
                                      song['title']!,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      song['subtitle']!,
                                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.more_vert, color: Colors.white70),
                                      onPressed: () {
                                        showSongOptionsMenu(context, song);
                                      },
                                    ),
                                    onTap: () {
                                      // Close the search window
                                      Navigator.pop(context);
                                      // Play the selected song and queue the rest
                                      AudioService().playPlaylist(_searchResults, startIndex: index);
                                    },
                                  ),
                                );
                              },
                            )
                          : _searchController.text.isNotEmpty && !_isSearching
                              ? Center(
                                  child: Text(
                                    'No results found for "${_searchController.text}"',
                                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                                  ),
                                )
                              : const SizedBox(), // Empty state
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
