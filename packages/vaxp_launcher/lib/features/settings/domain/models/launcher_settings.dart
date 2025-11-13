import 'package:flutter/material.dart';

class LauncherSettings {
  final Color backgroundColor;
  final double opacity;
  final String? backgroundImagePath;
  final String? iconThemePath;

  const LauncherSettings({
    required this.backgroundColor,
    required this.opacity,
    this.backgroundImagePath,
    this.iconThemePath,
  });

  LauncherSettings copyWith({
    Color? backgroundColor,
    double? opacity,
    String? backgroundImagePath,
    String? iconThemePath,
  }) {
    return LauncherSettings(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      opacity: opacity ?? this.opacity,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      iconThemePath: iconThemePath ?? this.iconThemePath,
    );
  }
}

