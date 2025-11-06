import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _colorKey = 'launcher_bg_color';
  static const _opacityKey = 'launcher_opacity';
  static const _imageKey = 'launcher_bg_image';
  static const _iconThemeKey = 'launcher_icon_theme';

  Future<LauncherSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final intColor = prefs.getInt(_colorKey);
    final doubleOpacity = prefs.getDouble(_opacityKey);
    final imagePath = prefs.getString(_imageKey);
    final iconThemePath = prefs.getString(_iconThemeKey);
    return LauncherSettings(
      backgroundColor: intColor != null ? Color(intColor) : Colors.black,
      opacity: (doubleOpacity ?? 0.7).clamp(0.0, 1.0),
      backgroundImagePath: imagePath,
      iconThemePath: iconThemePath,
    );
  }

  Future<void> save(LauncherSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, s.backgroundColor.value);
    await prefs.setDouble(_opacityKey, s.opacity);
    if (s.backgroundImagePath == null || s.backgroundImagePath!.isEmpty) {
      await prefs.remove(_imageKey);
    } else {
      await prefs.setString(_imageKey, s.backgroundImagePath!);
    }
    if (s.iconThemePath == null || s.iconThemePath!.isEmpty) {
      await prefs.remove(_iconThemeKey);
    } else {
      await prefs.setString(_iconThemeKey, s.iconThemePath!);
    }
  }
}

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
}


