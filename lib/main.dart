import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaxp_core/models/desktop_entry.dart';
import 'package:vaxp_core/services/dock_service.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'models/running_app.dart';
import 'widgets/dock/dock_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize D-Bus service
  final dockService = VaxpDockService();
  await dockService.listenAsServer();
  
  runApp(DockApp(dockService: dockService));
}

class DockApp extends StatelessWidget {
  final VaxpDockService dockService;

  const DockApp({
    super.key,
    required this.dockService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAXP Dock',
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        canvasColor: Colors.transparent,
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(125, 0, 170, 255),
        ),
      ),
      home: DockHome(dockService: dockService),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DockHome extends StatefulWidget {
  final VaxpDockService dockService;

  const DockHome({
    super.key,
    required this.dockService,
  });

  @override
  State<DockHome> createState() => _DockHomeState();
}

class _DockHomeState extends State<DockHome> {
  String? _backgroundImagePath;
  List<DesktopEntry> _pinnedApps = [];
  Map<int, RunningApp> _runningApps = {}; // PID -> RunningApp
  bool _launcherVisible = false;
  bool _launcherMinimized = false;

  @override
  void initState() {
    super.initState();
    widget.dockService.onPinRequest = _handlePinRequest;
    widget.dockService.onUnpinRequest = _handleUnpinRequest;
    widget.dockService.onLauncherState = _handleLauncherState;
    widget.dockService.onRegisterRunningApp = _handleRegisterRunningApp;
    widget.dockService.onUnregisterRunningApp = _handleUnregisterRunningApp;
    // Ensure Flutter bindings are initialized for shared_preferences
    WidgetsFlutterBinding.ensureInitialized();
    _loadPinnedApps();
    _setupHotkey();
    _startProcessMonitor();
  }

  void _handleLauncherState(String state) {
    setState(() {
      if (state == 'visible') {
        _launcherVisible = true;
        _launcherMinimized = false;
      } else if (state == 'minimized') {
        _launcherVisible = true;
        _launcherMinimized = true;
      } else {
        _launcherVisible = false;
        _launcherMinimized = false;
      }
    });
  }

  Future<void> _loadPinnedApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pinnedAppsJson = prefs.getStringList('pinnedApps') ?? [];
      
  setState(() {
    _pinnedApps = pinnedAppsJson
    .map((json) => DesktopEntry.fromJson(jsonDecode(json) as Map<String, dynamic>))
    .toList();
  });
    } catch (e) {
      debugPrint('Error loading pinned apps: $e');
    }
  }

  Future<void> _savePinnedApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pinnedAppsJson = _pinnedApps
          .map((entry) => jsonEncode(entry.toJson()))
          .toList();
      await prefs.setStringList('pinnedApps', pinnedAppsJson);
    } catch (e) {
      debugPrint('Error saving pinned apps: $e');
    }
  }

  void _handlePinRequest(String name, String exec, String? iconPath, bool isSvgIcon) {
    setState(() {
      if (!_pinnedApps.any((app) => app.name == name)) {
        _pinnedApps.add(DesktopEntry(
          name: name,
          exec: exec,
          iconPath: iconPath,
          isSvgIcon: isSvgIcon,
        ));
        _savePinnedApps(); // Save changes to persistent storage
      }
    });
  }

  void _handleUnpinRequest(String name) {
    setState(() {
      _pinnedApps.removeWhere((app) => app.name == name);
      _savePinnedApps(); // Save changes to persistent storage
    });
  }

  void _handleRegisterRunningApp(String name, String exec, String? iconPath, bool isSvgIcon, int pid) {
    setState(() {
      _runningApps[pid] = RunningApp(
        name: name,
        exec: exec,
        iconPath: iconPath,
        isSvgIcon: isSvgIcon,
        pid: pid,
      );
    });
  }

  void _handleUnregisterRunningApp(int pid) {
    setState(() {
      _runningApps.remove(pid);
    });
  }

  /// Monitor running processes and remove them from dock when they exit
  void _startProcessMonitor() {
    // Check every 2 seconds if processes are still running
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _checkRunningProcesses();
      _startProcessMonitor(); // Schedule next check
    });
  }

  Future<void> _checkRunningProcesses() async {
    final pidsToRemove = <int>[];
    for (final pid in _runningApps.keys) {
      try {
        // Check if process exists by reading /proc/[pid]/stat
        final procFile = File('/proc/$pid/stat');
        if (!await procFile.exists()) {
          pidsToRemove.add(pid);
        }
      } catch (e) {
        // Process likely doesn't exist
        pidsToRemove.add(pid);
      }
    }
    if (pidsToRemove.isNotEmpty && mounted) {
      setState(() {
        for (final pid in pidsToRemove) {
          _runningApps.remove(pid);
        }
      });
    }
  }

  /// Focus a running application by its PID
  /// This will restore the window if minimized and bring it to front
  Future<void> _focusApp(int pid) async {
    // Get the app name for fallback window finding
    final runningApp = _runningApps[pid];
    final appName = runningApp?.name;
    
    try {
      // Try wmctrl first (more reliable for window management)
      final wmctrlResult = await Process.run('which', ['wmctrl']);
      if (wmctrlResult.exitCode == 0) {
        // Find window by PID
        final findResult = await Process.run('wmctrl', ['-l', '-p']);
        if (findResult.exitCode == 0) {
          final lines = (findResult.stdout as String).split('\n');
          String? windowId;
          
          // First try to find by PID
          for (final line in lines) {
            if (line.contains(' $pid ')) {
              final parts = line.split(RegExp(r'\s+'));
              if (parts.isNotEmpty) {
                windowId = parts[0];
                break;
              }
            }
          }
          
          // If not found by PID and we have app name, try by name
          if (windowId == null && appName != null) {
            for (final line in lines) {
              // Check if window title contains app name (case insensitive)
              final titleStart = line.indexOf('  ') + 2;
              if (titleStart > 1 && titleStart < line.length) {
                final title = line.substring(titleStart);
                if (title.toLowerCase().contains(appName.toLowerCase())) {
                  final parts = line.split(RegExp(r'\s+'));
                  if (parts.isNotEmpty) {
                    windowId = parts[0];
                    break;
                  }
                }
              }
            }
          }
          
          if (windowId != null) {
            // First restore the window (unminimize it)
            await Process.run('wmctrl', ['-i', '-R', windowId]);
            // Small delay to ensure restore completes
            await Future.delayed(const Duration(milliseconds: 100));
            // Then activate it (bring to front and focus)
            await Process.run('wmctrl', ['-i', '-a', windowId]);
            return;
          }
        }
      }

      // Fallback to xdotool
      final xdotoolResult = await Process.run('which', ['xdotool']);
      if (xdotoolResult.exitCode == 0) {
        String? windowId;
        
        // Get window ID from PID
        final searchResult = await Process.run('xdotool', ['search', '--pid', pid.toString()]);
        if (searchResult.exitCode == 0) {
          final windowIds = (searchResult.stdout as String).trim().split('\n');
          if (windowIds.isNotEmpty && windowIds[0].isNotEmpty) {
            windowId = windowIds[0];
          }
        }
        
        // If not found by PID and we have app name, try by name
        if (windowId == null && appName != null) {
          try {
            // Try to find window by class name (WM_CLASS)
            final classResult = await Process.run('xdotool', ['search', '--class', appName.toLowerCase()]);
            if (classResult.exitCode == 0) {
              final windowIds = (classResult.stdout as String).trim().split('\n');
              if (windowIds.isNotEmpty && windowIds[0].isNotEmpty) {
                windowId = windowIds[0];
              }
            }
          } catch (e) {
            debugPrint('Could not find window by class name: $e');
          }
        }
        
        if (windowId != null) {
          // First map (unminimize) the window
          await Process.run('xdotool', ['windowmap', windowId]);
          // Small delay to ensure map completes
          await Future.delayed(const Duration(milliseconds: 100));
          // Then activate it (bring to front and focus)
          await Process.run('xdotool', ['windowactivate', windowId]);
          // Also raise it to ensure it's on top
          await Process.run('xdotool', ['windowraise', windowId]);
          return;
        }
      }
    } catch (e) {
      debugPrint('Failed to focus app with PID $pid: $e');
    }
  }

  void _launchEntry(DesktopEntry entry) async {
    final cmd = entry.exec;
    if (cmd == null) return;
    // remove placeholders like %U, %f, etc.
    final cleaned = cmd.replaceAll(RegExp(r'%[a-zA-Z]'), '').trim();
    if (cleaned.isEmpty) return;
    try {
      await Process.start('/bin/sh', ['-c', cleaned]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch ${entry.name}: $e')),
      );
    }
  }

  void _launchLauncher() async {
    try {
      // If the launcher is visible and not minimized, ask it to minimize/hide
      if (_launcherVisible && !_launcherMinimized) {
        await widget.dockService.emitMinimizeWindow('vaxp-launcher');
        return;
      }

      // If the launcher is minimized, ask it to restore
      if (_launcherMinimized) {
        await widget.dockService.emitRestoreWindow('vaxp-launcher');
        return;
      }

      // Otherwise, try to start the launcher process
      await Process.start('/bin/sh', ['-c', 'vaxp-launcher']);
    } catch (e) {
      // If signaling failed (no listener / error), try to launch the launcher process.
      try {
        await Process.start('/bin/sh', ['-c', 'vaxp-launcher']);
      } catch (e2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to launch VAXP Launcher')),
        );
      }
    }
  }

  Future<void> _setupHotkey() async {
    // Register Super/Windows key as hotkey
    final hotKey = HotKey(
      KeyCode.metaLeft,
      scope: HotKeyScope.system, // Listen to hotkey when app is not focused
    );

    await HotKeyManager.instance.register(
      hotKey,
      keyDownHandler: (hotKey) => _launchLauncher(),
    );
  }

  @override
  void dispose() {
    hotKeyManager.unregisterAll();
    widget.dockService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_backgroundImagePath != null)
            Image.file(
              File(_backgroundImagePath!),
              fit: BoxFit.cover,
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: DockPanel(
              onLaunch: _launchEntry,
              onShowLauncher: _launchLauncher,
              onMinimizeLauncher: () async {
                try {
                  await widget.dockService.emitMinimizeWindow('vaxp-launcher');
                } catch (e) {
                  debugPrint('Failed to emit minimize signal: $e');
                }
              },
              onRestoreLauncher: () async {
                try {
                  await widget.dockService.emitRestoreWindow('vaxp-launcher');
                } catch (e) {
                  debugPrint('Failed to emit restore signal: $e');
                }
              },
              pinnedApps: _pinnedApps,
              runningApps: _runningApps.values.toList(),
              onUnpin: (name) => _handleUnpinRequest(name),
              onFocusApp: _focusApp,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  final item = _pinnedApps.removeAt(oldIndex);
                  _pinnedApps.insert(newIndex, item);
                  _savePinnedApps();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}