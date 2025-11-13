import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double height;
  final Color borderColor;
  

  const GlassCard({
    super.key,
    required this.child,
    this.height = 120,
    
    this.borderColor = const Color.fromARGB(19, 0, 0, 0),
  });

  @override
  Widget build(BuildContext context) {
    const double radius = 12;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(14, 0, 0, 0),
            blurRadius: 32,
            spreadRadius: -14,
            offset: const Offset(0, 24),
          ),
          BoxShadow(
            color: borderColor.withOpacity(0.05),
            blurRadius: 18,
            spreadRadius: -12,
            offset: const Offset(-10, -8),
          ),
        ],
      ),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: height,
        borderRadius: radius,
        blur: 26,
        alignment: Alignment.center,
        border: 1.2,
        linearGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color.fromARGB(0, 0, 0, 0),
            const Color.fromARGB(0, 0, 0, 0),
          ],
        ),

        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            borderColor.withOpacity(0.1),
            borderColor.withOpacity(0.05),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.fromARGB(0, 0, 0, 0), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: const Color.fromARGB(28, 255, 255, 255),
                    width: 0.9,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [
                      const Color.fromARGB(0, 0, 0, 0),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class AppColors {
  static const Color primary = Color.fromARGB(0, 0, 0, 0);
  static const Color secondary = Color.fromARGB(0, 0, 0, 0);
  static const Color accent = Color(0xFF0A84FF);
  static const Color background = Color.fromARGB(0, 0, 0, 0);
  static const Color cardBackground = Color.fromARGB(0, 0, 0, 0);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAEAEB2);

  // Status colors
  static const Color cpuColor = Color(0xFF30D158);
  static const Color ramColor = Color(0xFFFF453A);
  static const Color networkColor = Color(0xFF32ADE6);
  static const Color diskColor = Color(0xFFFFD60A);

  // Glass effect colors
  static const Color glassLight = Color.fromARGB(0, 255, 255, 255);
  static const Color glassDark = Color.fromARGB(0, 0, 0, 0);
}
