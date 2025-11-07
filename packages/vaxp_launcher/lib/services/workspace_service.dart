import 'dart:io';

class Workspace {
  final int index;
  final String name;
  final bool isCurrent;

  Workspace({required this.index, required this.name, this.isCurrent = false});
}

class WorkspaceService {
  /// Returns a list of available workspaces. Tries `wmctrl -d` first, then
  /// falls back to `xdotool` (which only provides a count, not names).
  Future<List<Workspace>> listWorkspaces() async {
    try {
      final which = await _which('wmctrl');
      if (which != null) {
        final res = await Process.run('wmctrl', ['-d']);
        if (res.exitCode == 0) {
          final out = res.stdout.toString().trim().split('\n');
          final List<Workspace> list = [];
          final reg = RegExp(r'^\s*(\d+)\s+(\*)?\s+.*?\s+(.*)\s*\$');
          for (final line in out) {
            final m = reg.firstMatch(line);
            if (m != null) {
              final idx = int.tryParse(m.group(1) ?? '') ?? 0;
              final isCur = (m.group(2) ?? '').trim() == '*';
              final name = (m.group(3) ?? '').trim();
              list.add(Workspace(index: idx, name: name.isEmpty ? 'Workspace $idx' : name, isCurrent: isCur));
            }
          }
          if (list.isNotEmpty) return list;
        }
      }

      // Fallback: use xdotool to get number of desktops
      final xd = await _which('xdotool');
      if (xd != null) {
        final res = await Process.run('xdotool', ['get_num_desktops']);
        if (res.exitCode == 0) {
          final n = int.tryParse(res.stdout.toString().trim()) ?? 0;
          final curRes = await Process.run('xdotool', ['get_desktop']);
          final cur = int.tryParse(curRes.stdout.toString().trim()) ?? 0;
          final List<Workspace> list = List.generate(n, (i) => Workspace(index: i, name: 'Workspace ${i + 1}', isCurrent: i == cur));
          return list;
        }
      }
    } catch (_) {}
    // If nothing available, return a default single workspace
    return [Workspace(index: 0, name: 'Workspace 1', isCurrent: true)];
  }

  Future<bool> switchTo(int index) async {
    try {
      final which = await _which('wmctrl');
      if (which != null) {
        final res = await Process.run('wmctrl', ['-s', index.toString()]);
        return res.exitCode == 0;
      }
      final xd = await _which('xdotool');
      if (xd != null) {
        final res = await Process.run('xdotool', ['set_desktop', index.toString()]);
        return res.exitCode == 0;
      }
    } catch (_) {}
    return false;
  }

  Future<String?> _which(String cmd) async {
    try {
      final res = await Process.run('which', [cmd]);
      if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) return res.stdout.toString().trim();
    } catch (_) {}
    return null;
  }
}
