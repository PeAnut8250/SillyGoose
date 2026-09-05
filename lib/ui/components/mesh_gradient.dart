import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

class MeshGradientBackground extends StatefulWidget {
  final String? imageUrl;
  final bool animated;
  final double blurRadius;
  final int driftMillis;

  const MeshGradientBackground({
    super.key,
    this.imageUrl,
    this.animated = true,
    this.blurRadius = 64.0,
    this.driftMillis = 8000,
  });

  @override
  State<MeshGradientBackground> createState() => _MeshGradientBackgroundState();
}

class _MeshGradientBackgroundState extends State<MeshGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<Color> _colors = _fallbackColors;

  static const List<Color> _fallbackColors = [
    Color(0xFF3A1C71),
    Color(0xFFD76D77),
    Color(0xFF2B5876),
    Color(0xFFFFAF7B),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.driftMillis * 4),
    );
    if (widget.animated) {
      _controller.repeat();
    }
    _extractColors();
  }

  @override
  void didUpdateWidget(MeshGradientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animated != widget.animated) {
      if (widget.animated) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
    if (oldWidget.imageUrl != widget.imageUrl) {
      _extractColors();
    }
  }

  Future<void> _extractColors() async {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      if (mounted) setState(() => _colors = _fallbackColors);
      return;
    }

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(widget.imageUrl!),
        maximumColorCount: 24,
      );

      final swatches = palette.paletteColors.toList()
        ..sort((a, b) => b.population.compareTo(a.population));

      List<Color> extracted = [];
      for (var swatch in swatches) {
        // Boost saturation and adjust lightness for richer mesh colors
        var hsl = HSLColor.fromColor(swatch.color);
        double s = (hsl.saturation * 1.35).clamp(0.0, 1.0);
        double l = hsl.lightness.clamp(0.28, 0.58);
        var tuned = hsl.withSaturation(s).withLightness(l).toColor();
        
        if (!extracted.any((c) => _isCloseTo(c, tuned))) {
          extracted.add(tuned);
        }
      }

      if (extracted.isEmpty) {
        extracted = _fallbackColors;
      } else if (extracted.length < 4) {
        // Fill shortfalls
        int step = 1;
        while (extracted.length < 4) {
          int index = (extracted.length - 1) % extracted.length;
          var hsl = HSLColor.fromColor(extracted[index]);
          double h = (hsl.hue + 24.0 * step) % 360.0;
          double l = (hsl.lightness + 0.12 * step).clamp(0.2, 0.7);
          extracted.add(hsl.withHue(h).withLightness(l).toColor());
          step++;
        }
      }

      if (mounted) {
        setState(() {
          _colors = extracted.take(4).toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _colors = _fallbackColors);
    }
  }

  bool _isCloseTo(Color a, Color b) {
    var hslA = HSLColor.fromColor(a);
    var hslB = HSLColor.fromColor(b);
    double hueGap = (hslA.hue - hslB.hue).abs();
    hueGap = math.min(hueGap, 360.0 - hueGap);
    return hueGap < 15.0 && (hslA.lightness - hslB.lightness).abs() < 0.12;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We animate the colors over time when they change!
    return AnimatedContainer(
      duration: const Duration(milliseconds: 1400),
      color: _colors.isNotEmpty 
          ? HSLColor.fromColor(_colors[0]).withLightness(0.05).toColor() // Extremely dark base color
          : Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: Transform.scale(
              scale: 1.3,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: MeshGradientPainter(
                      colors: _colors,
                      phase: _controller.value * 2 * math.pi,
                    ),
                    child: Container(),
                  );
                },
              ),
            ),
          ),
          // Heavy dimming overlay to make sure text and glass widgets look premium and readable
          Container(
            color: Colors.black.withOpacity(0.7),
          ),
        ],
      ),
    );
  }
}

class MeshGradientPainter extends CustomPainter {
  final List<Color> colors;
  final double phase;

  MeshGradientPainter({required this.colors, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.length < 4) return;

    final anchors = [
      const Offset(0.20, 0.25),
      const Offset(0.80, 0.20),
      const Offset(0.75, 0.80),
      const Offset(0.25, 0.75),
    ];
    final speeds = [1.0, -0.7, 0.85, -1.15];

    for (int i = 0; i < 4; i++) {
      double driftX = 0.16 * math.cos(phase * speeds[i] + i * 1.7);
      double driftY = 0.16 * math.sin(phase * speeds[i] * 0.9 + i * 2.3);
      
      Offset center = Offset(
        (anchors[i].dx + driftX) * size.width,
        (anchors[i].dy + driftY) * size.height,
      );

      double radius = math.max(size.width, size.height) * 0.62;

      final paint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [colors[i].withOpacity(0.85), colors[i].withOpacity(0.0)],
        );
      
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MeshGradientPainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.colors != colors;
  }
}
