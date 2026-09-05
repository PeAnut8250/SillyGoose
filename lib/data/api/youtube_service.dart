import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../settings_service.dart';
class YoutubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Retrieves search autocomplete suggestions from iTunes API (music only).
  Future<List<String>> getQuerySuggestions(String query) async {
    try {
      final uri = Uri.parse('https://itunes.apple.com/search?term=\${Uri.encodeComponent(query)}&media=music&limit=7');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final Set<String> suggestions = {};
          for (var item in results) {
            final trackName = item['trackName']?.toString() ?? '';
            final artistName = item['artistName']?.toString() ?? '';
            if (trackName.isNotEmpty) {
              suggestions.add('\$trackName - \$artistName');
            } else if (artistName.isNotEmpty) {
              suggestions.add(artistName);
            }
          }
          if (suggestions.isNotEmpty) return suggestions.toList();
        }
      }
    } catch (e) {
      // Fallback
    }

    try {
      return await _yt.search.getQuerySuggestions(query);
    } catch (e) {
      return [];
    }
  }

  /// Searches YouTube Music with specific filters (Songs, Albums, Artists, Playlists).
  Future<List<Map<String, String>>> searchSongs(String query, {String filterType = 'Top Results'}) async {
    try {
      final isSongSearch = filterType == 'Top Results' || filterType == 'Songs';
      final searchQuery = (isSongSearch && !query.toLowerCase().contains('official')) 
          ? '$query official audio' 
          : query;
          
      SearchFilter ytFilter = const SearchFilter('');
      if (filterType == 'Songs') ytFilter = TypeFilters.video;
      if (filterType == 'Albums' || filterType == 'Playlists') ytFilter = TypeFilters.playlist;

      // WORKAROUND: youtube_explode_dart has an internal parsing bug for SearchChannel.
      // Instead, we search for videos and extract the unique channel/artist data from them!
      if (filterType == 'Artists') {
        final videos = await _yt.search.search(searchQuery);
        final uniqueArtists = <String, Map<String, String>>{};
        
        for (var video in videos) {
          if (!uniqueArtists.containsKey(video.channelId.value)) {
            uniqueArtists[video.channelId.value] = {
              'id': video.channelId.value,
              'title': video.author,
              'subtitle': 'Artist',
              // Using video thumbnail as fallback since we can't fetch channel avatar easily without API
              'imageUrl': video.thumbnails.highResUrl,
              'type': 'artist'
            };
          }
          if (uniqueArtists.length >= 10) break;
        }
        return uniqueArtists.values.toList();
      }

      dynamic searchResults;
      try {
        searchResults = await _yt.search.searchContent(searchQuery, filter: ytFilter).timeout(const Duration(seconds: 10));
      } catch (e) {
        print('Warning: searchContent failed (YouTube layout change), using fallback search. $e');
        
        final fallbackQuery = (filterType == 'Albums' || filterType == 'Playlists') 
            ? '$searchQuery full album' 
            : searchQuery;
            
        final fallbackResults = await _yt.search.search(fallbackQuery).timeout(const Duration(seconds: 10));
        
        // Filter out non-music content (podcasts, comedy shows)
        final filteredResults = fallbackResults.where((video) {
          if (!isSongSearch) return true;
          
          final titleLower = video.title.toLowerCase();
          if (titleLower.contains('podcast') || 
              titleLower.contains('interview') || 
              titleLower.contains('episode') ||
              titleLower.contains('latent') ||
              titleLower.contains('vlog') ||
              titleLower.contains('stand up') ||
              titleLower.contains('comedy')) {
            return false;
          }
          
          // Music tracks are rarely over 15 minutes
          if (video.duration != null && video.duration!.inMinutes > 15) {
            return false;
          }
          
          return true;
        });

        return filteredResults.map((video) {
          String artist = video.author;
          String title = video.title;
          
          if (artist.endsWith(' - Topic')) {
            artist = artist.replaceAll(' - Topic', '');
          }
          
          // Normalize dashes
          title = title.replaceAll('–', '-').replaceAll('—', '-');
          
          if (title.contains(' - ')) {
            final parts = title.split(' - ');
            if (parts.length >= 2) {
              artist = parts[0].trim();
              title = parts.sublist(1).join(' - ').trim();
            }
          }
          
          // Clean up suffixes
          title = title.replaceAll(RegExp(r'\s*\|.*?$'), '');
          title = title.replaceAll(RegExp(r'\s*\(.*?\)'), '');
          title = title.replaceAll(RegExp(r'\s*\[.*?\]'), '');

          return <String, String>{
            'id': video.id.value,
            'title': title,
            'subtitle': filterType == 'Albums' || filterType == 'Playlists' 
                ? 'Full Album Video • $artist' 
                : artist,
            'imageUrl': 'https://i.ytimg.com/vi/${video.id.value}/hqdefault.jpg',
            'type': 'song',
            'duration': video.duration != null ? '${video.duration!.inMinutes}:${(video.duration!.inSeconds % 60).toString().padLeft(2, '0')}' : '',
          };
        }).toList();
      }
      
      return searchResults.map((item) {
        if (item is SearchVideo) {
          if (isSongSearch) {
            final titleLower = item.title.toLowerCase();
            if (titleLower.contains('podcast') || 
                titleLower.contains('interview') || 
                titleLower.contains('episode') ||
                titleLower.contains('vlog')) {
              return null;
            }
            
            if (item.duration != null) {
              final parts = item.duration!.split(':');
              if (parts.length >= 3) return null; // Over an hour
              if (parts.length == 2) {
                final min = int.tryParse(parts[0]) ?? 0;
                if (min > 15) return null; // Over 15 minutes
              }
            }
          }
          
          String artist = item.author;
          String title = item.title;
          
          if (artist.endsWith(' - Topic')) {
            artist = artist.replaceAll(' - Topic', '');
          }
          
          // Normalize dashes
          title = title.replaceAll('–', '-').replaceAll('—', '-');
          
          if (title.contains(' - ')) {
            final parts = title.split(' - ');
            if (parts.length >= 2) {
              artist = parts[0].trim();
              title = parts.sublist(1).join(' - ').trim();
            }
          } else if (title.contains(' | ')) {
            final parts = title.split(' | ');
            if (parts.length >= 2) {
              title = parts[0].trim(); // Usually Title | Artist
              artist = parts.sublist(1).join(', ').trim();
            }
          }
          
          // Clean up typical video suffixes like (Official Audio), [MV], etc.
          title = title.replaceAll(RegExp(r'\s*\|.*?$'), '');
          title = title.replaceAll(RegExp(r'\s*\(.*?\)'), '');
          title = title.replaceAll(RegExp(r'\s*\[.*?\]'), '');

          return <String, String>{
            'id': item.id.value,
            'title': title,
            'subtitle': artist,
            'imageUrl': 'https://i.ytimg.com/vi/${item.id.value}/hqdefault.jpg',
            'type': 'song',
            'duration': item.duration ?? '',
          };
        } else if (item is SearchPlaylist) {
          return <String, String>{
            'id': item.id.value,
            'title': item.title,
            'subtitle': 'Playlist • ${item.videoCount} tracks',
            'imageUrl': item.thumbnails.isEmpty ? '' : item.thumbnails.last.url.toString(),
            'type': 'playlist'
          };
        }
        return null;
      }).whereType<Map<String, String>>().toList();
    } catch (e) {
      print('Error searching with filter $filterType: $e');
      return [];
    }
  }

  /// Fetches related "Up Next" songs for a given video ID.
  Future<List<Map<String, String>>> getUpNext(String videoId) async {
    try {
      final video = await _yt.videos.get(VideoId(videoId)).timeout(const Duration(seconds: 10));
      
      List<Video> relatedVideos = [];
      try {
        final related = await _yt.videos.getRelatedVideos(video).timeout(const Duration(seconds: 10));
        if (related != null) {
          relatedVideos = related.whereType<Video>().toList();
        }
      } catch (e) {
        print('YouTube Explode error fetching related videos (likely livestream parse error): $e');
      }
      
      List<Map<String, String>> results = relatedVideos.where((v) {
        // Filter out long mixes/podcasts (over 8 minutes)
        if (v.duration != null && v.duration!.inMinutes > 8) return false;
        
        // Aggressive Music Filter: throw away anything that looks like a vlog, podcast, or comedy
        final title = v.title.toLowerCase();
        final author = v.author.toLowerCase();
        
        // Explicitly exclude non-music genres even if they have a hyphen
        if (title.contains('comedy') || 
            title.contains('stand up') || 
            title.contains('podcast') || 
            title.contains('interview') || 
            title.contains('vlog') ||
            title.contains('episode') ||
            title.contains('reaction') ||
            title.contains('trailer') ||
            author.contains('comedy') ||
            author.contains('podcast')) {
          return false;
        }
        
        bool isMusic = author.contains('vevo') || 
                       author.contains('topic') || 
                       author.contains('music') ||
                       author.contains('records') ||
                       title.contains('official') || 
                       title.contains('lyric') || 
                       title.contains('music video') ||
                       title.contains('audio') ||
                       title.contains('remix') ||
                       title.contains('song') ||
                       title.contains('album') ||
                       title.contains('cover') ||
                       title.contains('feat') ||
                       title.contains('ft.');
                       
        return isMusic;
      }).map((v) {
        String artist = v.author;
        String title = v.title;
        
        if (artist.endsWith(' - Topic')) {
          artist = artist.replaceAll(' - Topic', '');
        }
        
        if (title.contains(' - ')) {
          final parts = title.split(' - ');
          if (parts.length >= 2) {
            artist = parts[0].trim();
            title = parts.sublist(1).join(' - ').trim();
          }
        }
        
        // Clean up suffixes
        title = title.replaceAll(RegExp(r'\s*\|.*?$'), '');
        title = title.replaceAll(RegExp(r'\s*\(.*?\)'), '');
        title = title.replaceAll(RegExp(r'\s*\[.*?\]'), '');
        
        return {
          'id': v.id.value,
          'title': title.trim(),
          'subtitle': artist,
          'imageUrl': v.thumbnails.highResUrl,
          'duration': v.duration != null ? '${v.duration!.inMinutes}:${(v.duration!.inSeconds % 60).toString().padLeft(2, '0')}' : '',
          'type': 'song'
        };
      }).toList();

      // Fallback: If YouTube hides related videos, or crashed, just queue up top songs from the same artist!
      if (results.isEmpty) {
        results = await searchSongs(video.author);
        // Remove the current video from the fallback results
        results.removeWhere((track) => track['id'] == videoId);
      }

      return results;
    } catch (e) {
      print('Error getting Up Next: $e');
      return [];
    }
  }

  /// Gets the highest quality audio stream URL for a given video ID.
  Future<String?> getAudioStreamUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 10));
      
      // Check network connectivity to determine target quality
      // Add a strict timeout since Connectivity() can hang indefinitely on Windows Media Foundation backend
      final connectivityResult = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 2), onTimeout: () => [ConnectivityResult.wifi]);
          
      bool isWifi = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.ethernet);
      
      String targetQuality = isWifi 
          ? SettingsService().wifiQuality 
          : SettingsService().mobileDataQuality;

      // Windows Media Foundation crashes (Item Error) on fragmented DASH streams (audioOnly).
      // We MUST use progressive muxed (video+audio) streams on Windows to avoid crashing.
      // Furthermore, YouTube heavily restricts DASH audio-only streams on mobile networks (yielding 403 Forbidden).
      // We will universally use progressive muxed MP4 streams for maximum compatibility across all platforms!
      final muxedStreams = manifest.muxed.where(
        (stream) => stream.container.name.toLowerCase() == 'mp4'
      ).toList();
      
      if (muxedStreams.isNotEmpty) {
        if (targetQuality == 'Low' || targetQuality == 'Normal') {
          return muxedStreams.sortByVideoQuality().last.url.toString(); // lowest
        } else {
          return muxedStreams.withHighestBitrate().url.toString(); // highest
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting audio stream: $e');
      return null;
    }
  }

  /// Gets a low-quality video stream URL for animated cover art.
  Future<String?> getVideoStreamUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      
      // Reverting to muxed streams ONLY. Windows Media Foundation strictly requires a complete MOOV atom, 
      // which DASH videoOnly streams often lack when we only download a 2MB chunk.
      final videoStreams = manifest.muxed.where(
        (stream) => stream.container.name.toLowerCase() == 'mp4'
      ).toList();
      
      if (videoStreams.isNotEmpty) {
        final lowestQualityVideo = videoStreams.sortByVideoQuality().first;
        return lowestQualityVideo.url.toString();
      }
      
      // Fallback to DASH videoOnly streams for modern VEVO videos that lack muxed streams.
      // Since player_screen downloads the entire file now, the MOOV atom is fully intact!
      final dashVideoStreams = manifest.videoOnly.where(
        (stream) => stream.container.name.toLowerCase() == 'mp4'
      ).toList();
      
      if (dashVideoStreams.isNotEmpty) {
        final lowestQualityDash = dashVideoStreams.sortByVideoQuality().first;
        return lowestQualityDash.url.toString();
      }
      
      return null;
    } catch (e) {
      print('Error getting video stream: $e');
      return null;
    }
  }

  /// Searches for the actual Music Video (ignoring the current Official Audio ID) 
  /// just so we can fetch an animated background video!
  Future<String?> getBackgroundVideoUrl(String artist, String title) async {
    try {
      final cleanTitle = title.replaceAll(RegExp(r'\(.*?\)'), '').replaceAll(RegExp(r'\[.*?\]'), '').trim();
      final searchResult = await _yt.search.search('$artist $cleanTitle music video');
      
      if (searchResult.isNotEmpty) {
        final video = searchResult.first;
        return await getVideoStreamUrl(video.id.value);
      }
      return null;
    } catch (e) {
      print('Error finding background video: $e');
      return null;
    }
  }

  /// Gets all tracks from a specific playlist or album ID.
  Future<List<Map<String, String>>> getPlaylistTracks(String playlistId, {String? fallbackQuery}) async {
    try {
      final videos = await _yt.playlists.getVideos(playlistId).toList();
      
      // WORKAROUND: If youtube_explode_dart fails to parse the playlist (returns 0 videos),
      // we fallback to searching the playlist title and returning those songs!
      if (videos.isEmpty && fallbackQuery != null) {
        final fallbackVideos = await _yt.search.search(fallbackQuery);
        return fallbackVideos.take(30).map((video) {
          return {
            'id': video.id.value,
            'title': video.title,
            'subtitle': video.author,
            'imageUrl': video.thumbnails.highResUrl,
            'type': 'song',
            'duration': video.duration != null ? '${video.duration!.inMinutes}:${(video.duration!.inSeconds % 60).toString().padLeft(2, '0')}' : '',
          };
        }).toList();
      }
      
      return videos.map((video) {
        return {
          'id': video.id.value,
          'title': video.title,
          'subtitle': video.author,
          'imageUrl': video.thumbnails.highResUrl,
          'type': 'song',
          'duration': video.duration != null ? '${video.duration!.inMinutes}:${(video.duration!.inSeconds % 60).toString().padLeft(2, '0')}' : '',
        };
      }).toList();
    } catch (e) {
      print('Error getting playlist tracks: $e');
      return [];
    }
  }

  /// Gets top songs/uploads from a specific artist channel ID.
  Future<List<Map<String, String>>> getArtistTopSongs(String channelId, {String? fallbackArtistName}) async {
    try {
      // Just fetch the first 20 recent uploads/songs from the channel
      final videos = await _yt.channels.getUploads(ChannelId(channelId)).take(20).toList();
      
      if (videos.isEmpty && fallbackArtistName != null) {
        // VEVO or Topic channels might not have uploads playlist. Fallback to search!
        final fallbackVideos = await _yt.search.search('$fallbackArtistName song');
        return fallbackVideos.take(15).map((video) {
          return {
            'id': video.id.value,
            'title': video.title,
            'subtitle': video.author,
            'imageUrl': video.thumbnails.highResUrl,
            'type': 'song',
            'duration': video.duration != null ? '${video.duration!.inMinutes}:${(video.duration!.inSeconds % 60).toString().padLeft(2, '0')}' : '',
          };
        }).toList();
      }

      return videos.map((video) {
        return {
          'id': video.id.value,
          'title': video.title,
          'subtitle': video.author,
          'imageUrl': video.thumbnails.highResUrl,
          'type': 'song',
          'duration': video.duration != null ? '${video.duration!.inMinutes}:${(video.duration!.inSeconds % 60).toString().padLeft(2, '0')}' : '',
        };
      }).toList();
    } catch (e) {
      print('Error getting artist songs: $e');
      return [];
    }
  }

  /// Gets Albums for an artist by searching for them
  Future<List<Map<String, String>>> getArtistAlbums(String artistName) async {
    try {
      final searchResults = await _yt.search.search('$artistName full album');
      return searchResults.take(10).map((video) {
        return {
          'id': video.id.value,
          'title': video.title,
          'subtitle': 'Album • ${video.author}',
          'imageUrl': video.thumbnails.highResUrl,
          'type': 'album',
          'duration': '', // Albums can be handled as long videos for now or playlists if we filter
        };
      }).toList();
    } catch (e) {
      print('Error getting artist albums: $e');
      return [];
    }
  }

  /// Gets Singles & EPs for an artist by searching for them
  Future<List<Map<String, String>>> getArtistSingles(String artistName) async {
    try {
      final searchResults = await _yt.search.search('$artistName single');
      return searchResults.take(10).map((video) {
        return {
          'id': video.id.value,
          'title': video.title,
          'subtitle': 'Single • ${video.author}',
          'imageUrl': video.thumbnails.highResUrl,
          'type': 'song',
          'duration': video.duration != null ? '${video.duration!.inMinutes}:${(video.duration!.inSeconds % 60).toString().padLeft(2, '0')}' : '',
        };
      }).toList();
    } catch (e) {
      print('Error getting artist singles: $e');
      return [];
    }
  }

  /// Finds an artist's channel ID and details by their name
  Future<Map<String, String>?> getArtistByName(String artistName) async {
    try {
      final videos = await _yt.search.search(artistName);
      if (videos.isNotEmpty) {
        final video = videos.first;
        try {
          final channel = await _yt.channels.get(video.channelId);
          // YouTube channel avatars are often 800x800 or 900x900 natively which is perfect for headers
          return {
            'id': video.channelId.value,
            'title': channel.title,
            'subtitle': 'Artist',
            'imageUrl': channel.logoUrl,
            'type': 'artist'
          };
        } catch (e) {
          // Fallback if channel fetch fails
          return {
            'id': video.channelId.value,
            'title': video.author,
            'subtitle': 'Artist',
            'imageUrl': video.thumbnails.highResUrl,
            'type': 'artist'
          };
        }
      }
    } catch (e) {
      print('Error finding artist: $e');
    }
    return null;
  }

  void dispose() {
    _yt.close();
  }
}
