import 'package:flutter/material.dart';

/// Widget يرسم حدود نيون دوارة حول الـ dock
class AnimatedNeonBorder extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double borderWidth;

  const AnimatedNeonBorder({
    super.key,
    required this.child,
    this.borderRadius = 18.0,
    this.borderWidth = 1.5,
  });

  @override
  State<AnimatedNeonBorder> createState() => _AnimatedNeonBorderState();
}

class _AnimatedNeonBorderState extends State<AnimatedNeonBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _NeonBorderPainter(
            rotation: _controller.value,
            borderRadius: widget.borderRadius,
            borderWidth: widget.borderWidth,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _NeonBorderPainter extends CustomPainter {
  final double rotation;
  final double borderRadius;
  final double borderWidth;

  const _NeonBorderPainter({
    required this.rotation,
    required this.borderRadius,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // إنشاء التدرج الدوار
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = SweepGradient(
        colors: const [
          Colors.transparent,
          Colors.cyanAccent,
          Color.fromARGB(255, 0, 255, 170),
          Colors.cyanAccent,
          Color.fromARGB(0, 0, 122, 106),
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
        transform: GradientRotation(rotation * 2 * 3.14159),
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_NeonBorderPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}
