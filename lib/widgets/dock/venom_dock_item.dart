import 'dart:math' as math;
import 'package:flutter/material.dart';

class VenomDockItem extends StatefulWidget {
  final Widget child;
  final bool isFocused; // هل التطبيق نشط؟
  final VoidCallback onTap;

  const VenomDockItem({
    super.key,
    required this.child,
    this.isFocused = false,
    required this.onTap,
  });

  @override
  State<VenomDockItem> createState() => _VenomDockItemState();
}

class _VenomDockItemState extends State<VenomDockItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // تحكم في سرعة الدوران (ثانيتين للدورة الكاملة)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    if (widget.isFocused) _controller.repeat();
  }

  @override
  void didUpdateWidget(VenomDockItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // التحكم الذكي: أوقف الدوران إذا فقد التركيز لتوفير الموارد
    if (widget.isFocused != oldWidget.isFocused) {
      if (widget.isFocused) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
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
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 45,
        height: 45,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // طبقة الحلقة النيون الدوارة (تظهر فقط عند التركيز)
            if (widget.isFocused)
              RotationTransition(
                turns: _controller,
                // 🔥 التحسين: RepaintBoundary يعزل الرسم ويحفظه كطبقة في الـ GPU
                // استخدام const هنا يمنع إعادة بناء الودجت غير الضرورية
                child: const RepaintBoundary(
                  child: CustomPaint(
                    size: Size(45, 45),
                    painter: _NeonRingPainter(),
                  ),
                ),
              ),
            // الأيقونة في المنتصف
            widget.child,
          ],
        ),
      ),
    );
  }
}

class _NeonRingPainter extends CustomPainter {
  // جعل الكونستركتور const لتحسين الأداء
  const _NeonRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 3; // نصف القطر

    // إعداد فرشاة النيون
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          3.0 // سماكة الحلقة
      ..strokeCap = StrokeCap.round
      // تأثير التوهج (Neon Glow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);

    // التدرج اللوني (Venom Colors)
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    paint.shader = const SweepGradient(
      colors: [
        Colors.transparent,
        Colors.cyanAccent,
        Colors.purpleAccent,
        Colors.cyanAccent,
      ],
      stops: [0.0, 0.5, 0.75, 1.0],
    ).createShader(rect);

    // رسم الحلقة
    canvas.drawArc(rect, 0, math.pi * 2, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
