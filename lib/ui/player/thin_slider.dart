import 'package:flutter/material.dart';

class ThinSlider extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration>? onChanged;

  const ThinSlider({
    super.key,
    required this.position,
    required this.duration,
    this.onChanged,
  });

  @override
  State<ThinSlider> createState() => _ThinSliderState();
}

class _ThinSliderState extends State<ThinSlider> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    final double max = widget.duration.inMilliseconds.toDouble();
    final double value = _isDragging 
        ? _dragValue 
        : widget.position.inMilliseconds.toDouble().clamp(0, max);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double fraction = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
        
        final double height = _isDragging ? 8.0 : 2.0;

        return GestureDetector(
          onHorizontalDragStart: (details) {
            setState(() {
              _isDragging = true;
              _dragValue = (details.localPosition.dx / width).clamp(0.0, 1.0) * max;
            });
          },
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragValue = (details.localPosition.dx / width).clamp(0.0, 1.0) * max;
            });
          },
          onHorizontalDragEnd: (details) {
            setState(() {
              _isDragging = false;
            });
            if (widget.onChanged != null) {
              widget.onChanged!(Duration(milliseconds: _dragValue.toInt()));
            }
          },
          onTapDown: (details) {
             setState(() {
              _isDragging = true;
              _dragValue = (details.localPosition.dx / width).clamp(0.0, 1.0) * max;
            });
          },
          onTapUp: (details) {
            setState(() {
              _isDragging = false;
            });
            if (widget.onChanged != null) {
              widget.onChanged!(Duration(milliseconds: _dragValue.toInt()));
            }
          },
          child: Container(
            height: 24, // Touch target height
            color: Colors.transparent,
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              height: height,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(height / 2),
              ),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(height / 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
