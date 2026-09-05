import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../data/scroll_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: false,
              floating: true,
              expandedHeight: 120,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
                title: Text(
                  'Explore',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16.0,
                  crossAxisSpacing: 16.0,
                  childAspectRatio: 1.5,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final colors = [
                      Colors.purple,
                      Colors.blue,
                      Colors.teal,
                      Colors.orange,
                      Colors.red,
                      Colors.pink,
                    ];
                    final titles = [
                      'New Releases',
                      'Charts',
                      'Moods',
                      'Genres',
                      'Podcasts',
                      'Discover'
                    ];
                    
                    final color = colors[index % colors.length];
                    final title = titles[index % titles.length];
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withOpacity(0.5)),
                      ),
                      child: Center(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: 12,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),
      ),
    );
  }
}
