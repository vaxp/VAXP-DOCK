import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'app/launcher_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optimize memory usage
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      1024 * 1024 * 20; // 100 MB

  await windowManager.ensureInitialized();
  runApp(const LauncherApp());
}
