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
    this.borderColor = AppColors.glassLight,
  });

  @override
  Widget build(BuildContext context) {
    const double radius = 24;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 32,
            spreadRadius: -14,
            offset: const Offset(0, 24),
          ),
          BoxShadow(
            color: borderColor.withOpacity(0.25),
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
            AppColors.glassLight.withOpacity(0.9),
            AppColors.glassDark.withOpacity(0.7),
          ],
          stops: const [0.05, 0.95],
        ),
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [borderColor.withOpacity(0.6), borderColor.withOpacity(0.1)],
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
                    colors: [Color(0x4DFFFFFF), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
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
                      Colors.black.withOpacity(0.25),
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
  static const Color primary = Color(0xFF2C2C2E);
  static const Color secondary = Color(0xFF48484A);
  static const Color accent = Color(0xFF0A84FF);
  static const Color background = Color(0xFF1C1C1E);
  static const Color cardBackground = Color(0xFF2C2C2E);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAEAEB2);

  // Status colors
  static const Color cpuColor = Color(0xFF30D158);
  static const Color ramColor = Color(0xFFFF453A);
  static const Color networkColor = Color(0xFF32ADE6);
  static const Color diskColor = Color(0xFFFFD60A);

  // Glass effect colors
  static const Color glassLight = Color(0x0FFFFFFF);
  static const Color glassDark = Color(0x2F000000);
}
