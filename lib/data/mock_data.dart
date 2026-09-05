class MockData {
  static const List<Map<String, dynamic>> homeShelves = [
    {
      'title': 'Listen Now',
      'subtitle': '',
      'isHero': true,
      'items': [
        {
          'id': '1',
          'title': 'Midnight City',
          'subtitle': 'M83 • Hurry Up, We\'re Dreaming',
          'imageUrl': 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?auto=format&fit=crop&q=80&w=500'
        },
        {
          'id': '2',
          'title': 'Blinding Lights',
          'subtitle': 'The Weeknd • After Hours',
          'imageUrl': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&q=80&w=500'
        }
      ]
    },
    {
      'title': 'Mixed for you',
      'subtitle': 'Based on your listening history',
      'isHero': false,
      'items': [
        {
          'id': '3',
          'title': 'Instant Crush',
          'subtitle': 'Daft Punk • Random Access Memories',
          'imageUrl': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&q=80&w=500'
        },
        {
          'id': '4',
          'title': 'Starboy',
          'subtitle': 'The Weeknd • Starboy',
          'imageUrl': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&q=80&w=500'
        }
      ]
    }
  ];

  static const List<Map<String, String>> mockSearchResults = [];
}
