import 'package:flutter/material.dart';
import '../components/animated_equalizer.dart';
import 'package:flutter/cupertino.dart';
import '../../data/api/youtube_service.dart';
import '../../data/api/audio_service.dart';
import '../../data/history_service.dart';
import 'playlist_screen.dart';
import 'artist_screen.dart';
import '../widgets/song_options_menu.dart';
import '../components/app_toast.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/rendering.dart';
import '../../data/scroll_service.dart';
import 'dart:async';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final YoutubeService _ytService = YoutubeService();
  Timer? _debounce;
  
  String _selectedFilter = 'Top Results';
  bool _isLoading = false;
  List<Map<String, String>> _searchResults = [];
  
  final List<String> _filters = ['Top Results', 'Songs', 'Albums', 'Artists', 'Playlists'];

  String _lastSearchedQuery = '';
  final Map<String, List<Map<String, String>>> _filterCache = {};

  List<Map<String, String>> _historySuggestions = [];
  List<String> _textSuggestions = [];
  bool _isShowingSuggestions = false;

  @override
  void dispose() {
    _queryController.dispose();
    _focusNode.dispose();
    _ytService.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _updateSuggestions(String query) async {
    setState(() {
      _isShowingSuggestions = true;
    });
    
    final lowerQuery = query.toLowerCase();
    final history = HistoryService().searchHistory;
    final historyMatches = history.where((item) {
      final title = (item['title'] ?? '').toLowerCase();
      final subtitle = (item['subtitle'] ?? '').toLowerCase();
      return title.contains(lowerQuery) || subtitle.contains(lowerQuery);
    }).take(3).toList();

    if (mounted) {
      setState(() {
        _historySuggestions = historyMatches;
      });
    }

    try {
      final suggestions = await _ytService.getQuerySuggestions(query);
      if (mounted && query == _queryController.text) {
        setState(() {
          _textSuggestions = suggestions.take(7).toList();
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    _focusNode.unfocus();
    
    // Clear cache if new query
    if (query != _lastSearchedQuery) {
      _filterCache.clear();
      _lastSearchedQuery = query;
    }

    // Check cache
    if (_filterCache.containsKey(_selectedFilter)) {
      setState(() {
        _searchResults = _filterCache[_selectedFilter]!;
        _isShowingSuggestions = false;
        _isLoading = false;
      });
      return;
    }
    
    setState(() {
      _isShowingSuggestions = false;
      _isLoading = true;
    });

    final results = await _ytService.searchSongs(query, filterType: _selectedFilter);

    if (mounted) {
      setState(() {
        _filterCache[_selectedFilter] = results;
        // Only update UI if the query hasn't changed and filter hasn't changed while waiting
        if (query == _lastSearchedQuery) {
          _searchResults = results;
          _isLoading = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildSearchField(),
            if (_queryController.text.isNotEmpty) _buildFilterTabs(),
            Expanded(
              child: NotificationListener<ScrollNotification>(
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
                child: _queryController.text.isEmpty
                    ? _buildRecentSearches()
                    : _isShowingSuggestions
                        ? _buildSuggestions()
                        : _buildSearchResults(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
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
                controller: _queryController,
                focusNode: _focusNode,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Search songs, albums, artists',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {});
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () {
                    if (value.trim().isNotEmpty) {
                      _updateSuggestions(value);
                    } else {
                      setState(() {
                        _historySuggestions = [];
                        _textSuggestions = [];
                      });
                    }
                  });
                },
                onSubmitted: (value) {
                  _focusNode.unfocus();
                  _performSearch(value);
                },
              ),
            ),
            if (_queryController.text.isNotEmpty)
              IconButton(
                icon: const Icon(CupertinoIcons.clear_circled_solid, color: Colors.white54, size: 20),
                onPressed: () {
                  _queryController.clear();
                  setState(() {});
                  _focusNode.requestFocus();
                },
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        itemCount: _filters.length,
        separatorBuilder: (context, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = filter == _selectedFilter;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
              if (_queryController.text.isNotEmpty) {
                _performSearch(_queryController.text);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Theme.of(context).colorScheme.onSurface 
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                filter,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isSelected 
                      ? Theme.of(context).colorScheme.surface 
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentSearches() {
    return ListenableBuilder(
      listenable: HistoryService(),
      builder: (context, _) {
        final history = HistoryService().searchHistory;

        if (history.isEmpty) {
          return Center(
            child: Text(
              'Search for songs, albums, or artists',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: history.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent searches',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 22,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        HistoryService().clearSearchHistory();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            }

            final result = history[index - 1];
            final type = result['type'] ?? 'song';
            final isArtist = type == 'artist';

            return ListenableBuilder(
              listenable: AudioService(),
              builder: (context, _) {
                final isPlaying = AudioService().currentTrack?['id'] == result['id'];
                
                final Widget tile = InkWell(
                  onTap: () {
                    _focusNode.unfocus();
                    if (type == 'song') {
                      AudioService().playTrack(result);
                    } else if (type == 'playlist' || type == 'album') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PlaylistScreen(playlistData: result)),
                      );
                    } else if (type == 'artist') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ArtistScreen(artistData: result)),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(isArtist ? 100 : 8),
                          child: Image.network(
                            result['imageUrl'] ?? '',
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 52, height: 52, color: Colors.grey[900],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result['title'] ?? '',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                result['subtitle'] ?? '',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (result['duration'] != null && result['duration']!.isNotEmpty)
                              isPlaying
                                  ? AnimatedEqualizer(isAudioPlaying: AudioService().isPlaying, color: Theme.of(context).colorScheme.primary)
                                  : Text(
                                      result['duration']!,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              onPressed: () {
                                HistoryService().removeSearch(result['id']!);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.playlist_add),
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              tooltip: 'Add to Playlist',
                              onPressed: () {
                                showAddToPlaylistModal(context, result);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert),
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              onPressed: () {
                                showSongOptionsMenu(context, result);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
                if (type == 'song') {
                  return Dismissible(
                    key: ValueKey('swipe_hist_${result['id']}_$index'),
                    direction: DismissDirection.horizontal,
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.endToStart) {
                        AudioService().addTrackToQueue(result);
                        showAppToast(context, 'Added to queue: ${result['title']}');
                      } else if (direction == DismissDirection.startToEnd) {
                        showAddToPlaylistModal(context, result);
                      }
                      return false;
                    },
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 24),
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.playlist_add, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text('Add to Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                    secondaryBackground: Container(
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
                    child: tile,
                  );
                }
                return tile;
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSuggestions() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        if (_historySuggestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('From your history', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          ..._historySuggestions.map((result) {
            final type = result['type'] ?? 'song';
            final isArtist = type == 'artist';
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(isArtist ? 24 : 4),
                child: Image.network(result['imageUrl'] ?? '', width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 48, height: 48, color: Colors.white10)),
              ),
              title: Text(result['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
              subtitle: Text(result['subtitle'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.6))),
              trailing: const Icon(Icons.history, color: Colors.white54, size: 20),
              onTap: () {
                _focusNode.unfocus();
                if (type == 'song') {
                  AudioService().playTrack(result);
                } else if (type == 'playlist' || type == 'album') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistScreen(playlistData: result)));
                } else if (type == 'artist') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ArtistScreen(artistData: result)));
                }
              },
            );
          }),
          const Divider(color: Colors.white24, height: 1),
        ],
        ..._textSuggestions.map((suggestion) {
          return ListTile(
            leading: const Icon(CupertinoIcons.search, color: Colors.white54, size: 20),
            title: Text(suggestion, style: const TextStyle(color: Colors.white)),
            trailing: const Icon(CupertinoIcons.arrow_up_left, color: Colors.white24, size: 16),
            onTap: () {
              _queryController.text = suggestion;
              _performSearch(suggestion);
            },
          );
        }),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.white.withOpacity(0.05),
        highlightColor: Colors.white.withOpacity(0.15),
        child: ListView.separated(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          itemCount: 8,
        separatorBuilder: (context, _) => Padding(
          padding: const EdgeInsets.only(left: 72.0),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.2),
          ),
        ),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 16,
                        margin: const EdgeInsets.only(right: 40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
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
          );
        },
      ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No results found.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: _searchResults.length,
      separatorBuilder: (context, _) => Padding(
        padding: const EdgeInsets.only(left: 72.0),
        child: Divider(
          height: 1,
          thickness: 0.5,
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final type = result['type'] ?? 'song';
        final isArtist = type == 'artist';
        
        return ListenableBuilder(
          listenable: AudioService(),
          builder: (context, _) {
            final isPlaying = AudioService().currentTrack?['id'] == result['id'];
            
            final Widget tile = InkWell(
              onTap: () {
                _focusNode.unfocus();
                HistoryService().addSearch(result);
                if (type == 'song') {
                  if (AudioService().isShuffleEnabled) {
                    // User wants "Radio Mode" (random mix of related artists via Autoplay)
                    AudioService().playTrack(result);
                  } else {
                    // User wants to strictly play the search results sequentially
                    final songResults = _searchResults.where((r) => r['type'] == 'song').toList();
                    final tappedIndex = songResults.indexWhere((r) => r['id'] == result['id']);
                    
                    AudioService().playPlaylist(
                      songResults, 
                      startIndex: tappedIndex >= 0 ? tappedIndex : 0
                    );
                  }
                } else if (type == 'playlist') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PlaylistScreen(playlistData: result)),
                  );
                } else if (type == 'artist') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ArtistScreen(artistData: result)),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(isArtist ? 100 : 8),
                      child: Image.network(
                        result['imageUrl']!,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result['title']!,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            result['subtitle']!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (result['duration'] != null && result['duration']!.isNotEmpty)
                          isPlaying
                              ? AnimatedEqualizer(isAudioPlaying: AudioService().isPlaying, color: Theme.of(context).colorScheme.primary)
                              : Text(
                                  result['duration']!,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.playlist_add),
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          tooltip: 'Add to Playlist',
                          onPressed: () {
                            showAddToPlaylistModal(context, result);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert),
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          onPressed: () {
                            showSongOptionsMenu(context, result);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
            if (type == 'song') {
              return Dismissible(
                key: ValueKey('swipe_srch_${result['id']}_$index'),
                direction: DismissDirection.horizontal,
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    AudioService().addTrackToQueue(result);
                    showAppToast(context, 'Added to queue: ${result['title']}');
                  } else if (direction == DismissDirection.startToEnd) {
                    showAddToPlaylistModal(context, result);
                  }
                  return false;
                },
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 24),
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.playlist_add, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text('Add to Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
                secondaryBackground: Container(
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
                child: tile,
              );
            }
            return tile;
          },
        );
      },
    );
  }
}
