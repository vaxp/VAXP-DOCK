import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dbus/dbus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:vaxp_core/models/desktop_entry.dart';
import 'package:vaxp_core/services/dock_service.dart';
import 'widgets/app_grid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  runApp(const LauncherApp());
}

class LauncherApp extends StatelessWidget {
  const LauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAXP Launcher',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(125, 0, 170, 255),
          brightness: Brightness.dark,
        ),
      ),
      home: const LauncherHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LauncherHome extends StatefulWidget {
  const LauncherHome({super.key});

  @override
  State<LauncherHome> createState() => _LauncherHomeState();
}

class _LauncherHomeState extends State<LauncherHome> {
  late Future<List<DesktopEntry>> _allAppsFuture;
  final _searchController = TextEditingController();
  List<DesktopEntry> _filteredApps = [];
  bool _isLoading = true;
  late final VaxpDockService _dockService;
  late final DBusClient _dbusClient;
  StreamSubscription<DBusSignal>? _minimizeSub;
  StreamSubscription<DBusSignal>? _restoreSub;

  Future<void> _connectToDockService() async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 1);
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        await _dockService.ensureClientConnection();
        // After connecting, report that the launcher is visible (initial state)
        try {
          await _dockService.reportLauncherState('visible');
        } catch (_) {
          // ignore reporting errors
        }
        return; // Connection successful
      } catch (e) {
        retryCount++;
        if (retryCount == maxRetries) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to connect to dock service: $e')),
          );
          return;
        }
        await Future.delayed(retryDelay);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _allAppsFuture = DesktopEntry.loadAll();
    _loadApps();
    _dockService = VaxpDockService();
    _connectToDockService();
    // Start listening for dock signals (minimize/restore)
    _setupDockSignalListeners();
  }

  void _setupDockSignalListeners() {
    try {
      _dbusClient = DBusClient.session();

      _minimizeSub = DBusSignalStream(
        _dbusClient,
        interface: vaxpInterfaceName,
        name: 'MinimizeWindow',
        signature: DBusSignature('s'),
      ).asBroadcastStream().listen((signal) async {
        try {
          final name = (signal.values[0] as DBusString).value;
          debugPrint('Dock -> MinimizeWindow signal received for: $name');
          // Received minimize request from dock
          await windowManager.minimize();
          try {
            await _dockService.reportLauncherState('minimized');
          } catch (e) {
            debugPrint('Failed to report minimized state to dock: $e');
          }
        } catch (e, st) {
          debugPrint('Error handling MinimizeWindow signal: $e\n$st');
        }
      });

      _restoreSub = DBusSignalStream(
        _dbusClient,
        interface: vaxpInterfaceName,
        name: 'RestoreWindow',
        signature: DBusSignature('s'),
      ).asBroadcastStream().listen((signal) async {
        try {
          final name = (signal.values[0] as DBusString).value;
          debugPrint('Dock -> RestoreWindow signal received for: $name');
          // Received restore request from dock
          await windowManager.restore();
          await windowManager.show();
          await windowManager.focus();
          try {
            await _dockService.reportLauncherState('visible');
          } catch (e) {
            debugPrint('Failed to report visible state to dock: $e');
          }
        } catch (e, st) {
          debugPrint('Error handling RestoreWindow signal: $e\n$st');
        }
      });
    } catch (e) {
      debugPrint('Failed to set up dock signal listeners: $e');
    }
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    final apps = await _allAppsFuture;
    if (!mounted) return;
    setState(() {
      _filteredApps = apps;
      _isLoading = false;
    });
  }

  Future<void> _refreshApps() async {
    // Reload desktop entries from scratch
    _allAppsFuture = DesktopEntry.loadAll();
    // Reload and update the UI
    setState(() => _isLoading = true);
    final apps = await _allAppsFuture;
    if (!mounted) return;
    
    // Preserve search filter if active
    final query = _searchController.text.trim();
    setState(() {
      if (query.isEmpty) {
        _filteredApps = apps;
      } else {
        _filteredApps = apps
            .where((app) =>
                app.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      _isLoading = false;
    });
  }

  void _filterApps(String query) {
    _allAppsFuture.then((apps) {
      setState(() {
        _filteredApps = apps
            .where((app) =>
                app.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    });
  }

  void _launchEntry(DesktopEntry entry) async {
    final cmd = entry.exec;
    if (cmd == null) return;
    // remove placeholders like %U, %f, etc.
    final cleaned = cmd.replaceAll(RegExp(r'%[a-zA-Z]'), '').trim();
    if (cleaned.isEmpty) return;
    try {
      await Process.start('/bin/sh', ['-c', cleaned]);
      // Minimize launcher after launching app
      await windowManager.minimize();
      try {
        await _dockService.reportLauncherState('minimized');
      } catch (e) {
        debugPrint('Failed to report minimized state to dock: $e');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch ${entry.name}: $e')),
      );
    }
  }

  void _pinToDock(DesktopEntry entry) async {
    try {
      // Try to ensure connection before pinning
      await _dockService.ensureClientConnection();
      await _dockService.pinApp(entry);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pinned ${entry.name} to dock')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pin ${entry.name}: Make sure the VAXP Dock is running'),
          duration: const Duration(seconds: 1),
          action: SnackBarAction(
            label: 'Launch Dock',
            onPressed: () async {
              try {
                await Process.start('vaxp-dock', []);
                // Wait a bit for the dock to start
                await Future.delayed(const Duration(seconds: 2));
                // Try pinning again
                if (!mounted) return;
                _pinToDock(entry);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to launch VAXP Dock')),
                );
              }
            },
          ),
        ),
      );
    }
  }

  Future<String?> _requestPassword() async {
    final passwordController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your password to uninstall the application:'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                Navigator.of(context).pop(value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(passwordController.text);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<String?> _detectPackageManager() async {
    // Check for common package managers
    final packageManagers = [
      ('apt', ['apt', 'apt-get']),
      ('dnf', ['dnf']),
      ('yum', ['yum']),
      ('pacman', ['pacman']),
      ('zypper', ['zypper']),
      ('apk', ['apk']),
    ];

    for (final (name, commands) in packageManagers) {
      for (final cmd in commands) {
        try {
          final result = await Process.run('which', [cmd]);
          if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
            return name;
          }
        } catch (_) {
          // Continue checking
        }
      }
    }
    return null;
  }

  Future<String?> _findPackageName(DesktopEntry entry) async {
    // Try to find the package that provides this desktop entry
    final packageManager = await _detectPackageManager();
    if (packageManager == null) return null;

    // First, try to find the desktop file path
    final List<String> desktopDirs = [
      '/usr/share/applications',
      '/usr/local/share/applications',
      if (Platform.environment['XDG_DATA_HOME'] != null)
        '${Platform.environment['XDG_DATA_HOME']!}/applications'
      else
        Platform.environment['HOME'] != null
            ? '${Platform.environment['HOME']!}/.local/share/applications'
            : '',
    ];

    String? desktopFilePath;
    for (final dir in desktopDirs) {
      final d = Directory(dir);
      if (!await d.exists()) continue;
      await for (final file in d.list()) {
        if (!file.path.endsWith('.desktop')) continue;
        try {
          final lines = await File(file.path).readAsLines();
          for (final line in lines) {
            if (line.trim().startsWith('Name=') && 
                line.substring(5).trim() == entry.name) {
              desktopFilePath = file.path;
              break;
            }
          }
          if (desktopFilePath != null) break;
        } catch (_) {
          continue;
        }
      }
      if (desktopFilePath != null) break;
    }

    if (desktopFilePath != null) {
      try {
        ProcessResult result;
        switch (packageManager) {
          case 'apt':
            result = await Process.run('dpkg', ['-S', desktopFilePath]);
            if (result.exitCode == 0) {
              final output = result.stdout.toString().trim();
              return output.split(':').first;
            }
            break;
          case 'dnf':
          case 'yum':
            result = await Process.run('rpm', ['-qf', desktopFilePath]);
            if (result.exitCode == 0) {
              final output = result.stdout.toString().trim();
              return output.split('-')[0];
            }
            break;
          case 'pacman':
            result = await Process.run('pacman', ['-Qo', desktopFilePath]);
            if (result.exitCode == 0) {
              final output = result.stdout.toString().trim();
              final parts = output.split(' ');
              if (parts.length >= 2) {
                return parts[parts.length - 1].split('/').last;
              }
            }
            break;
        }
      } catch (_) {
        // Fall through to name-based approach
      }
    }

    // Fallback: try to derive package name from app name
    final appName = entry.name.toLowerCase();
    // Remove common suffixes and convert to package name format
    String packageName = appName
        .replaceAll(RegExp(r'[^a-z0-9]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    
    return packageName;
  }

  void _uninstallApp(DesktopEntry entry) async {
    // Request authentication
    final password = await _requestPassword();
    if (password == null || password.isEmpty) {
      return; // User cancelled or didn't enter password
    }

    if (!mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Uninstalling application...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final packageManager = await _detectPackageManager();
      if (packageManager == null) {
        if (!mounted) return;
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not detect package manager'),
          ),
        );
        return;
      }

      final packageName = await _findPackageName(entry);
      if (packageName == null || packageName.isEmpty) {
        if (!mounted) return;
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not determine package name for ${entry.name}'),
          ),
        );
        return;
      }

      // Build uninstallation command based on package manager
      List<String> uninstallCmd;
      switch (packageManager) {
        case 'apt':
          uninstallCmd = ['sudo', '-S', 'apt-get', 'remove', '-y', packageName];
          break;
        case 'dnf':
          uninstallCmd = ['sudo', '-S', 'dnf', 'remove', '-y', packageName];
          break;
        case 'yum':
          uninstallCmd = ['sudo', '-S', 'yum', 'remove', '-y', packageName];
          break;
        case 'pacman':
          uninstallCmd = ['sudo', '-S', 'pacman', '-R', '--noconfirm', packageName];
          break;
        case 'zypper':
          uninstallCmd = ['sudo', '-S', 'zypper', 'remove', '-y', packageName];
          break;
        case 'apk':
          uninstallCmd = ['sudo', '-S', 'apk', 'del', packageName];
          break;
        default:
          if (!mounted) return;
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unsupported package manager')),
          );
          return;
      }

      // Execute uninstallation
      final process = await Process.start(
        uninstallCmd[0],
        uninstallCmd.sublist(1),
        mode: ProcessStartMode.normal,
      );

      // Send password to stdin
      process.stdin.writeln(password);
      await process.stdin.close();

      // Wait for process to complete
      final exitCode = await process.exitCode;
      final stderr = await process.stderr.transform(
        const SystemEncoding().decoder,
      ).join();

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uninstalled ${entry.name}'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh apps to reflect the uninstallation
        await _refreshApps();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to uninstall ${entry.name}: ${stderr.isNotEmpty ? stderr : 'Uninstallation failed'}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uninstalling ${entry.name}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dockService.dispose();
    _minimizeSub?.cancel();
    _restoreSub?.cancel();
    _dbusClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterApps,
              decoration: InputDecoration(
                hintText: 'Search applications...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white10,
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : AppGrid(
                    apps: _filteredApps,
                    onLaunch: _launchEntry,
                    onPin: _pinToDock,
                    onInstall: _uninstallApp,
                  ),
          ),
        ],
      ),
    );
  }


}