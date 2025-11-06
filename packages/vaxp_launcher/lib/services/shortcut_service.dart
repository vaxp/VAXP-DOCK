import 'dart:io';

class ShortcutService {
  Future<void> createDesktopShortcut({
    required String appName,
    required String? exec,
    required String? iconPath,
  }) async {
    String desktopDir;
    if (Platform.environment['XDG_DESKTOP_DIR'] != null) {
      desktopDir = Platform.environment['XDG_DESKTOP_DIR']!;
    } else if (Platform.environment['HOME'] != null) {
      desktopDir = '${Platform.environment['HOME']!}/Desktop';
    } else {
      throw Exception('Could not determine Desktop directory');
    }

    final dir = Directory(desktopDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final safeName = appName
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s\-_]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    final path = '$desktopDir/$safeName.desktop';

    final content = '''[Desktop Entry]
Version=1.0
Type=Application
Name=$appName
Exec=${exec ?? ''}
Icon=${iconPath ?? 'application-default-icon'}
Terminal=false
''';

    await File(path).writeAsString(content);
    await Process.run('chmod', ['+x', path]);
  }
}


