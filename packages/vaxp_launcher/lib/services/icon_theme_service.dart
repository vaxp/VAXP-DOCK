import 'dart:io';
import 'package:vaxp_core/models/desktop_entry.dart';

class IconThemeService {
  final Map<String, String> _iconCache = {};
  List<File> _themeFiles = [];
  String? _currentThemePath;

  Future<void> loadTheme(String? themePath) async {
    if (themePath == null || themePath == _currentThemePath) return;

    _currentThemePath = themePath;
    _iconCache.clear();
    _themeFiles = [];

    final dir = Directory(themePath);
    if (!await dir.exists()) return;

    try {
      // Load all files recursively once
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          _themeFiles.add(entity);
          // Pre-index by filename for O(1) lookup
          final filename = entity.path
              .split(Platform.pathSeparator)
              .last
              .toLowerCase();
          final nameWithoutExt = filename.lastIndexOf('.') > 0
              ? filename.substring(0, filename.lastIndexOf('.'))
              : filename;

          // Store both full name and base name
          _iconCache[filename] = entity.path;
          if (!_iconCache.containsKey(nameWithoutExt)) {
            _iconCache[nameWithoutExt] = entity.path;
          }
        }
      }
    } catch (e) {
      print('Error loading icon theme: $e');
    }
  }

  String? resolveIcon(DesktopEntry entry) {
    // 1. Look up in our theme cache FIRST
    if (_currentThemePath != null) {
      // Try app name variations
      final name = entry.name.toLowerCase();
      final variations = [
        name,
        name.replaceAll(' ', '-'),
        name.replaceAll(' ', '_'),
        name.replaceAll(' ', ''),
      ];

      for (final v in variations) {
        if (_iconCache.containsKey(v)) {
          return _iconCache[v];
        }
      }

      // Try exact match on icon name/path
      if (entry.iconPath != null) {
        final filename = entry.iconPath!
            .split(Platform.pathSeparator)
            .last
            .toLowerCase();
        final nameWithoutExt = filename.lastIndexOf('.') > 0
            ? filename.substring(0, filename.lastIndexOf('.'))
            : filename;

        if (_iconCache.containsKey(nameWithoutExt)) {
          return _iconCache[nameWithoutExt];
        }
        if (_iconCache.containsKey(filename)) {
          return _iconCache[filename];
        }
      }
    }

    // 2. Fallback: Check if entry has an absolute path icon that exists
    if (entry.iconPath != null && File(entry.iconPath!).existsSync()) {
      return entry.iconPath;
    }

    return null;
  }
}
