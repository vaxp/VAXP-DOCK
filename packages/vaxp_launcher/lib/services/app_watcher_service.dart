import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class AppWatcherService {
  final _controller = StreamController<void>.broadcast();
  final List<StreamSubscription> _watchers = [];
  Timer? _debounceTimer;

  Stream<void> get onAppsChanged => _controller.stream;

  void startWatching() {
    final home = Platform.environment['HOME'] ?? '/home/x';
    final paths = [
      '/usr/share/applications',
      '$home/.local/share/applications',
      '/var/lib/flatpak/exports/share/applications',
      '$home/.local/share/flatpak/exports/share/applications',
    ];

    for (final path in paths) {
      final dir = Directory(path);
      if (dir.existsSync()) {
        try {
          final watcher = dir.watch(events: FileSystemEvent.all);
          _watchers.add(
            watcher.listen((event) {
              if (event.path.endsWith('.desktop')) {
                _debounceNotify();
              }
            }),
          );
          // We can't easily store StreamSubscription from dir.watch directly
          // without a wrapper, but for this service lifecycle it's okay
          // as it runs for the app duration.
        } catch (e) {
          debugPrint('Failed to watch $path: $e');
        }
      }
    }
  }

  void _debounceNotify() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _controller.add(null);
    });
  }

  void dispose() {
    _debounceTimer?.cancel();
    _controller.close();
  }
}
