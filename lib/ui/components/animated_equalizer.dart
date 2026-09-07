import 'package:flutter/material.dart';
import '../../data/settings_service.dart';

class AnimatedEqualizer extends StatefulWidget {
  final bool isAudioPlaying;
  final Color? color;
  
  const AnimatedEqualizer({super.key, required this.isAudioPlaying, this.color});

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    if (widget.isAudioPlaying && !SettingsService().reduceAnimation) {
      _controller.repeat(reverse: true);
    }
  }
  
  @override
  void didUpdateWidget(AnimatedEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAudioPlaying != oldWidget.isAudioPlaying) {
      if (widget.isAudioPlaying && !SettingsService().reduceAnimation) {
        _controller.repeat(reverse: true);
      } else {
        _controller.animateTo(0.0, duration: const Duration(milliseconds: 300));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildBar(0),
        const SizedBox(width: 3),
        _buildBar(1),
        const SizedBox(width: 3),
        _buildBar(2),
      ],
    );
  }

  Widget _buildBar(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Give each bar a different phase offset
        double value = _controller.value;
        if (index == 0) value = (value + 0.3) % 1.0;
        if (index == 2) value = (value + 0.6) % 1.0;
        
        // Convert sawtooth (0 to 1) into a triangle wave (0 to 1 to 0)
        if (value > 0.5) value = 1.0 - value;
        value *= 2.0;

        return Container(
          width: 4,
          height: 6 + (10 * value),
          decoration: BoxDecoration(
            color: widget.color ?? Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}
