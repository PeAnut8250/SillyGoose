import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../components/floating_bottom_bar.dart';
import '../../data/api/audio_service.dart';
import '../../data/settings_service.dart';
import '../components/mini_player.dart';
import '../components/dynamic_background.dart';
import '../../data/scroll_service.dart';
import '../components/liquid_glass.dart';

class ScaffoldWithNavBar extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
  });

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  int _previousIndex = 0;

  void _onTabSelected(int index) {
    if (widget.navigationShell.currentIndex != index) {
      setState(() {
        _previousIndex = widget.navigationShell.currentIndex;
      });
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DynamicBackground(
            child: widget.navigationShell,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ListenableBuilder(
              listenable: Listenable.merge([AudioService(), ScrollService()]),
              builder: (context, _) {
                final track = AudioService().currentTrack;
                if (track == null) return const SizedBox.shrink();

                final isInline = ScrollService().isScrolledDown;

                return SizedBox(
                  height: 200, // Fixed height to contain the animations safely
                  child: Stack(
                    children: [
                      // MiniPlayer
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        left: isInline ? (16.0 + 42.0 + 8.0) : 16.0,
                        right: isInline ? (16.0 + 42.0 + 8.0) : 16.0,
                        bottom: isInline ? 24.0 : (24.0 + 48.0 + 4.0), // 48 is the new expanded bar height, 4px gap
                        height: isInline ? 42.0 : 48.0, // Shrunk from 56 to 48
                        child: MiniPlayer(
                          track: track,
                          isInline: isInline,
                        ),
                      ),
                      
                      // FloatingBottomBar (Tabs)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        left: 16.0,
                        width: isInline ? 42.0 : MediaQuery.of(context).size.width - 88.0, // 88 = 16 left + 16 right + 48 search width + 8 gap
                        bottom: 24.0,
                        height: isInline ? 42.0 : 48.0, // Shrunk from 56 to 48
                        child: FloatingBottomBar(
                          selectedIndex: widget.navigationShell.currentIndex,
                          previousIndex: _previousIndex,
                          onTabSelected: _onTabSelected,
                          isInline: isInline,
                        ),
                      ),

                      // Search Button (Always visible as separate circle)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        right: 16.0,
                        bottom: 24.0, // Aligned with the 48px nav bar
                        width: isInline ? 42.0 : 48.0, // Shrunk from 56 to 48
                        height: isInline ? 42.0 : 48.0, // Shrunk from 56 to 48
                        child: ListenableBuilder(
                          listenable: SettingsService(),
                          builder: (context, _) {
                            final isSearchSelected = widget.navigationShell.currentIndex == 3;
                            return LiquidGlass(
                              forceOpaque: !SettingsService().liquidGlass,
                              borderRadius: BorderRadius.circular(100),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: isSearchSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.15) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.search,
                                    color: isSearchSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                                    size: isInline ? 20 : 24,
                                  ),
                                  onPressed: () {
                                    _onTabSelected(3);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: AudioService(),
        builder: (context, _) {
          // If a track is playing, the FloatingBottomBar is part of the Stack above
          if (AudioService().currentTrack != null) return const SizedBox.shrink();
          
          return FloatingBottomBar(
            selectedIndex: widget.navigationShell.currentIndex,
            previousIndex: _previousIndex,
            onTabSelected: _onTabSelected,
          );
        },
      ),
    );
  }}
