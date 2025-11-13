import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaxp_launcher/features/settings/domain/models/launcher_settings.dart';

class SettingsRepository {
  static const _colorKey = 'launcher_bg_color';
  static const _opacityKey = 'launcher_opacity';
  static const _imageKey = 'launcher_bg_image';
  static const _iconThemeKey = 'launcher_icon_theme';

  Future<LauncherSettings> loadSettings() async {
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

  Future<void> saveSettings(LauncherSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, settings.backgroundColor.value);
    await prefs.setDouble(_opacityKey, settings.opacity);
    if (settings.backgroundImagePath == null ||
        settings.backgroundImagePath!.isEmpty) {
      await prefs.remove(_imageKey);
    } else {
      await prefs.setString(_imageKey, settings.backgroundImagePath!);
    }
    if (settings.iconThemePath == null || settings.iconThemePath!.isEmpty) {
      await prefs.remove(_iconThemeKey);
    } else {
      await prefs.setString(_iconThemeKey, settings.iconThemePath!);
    }
  }
}

