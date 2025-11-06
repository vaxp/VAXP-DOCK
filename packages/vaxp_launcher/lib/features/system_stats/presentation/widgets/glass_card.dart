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
    return GlassmorphicContainer(
      width: double.infinity,
      height: height,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 1,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.glassLight,
          AppColors.glassDark,
        ],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          // ignore: deprecated_member_use
          borderColor.withOpacity(0.5),
          // ignore: deprecated_member_use
          borderColor.withOpacity(0.2),
        ],
      ),
      child: child,
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