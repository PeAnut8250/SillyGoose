import 'dart:ui';
import 'package:flutter/material.dart';
import '../../data/api/audio_service.dart';
import '../../data/scroll_service.dart';
import '../player/player_screen.dart';
import '../../data/settings_service.dart';
import 'liquid_glass.dart';

class MiniPlayer extends StatelessWidget {
  final Map<String, String> track;
  final bool isInline;

  const MiniPlayer({super.key, required this.track, this.isInline = false});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
        key: ValueKey(track['id']),
        background: Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: 32.0),
          child: Icon(Icons.skip_previous_rounded, color: Theme.of(context).colorScheme.onSurface, size: 36),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 32.0),
          child: Icon(Icons.skip_next_rounded, color: Theme.of(context).colorScheme.onSurface, size: 36),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            AudioService().skipToNext();
          } else if (direction == DismissDirection.startToEnd) {
            AudioService().skipToPrevious();
          }
          return false;
        },
        child: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const PlayerScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.05),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                      child: child,
                    ),
                  );
                },
                transitionDuration: const Duration(milliseconds: 300),
                reverseTransitionDuration: const Duration(milliseconds: 250),
                fullscreenDialog: true,
              ),
            );
          },
          child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: ListenableBuilder(
            listenable: SettingsService(),
            builder: (context, _) {
              return LiquidGlass(
                forceOpaque: !SettingsService().liquidGlass,
                borderRadius: BorderRadius.circular(100),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  height: isInline ? 42 : 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isInline ? 28 : 40,
                        height: isInline ? 28 : 40,
                        child: Image.network(
                          track['imageUrl']!,
                          fit: BoxFit.cover,
                          cacheWidth: 150,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ClipRect(
                        child: OverflowBox(
                          maxHeight: 100,
                          alignment: Alignment.centerLeft,
                          child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track['title']!,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: isInline ? 14 : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!isInline)
                              Text(
                                track['subtitle']!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ListenableBuilder(
                      listenable: AudioService(),
                      builder: (context, _) {
                        final isPlaying = AudioService().isPlaying;
                        final isLoading = AudioService().isLoading;
                        
                        if (isLoading) {
                          return Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onSurface),
                              ),
                            ),
                          );
                        }
                        
                        return IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: isInline ? 24 : 32,
                          ),
                          padding: isInline ? EdgeInsets.zero : EdgeInsets.all(8.0),
                          onPressed: () {
                            AudioService().togglePlayPause();
                          },
                        );
                      },
                    ),
                    SizedBox(width: 8),
                  ],
                ),
              ),
              );
            },
          ),
        ),
      ),
    );
  }
}
