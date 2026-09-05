import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'screens/scaffold_with_nav_bar.dart';
import 'screens/replay_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      navigatorContainerBuilder: (context, navigationShell, children) {
        return AnimatedBranchContainer(
          currentIndex: navigationShell.currentIndex,
          children: children,
        );
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/explore',
              builder: (context, state) => const ExploreScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryScreen(),
              routes: [
                GoRoute(
                  path: 'replay',
                  builder: (context, state) => const ReplayScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class AnimatedBranchContainer extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;
  const AnimatedBranchContainer({super.key, required this.currentIndex, required this.children});

  @override
  State<AnimatedBranchContainer> createState() => _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<AnimatedBranchContainer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _currentIndex;
  late int _previousIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _controller.value = 1.0;
    _currentIndex = widget.currentIndex;
    _previousIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(covariant AnimatedBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _currentIndex = widget.currentIndex;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.children.length, (index) {
        final bool isCurrent = index == _currentIndex;
        final bool isPrevious = index == _previousIndex;
        
        if (!isCurrent && !isPrevious) {
          return Offstage(offstage: true, child: widget.children[index]);
        }

        final bool isMovingRight = _currentIndex > _previousIndex;
        
        final slideIn = Tween<Offset>(
          begin: Offset(isMovingRight ? 1.0 : -1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

        final slideOut = Tween<Offset>(
          begin: Offset.zero,
          end: Offset(isMovingRight ? -1.0 : 1.0, 0.0),
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

        return Offstage(
          offstage: false,
          child: SlideTransition(
            position: isCurrent ? slideIn : slideOut,
            child: widget.children[index],
          ),
        );
      }),
    );
  }
}
