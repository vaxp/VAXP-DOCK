import 'dart:io';

class GpuService {
  Future<String?> detectSwitcher() async {
    for (final cmd in ['prime-run', 'optirun', 'primusrun']) {
      try {
        final res = await Process.run('which', [cmd]);
        if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
          return cmd;
        }
      } catch (_) {}
    }
    return 'DRI_PRIME';
  }

  Future<String> buildGpuCommand(String cleanedExec) async {
    final switcher = await detectSwitcher();
    if (switcher == null) return cleanedExec;
    if (switcher == 'DRI_PRIME') {
      return 'DRI_PRIME=1 $cleanedExec';
    }
    return '$switcher $cleanedExec';
  }
}


