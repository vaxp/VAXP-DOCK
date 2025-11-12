import 'dart:io';
import 'package:flutter/foundation.dart';
import '../utils/icon_provider.dart';

class DesktopEntry {
  final String name;
  final String? exec;
  late final String? iconPath;
  final bool isSvgIcon;

  DesktopEntry({
    required this.name,
    this.exec,
    this.iconPath,
    this.isSvgIcon = false,
  });

  static Future<List<DesktopEntry>> loadAll() async {
    final home = Platform.environment['HOME'] ?? '';
    final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
    final xdgDataDirs = Platform.environment['XDG_DATA_DIRS']?.split(':') ?? [];
    
    // Build comprehensive list of directories to scan
    final List<String> dirs = [
      // Standard system directories
      '/usr/share/applications',
      '/usr/local/share/applications',
      
      // XDG_DATA_DIRS (system-wide data directories)
      ...xdgDataDirs.map((dir) => '$dir/applications').where((dir) => dir.isNotEmpty),
      
      // User-specific directories
      if (xdgDataHome != null && xdgDataHome.isNotEmpty)
        '$xdgDataHome/applications'
      else if (home.isNotEmpty)
        '$home/.local/share/applications',
      
      // Flatpak system-wide
      '/var/lib/flatpak/exports/share/applications',
      
      // Flatpak user-specific
      if (home.isNotEmpty) '$home/.local/share/flatpak/exports/share/applications',
      
      // Snap applications (system-wide and user)
      '/var/lib/snapd/desktop/applications',
      // Snap user applications are in ~/snap/*/current/usr/share/applications
      // We'll scan ~/snap recursively to find them
      if (home.isNotEmpty) '$home/snap',
      
      // AppImage applications (common locations)
      if (home.isNotEmpty) '$home/.local/share/applications',
      if (home.isNotEmpty) '$home/Applications',
      if (home.isNotEmpty) '$home/applications',
      
      // Additional common locations (many apps install to /opt)
      '/opt',
    ];

    final Set<String> seen = {};
    final List<DesktopEntry> entries = [];
    final String currentDesktop = Platform.environment['XDG_CURRENT_DESKTOP']?.toUpperCase() ?? '';

    for (final dirPath in dirs) {
      if (dirPath.isEmpty) continue;
      
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;

      try {
        // Scan recursively for .desktop files
        await for (final file in dir.list(recursive: true, followLinks: false)) {
          if (file is! File || !file.path.endsWith('.desktop')) continue;
          
          try {
            final lines = await file.readAsLines();
            String? name;
            String? exec;
            String? icon;
            String? type;
            bool inDesktopEntry = false;
            bool shouldDisplay = true;
            bool isNoDisplay = false;
            bool isHidden = false;

            for (final line in lines) {
              final l = line.trim();
              if (l == '[Desktop Entry]') {
                inDesktopEntry = true;
                continue;
              }
              if (!inDesktopEntry || l.startsWith('#') || l.isEmpty) continue;
              
              // Parse key-value pairs
              final eqIndex = l.indexOf('=');
              if (eqIndex == -1) continue;
              
              final key = l.substring(0, eqIndex).trim();
              final value = l.substring(eqIndex + 1).trim();
              
              switch (key) {
                case 'Type':
                  type = value;
                  break;
                case 'Name':
                  // Use first Name= found (fallback to localized if needed)
                  name ??= value;
                  break;
                case 'Exec':
                  exec ??= value;
                  break;
                case 'Icon':
                  icon ??= value;
                  break;
                case 'NoDisplay':
                  isNoDisplay = value.toLowerCase() == 'true';
                  break;
                case 'Hidden':
                  isHidden = value.toLowerCase() == 'true';
                  break;
                case 'OnlyShowIn':
                  if (value.isNotEmpty && currentDesktop.isNotEmpty) {
                    final environments = value.split(';')
                        .where((e) => e.isNotEmpty)
                        .map((e) => e.toUpperCase())
                        .toList();
                    
                    // Only filter if current desktop is a known desktop environment
                    // Custom desktops like VAXP should show all apps
                    final knownDesktops = [
                      'GNOME', 'KDE', 'XFCE', 'MATE', 'LXQT', 
                      'CINNAMON', 'UNITY', 'BUDGIE', 'DEEPIN'
                    ];
                    
                    if (knownDesktops.contains(currentDesktop) && 
                        !environments.contains(currentDesktop)) {
                      shouldDisplay = false;
                    }
                  }
                  break;
                case 'NotShowIn':
                  if (value.isNotEmpty && currentDesktop.isNotEmpty) {
                    final environments = value.split(';')
                        .where((e) => e.isNotEmpty)
                        .map((e) => e.toUpperCase())
                        .toList();
                    if (environments.contains(currentDesktop)) {
                      shouldDisplay = false;
                    }
                  }
                  break;
              }
            }
            
            // Filter criteria:
            // 1. Must be Type=Application (exclude services, links, etc.)
            // 2. Must have name and exec
            // 3. Must not be hidden or no-display
            // 4. Must pass OnlyShowIn/NotShowIn checks
            if (type != 'Application') continue;
            if (name == null || name.isEmpty) continue;
            if (exec == null || exec.isEmpty) continue;
            if (isHidden || isNoDisplay) continue;
            if (!shouldDisplay) continue;
            
            // Use a unique key based on name and exec to avoid duplicates
            final uniqueKey = '$name|$exec';
            if (seen.contains(uniqueKey)) continue;
            seen.add(uniqueKey);
            
            // Resolve icon path
            String? resolvedIconPath;
            if (icon != null && icon.isNotEmpty) {
              resolvedIconPath = icon.startsWith('/') && File(icon).existsSync()
                  ? icon
                  : IconProvider.findIcon(icon);
            }
            
            entries.add(
              DesktopEntry(
                name: name,
                exec: exec,
                iconPath: resolvedIconPath,
                isSvgIcon: resolvedIconPath?.toLowerCase().endsWith('.svg') ?? false,
              ),
            );
          } catch (e) {
            // Ignore parse errors for individual files
            debugPrint('Error parsing ${file.path}: $e');
          }
        }
      } catch (e) {
        // Ignore errors for directories that can't be read
        debugPrint('Error scanning directory $dirPath: $e');
      }
    }
    
    // Sort alphabetically by name
    entries.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    
    return entries;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'exec': exec,
      'iconPath': iconPath,
      'isSvgIcon': isSvgIcon,
    };
  }

  static DesktopEntry fromJson(Map<String, dynamic> json) {
    return DesktopEntry(
      name: json['name'] as String? ?? '',
      exec: json['exec'] as String?,
      iconPath: json['iconPath'] as String?,
      isSvgIcon: json['isSvgIcon'] as bool? ?? false,
    );
  }
}