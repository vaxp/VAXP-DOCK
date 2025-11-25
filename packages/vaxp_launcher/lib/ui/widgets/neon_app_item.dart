import 'package:flutter/material.dart';

class NeonAppItem extends StatefulWidget {
  final Widget child;
  final bool isFocused; // Maps to isRunning
  final VoidCallback onTap;

  const NeonAppItem({
    super.key,
    required this.child,
    this.isFocused = false,
    required this.onTap,
  });

  @override
  State<NeonAppItem> createState() => _NeonAppItemState();
}

class _NeonAppItemState extends State<NeonAppItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Control rotation speed: fast for focused (2s), slow for unfocused (6s)
    _controller = AnimationController(
      vsync: this,
      duration: widget.isFocused
          ? const Duration(seconds: 2)
          : const Duration(seconds: 6),
    );

    _controller.repeat();
  }

  @override
  void didUpdateWidget(NeonAppItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused != oldWidget.isFocused) {
      _controller.stop();
      _controller.duration = widget.isFocused
          ? const Duration(seconds: 2)
          : const Duration(seconds: 6);
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 64, // Adjusted to match launcher icon size
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Neon ring layer (only visible if focused/running, or always if desired)
            // User requested "add neon around the application being run", so we'll
            // only show it if isFocused is true, OR we can follow the provided code
            // which shows it always but with different colors.
            // The provided code shows it always. I will stick to that but maybe
            // make the inactive state transparent if it looks too busy.
            // For now, I'll use the provided code's logic exactly.
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(64, 64),
                  painter: _NeonRingPainter(
                    rotation: _controller.value,
                    isFocused: widget.isFocused,
                  ),
                );
              },
            ),
            // The icon in the center
            widget.child,
          ],
        ),
      ),
    );
  }
}

class _NeonRingPainter extends CustomPainter {
  final double rotation;
  final bool isFocused;

  const _NeonRingPainter({this.rotation = 0.0, this.isFocused = false});

  @override
  void paint(Canvas canvas, Size size) {
    // Only paint if focused (running), to avoid cluttering the launcher with rings around everything
    // OR if the user wants it always. The user said "add neon around the application being run".
    // So I will hide it if not focused.
    if (!isFocused) return;

    final center = Offset(size.width / 2, size.height / 2);

    final rect = Rect.fromCenter(
      center: center,
      width: size.width + 8, // Slightly larger than icon
      height: size.height + 8,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(20), // Soft corners
    );

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);

    final Rect shaderRect = Rect.fromCircle(
      center: center,
      radius: size.width / 2 + 10,
    );

    // Cyan/Purple gradient for running apps
    paint.shader = SweepGradient(
      colors: const [
        Colors.transparent,
        Colors.cyanAccent,
        Colors.purpleAccent,
        Colors.cyanAccent,
      ],
      stops: const [0.0, 0.5, 0.75, 1.0],
      transform: GradientRotation(rotation * 2 * 3.14159),
    ).createShader(shaderRect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_NeonRingPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.isFocused != isFocused;
  }
}
