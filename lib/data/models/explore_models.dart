class MoodGenreSection {
  final String title;
  final List<MoodGenreItem> items;
  
  MoodGenreSection({required this.title, required this.items});
}

class MoodGenreItem {
  final String title;
  final String browseId;
  final String params;
  String? thumbnailUrl;

  MoodGenreItem({
    required this.title,
    required this.browseId,
    required this.params,
    this.thumbnailUrl,
  });
}

class ExplorePlaylistShelf {
  final String title;
  final List<ExplorePlaylistItem> items;
  final String? strapline;

  ExplorePlaylistShelf({
    required this.title,
    required this.items,
    this.strapline,
  });
}

class ExplorePlaylistItem {
  final String title;
  final String subtitle;
  final String thumbnailUrl;
  final String browseId;
  
  ExplorePlaylistItem({
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
    required this.browseId,
  });
}
