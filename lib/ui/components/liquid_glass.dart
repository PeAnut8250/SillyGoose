import 'dart:ui';
import 'package:flutter/material.dart';
import '../../data/settings_service.dart';

class LiquidGlass extends StatelessWidget {
  final Widget? child;
  final BorderRadius? borderRadius;
  final bool forceOpaque;

  const LiquidGlass({
    super.key,
    this.child,
    this.borderRadius,
    this.forceOpaque = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final reduceBlur = SettingsService().reduceBlur;
        if (forceOpaque || reduceBlur) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(reduceBlur ? 0.95 : 1.0),
              borderRadius: borderRadius,
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12), width: 0.5),
            ),
            child: child,
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final tintColor = isDark ? const Color(0xFF121212) : const Color(0xFFE0E0E0);

        const double s = 4.9;
        final saturationMatrix = <double>[
          0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0,
          0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0,
          0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0,
          0, 0, 0, 1, 0,
        ];

        final filter = ImageFilter.compose(
          outer: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
          inner: ColorFilter.matrix(saturationMatrix),
        );

        Widget glassContent = BackdropFilter(
          filter: filter,
          child: Container(
            color: tintColor.withOpacity(0.25),
            foregroundDecoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.10),
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.10),
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.10),
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.10),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(isDark ? 0.10 : 0.25),
                width: 0.5,
              ),
            ),
            child: child,
          ),
        );

        if (borderRadius != null) {
          return ClipRRect(
            borderRadius: borderRadius!,
            child: glassContent,
          );
        }

        return glassContent;
      },
    );
  }
}
