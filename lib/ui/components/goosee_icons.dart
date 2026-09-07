import 'package:flutter/material.dart';

/// Vector icons for Shuffle, Repeat, and Infinity.
class GooseeShuffleIcon extends StatelessWidget {
  final Color? color;
  final double size;

  const GooseeShuffleIcon({
    super.key,
    this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? Colors.white;
    return CustomPaint(
      size: Size(size, size),
      painter: _GooseeShufflePainter(color: iconColor),
    );
  }
}

class _GooseeShufflePainter extends CustomPainter {
  final Color color;

  _GooseeShufflePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path1 = Path()
      ..moveTo(3.4, 7.4)
      ..lineTo(7.0, 7.4)
      ..lineTo(16.6, 16.6)
      ..lineTo(20.6, 16.6);
    canvas.drawPath(path1, paint);

    final arrow1 = Path()
      ..moveTo(18.1, 14.1)
      ..lineTo(20.6, 16.6)
      ..lineTo(18.1, 19.1);
    canvas.drawPath(arrow1, paint);

    final path2 = Path()
      ..moveTo(3.4, 16.6)
      ..lineTo(7.0, 16.6)
      ..lineTo(9.8, 13.9);
    canvas.drawPath(path2, paint);

    final path3 = Path()
      ..moveTo(13.9, 10.1)
      ..lineTo(16.6, 7.4)
      ..lineTo(20.6, 7.4);
    canvas.drawPath(path3, paint);

    final arrow2 = Path()
      ..moveTo(18.1, 4.9)
      ..lineTo(20.6, 7.4)
      ..lineTo(18.1, 9.9);
    canvas.drawPath(arrow2, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GooseeShufflePainter oldDelegate) =>
      oldDelegate.color != color;
}

class GooseeRepeatIcon extends StatelessWidget {
  final Color? color;
  final double size;
  final bool isOne;

  const GooseeRepeatIcon({
    super.key,
    this.color,
    this.size = 24,
    this.isOne = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? Colors.white;
    return CustomPaint(
      size: Size(size, size),
      painter: _GooseeRepeatPainter(color: iconColor, isOne: isOne),
    );
  }
}

class _GooseeRepeatPainter extends CustomPainter {
  final Color color;
  final bool isOne;

  _GooseeRepeatPainter({required this.color, required this.isOne});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final loop = Path()
      ..moveTo(8.6, 7.6)
      ..lineTo(15.4, 7.6)
      ..arcToPoint(
        const Offset(15.4, 16.4),
        radius: const Radius.circular(4.4),
        clockwise: true,
      )
      ..lineTo(8.6, 16.4)
      ..arcToPoint(
        const Offset(8.6, 7.6),
        radius: const Radius.circular(4.4),
        clockwise: true,
      )
      ..close();
    canvas.drawPath(loop, paint);

    final arrowTop = Path()
      ..moveTo(13.5, 5.7)
      ..lineTo(15.4, 7.6)
      ..lineTo(13.5, 9.5);
    canvas.drawPath(arrowTop, paint);

    final arrowBottom = Path()
      ..moveTo(10.5, 14.5)
      ..lineTo(8.6, 16.4)
      ..lineTo(10.5, 18.3);
    canvas.drawPath(arrowBottom, paint);

    if (isOne) {
      final onePath = Path()
        ..moveTo(11.2, 10.4)
        ..lineTo(12.2, 9.6)
        ..lineTo(12.2, 14.4);
      canvas.drawPath(onePath, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GooseeRepeatPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isOne != isOne;
}

class GooseeInfinityIcon extends StatelessWidget {
  final Color? color;
  final double size;

  const GooseeInfinityIcon({
    super.key,
    this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? Colors.white;
    return CustomPaint(
      size: Size(size, size),
      painter: _GooseeInfinityPainter(color: iconColor),
    );
  }
}

class _GooseeInfinityPainter extends CustomPainter {
  final Color color;

  _GooseeInfinityPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(12, 12)
      ..cubicTo(10.1, 9.1, 8.7, 8, 7.1, 8)
      ..arcToPoint(
        const Offset(7.1, 16),
        radius: const Radius.circular(4),
        clockwise: false,
      )
      ..cubicTo(8.7, 16, 10.1, 14.9, 12, 12)
      ..cubicTo(13.9, 9.1, 15.3, 8, 16.9, 8)
      ..arcToPoint(
        const Offset(16.9, 16),
        radius: const Radius.circular(4),
        clockwise: true,
      )
      ..cubicTo(15.3, 16, 13.9, 14.9, 12, 12);

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GooseeInfinityPainter oldDelegate) =>
      oldDelegate.color != color;
}
