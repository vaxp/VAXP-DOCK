import 'dart:io';

class PackageService {
  Future<String?> detectPackageManager() async {
    final managers = [
      ('apt', ['apt', 'apt-get']),
      ('dnf', ['dnf']),
      ('yum', ['yum']),
      ('pacman', ['pacman']),
      ('zypper', ['zypper']),
      ('apk', ['apk']),
    ];
    for (final m in managers) {
      for (final cmd in m.$2) {
        final res = await Process.run('which', [cmd]);
        if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
          return m.$1;
        }
      }
    }
    return null;
  }

  Future<String?> findPackageName(String appName) async {
    final app = appName.toLowerCase();
    return app
        .replaceAll(RegExp(r'[^a-z0-9]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  Future<List<String>?> buildUninstallCmd(String manager, String packageName) async {
    switch (manager) {
      case 'apt':
        return ['sudo', '-S', 'apt-get', 'remove', '-y', packageName];
      case 'dnf':
        return ['sudo', '-S', 'dnf', 'remove', '-y', packageName];
      case 'yum':
        return ['sudo', '-S', 'yum', 'remove', '-y', packageName];
      case 'pacman':
        return ['sudo', '-S', 'pacman', '-R', '--noconfirm', packageName];
      case 'zypper':
        return ['sudo', '-S', 'zypper', 'remove', '-y', packageName];
      case 'apk':
        return ['sudo', '-S', 'apk', 'del', packageName];
    }
    return null;
  }
}


