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
    // تحكم في سرعة الدوران: سريع للنشط (2 ثانية)، بطيء لغير النشط (6 ثواني)
    _controller = AnimationController(
      vsync: this,
      duration: widget.isFocused
          ? const Duration(seconds: 2) // سريع للتطبيقات النشطة
          : const Duration(seconds: 6), // بطيء للتطبيقات غير النشطة
    );

    _controller.repeat(); // دائماً يدور (نشط أو غير نشط)
  }

  @override
  void didUpdateWidget(VenomDockItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // تغيير سرعة الدوران عند تغيير حالة التركيز
    if (widget.isFocused != oldWidget.isFocused) {
      _controller.stop();
      _controller.duration = widget.isFocused
          ? const Duration(seconds: 2) // سريع للنشط
          : const Duration(seconds: 6); // بطيء لغير النشط
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
        width: 45,
        height: 45,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // طبقة الحلقة النيون الدوارة (دائماً تظهر)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(45, 45),
                  painter: _NeonRingPainter(
                    rotation: _controller.value,
                    isFocused: widget.isFocused,
                  ),
                );
              },
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
  final double rotation; // قيمة الدوران من 0.0 إلى 1.0
  final bool isFocused; // هل التطبيق نشط؟

  const _NeonRingPainter({this.rotation = 0.0, this.isFocused = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // إنشاء مربع دائري (Squircle) بدلاً من دائرة
    final rect = Rect.fromCenter(
      center: center,
      width: size.width - 6,
      height: size.height - 6,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(10), // زوايا دائرية ناعمة
    );

    // إعداد فرشاة النيون
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          1.0 // سماكة الحلقة
      ..strokeCap = StrokeCap.round
      // تأثير التوهج (Neon Glow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);

    // التدرج اللوني مع الدوران - ألوان مختلفة حسب الحالة
    final Rect shaderRect = Rect.fromCircle(
      center: center,
      radius: size.width / 2,
    );

    if (isFocused) {
      // تطبيق نشط: سيان/بنفسجي
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
    } else {
      // تطبيق غير نشط: أحمر متدرج
      paint.shader = SweepGradient(
        colors: const [
          Colors.transparent,
          Color(0xFFFF1744), // أحمر نيون
          Color(0xFFFF5252), // أحمر فاتح
          Color(0xFFFF1744), // أحمر نيون
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
        transform: GradientRotation(rotation * 2 * 3.14159),
      ).createShader(shaderRect);
    }

    // رسم المربع الدائري (ثابت)
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_NeonRingPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.isFocused != isFocused;
  }
}
