import 'dart:ui';
import 'package:flutter/material.dart';
import '../../data/api/audio_service.dart';
import '../../data/settings_service.dart';
import 'mesh_gradient.dart';

class DynamicBackground extends StatelessWidget {
  final Widget child;
  
  const DynamicBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([AudioService(), SettingsService().themeNotifier]),
          builder: (context, _) {
            final theme = SettingsService().theme;
            
            if (theme == 'Cool') {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF273833), // Dark teal
                      Color(0xFF281816), // Dark brownish red
                      Color(0xFF121212), // Deep black
                    ],
                    stops: [0.0, 0.4, 1.0],
                  ),
                ),
              );
            }

            final isDynamic = theme == 'Dynamic' || theme == 'Shuffle Dynamic';
            final track = AudioService().currentTrack;
            
            if (!isDynamic || track == null) {
              return Container(color: Theme.of(context).scaffoldBackgroundColor);
            }
            
            return MeshGradientBackground(
              imageUrl: track['imageUrl']!,
              animated: !SettingsService().reduceAnimation,
            );
          },
        ),
        child,
      ],
    );
  }
}
