import 'package:vaxp_core/models/desktop_entry.dart';

/// Represents a running application in the dock
class RunningApp {
  final String name;
  final String? exec;
  final String? iconPath;
  final bool isSvgIcon;
  final int pid;

  RunningApp({
    required this.name,
    this.exec,
    this.iconPath,
    this.isSvgIcon = false,
    required this.pid,
  });

  /// Convert to DesktopEntry for compatibility with dock UI
  DesktopEntry toDesktopEntry() {
    return DesktopEntry(
      name: name,
      exec: exec,
      iconPath: iconPath,
      isSvgIcon: isSvgIcon,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunningApp &&
          runtimeType == other.runtimeType &&
          pid == other.pid;

  @override
  int get hashCode => pid.hashCode;
}

