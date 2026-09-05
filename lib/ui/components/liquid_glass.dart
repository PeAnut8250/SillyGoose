import 'dart:ui';
import 'package:flutter/material.dart';

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
    if (forceOpaque) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: borderRadius,
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
        child: child,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tintColor = isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA);

    // To make it look like "liquid glass" where colors adapt to the background,
    // we must massively boost saturation and remove the dull gray tint.
    const double s = 4.9; // High saturation multiplier
    final saturationMatrix = <double>[
      0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0,
      0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0,
      0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0,
      0, 0, 0, 1, 0,
    ];

    final filter = ImageFilter.compose(
      outer: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5), // Reduced blur for more transparency
      inner: ColorFilter.matrix(saturationMatrix),
    );

    Widget glassContent = BackdropFilter(
      filter: filter,
      child: Container(
        // Extremely subtle tint to let the background shine through clearly
        color: tintColor.withOpacity(0.25),
        foregroundDecoration: BoxDecoration(
          borderRadius: borderRadius,
          // Softer specular liquid reflection gradient so it's less milky
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.10),
              Colors.white.withOpacity(0.10),
              Colors.white.withOpacity(0.10),
              Colors.white.withOpacity(0.10),
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.10),
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
  }
}
