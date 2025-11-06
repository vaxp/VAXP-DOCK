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

  Future<String?> _findDesktopFilePath(DesktopEntry entry) async {
    // Search for the desktop file that matches this entry
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
              return file.path;
            }
          }
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  void _createDesktopShortcut(DesktopEntry entry) async {
    try {
      // Get Desktop directory path
      String desktopDir;
      if (Platform.environment['XDG_DESKTOP_DIR'] != null) {
        desktopDir = Platform.environment['XDG_DESKTOP_DIR']!;
      } else if (Platform.environment['HOME'] != null) {
        desktopDir = '${Platform.environment['HOME']!}/Desktop';
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not determine Desktop directory'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create Desktop directory if it doesn't exist
      final desktopDirectory = Directory(desktopDir);
      if (!await desktopDirectory.exists()) {
        await desktopDirectory.create(recursive: true);
      }

      // Find the original desktop file
      final sourceDesktopFile = await _findDesktopFilePath(entry);
      
      String desktopContent;
      if (sourceDesktopFile != null) {
        // Read the original desktop file
        final originalContent = await File(sourceDesktopFile).readAsString();
        // Modify it to ensure it's a proper desktop shortcut
        final lines = originalContent.split('\n');
        final modifiedLines = <String>[];
        bool hasType = false;
        bool hasVersion = false;
        
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('[Desktop Entry]')) {
            modifiedLines.add(trimmed);
            continue;
          }
          if (trimmed.startsWith('Type=')) {
            modifiedLines.add('Type=Application');
            hasType = true;
            continue;
          }
          if (trimmed.startsWith('Version=')) {
            modifiedLines.add('Version=1.0');
            hasVersion = true;
            continue;
          }
          if (trimmed.isEmpty || trimmed.startsWith('#')) {
            modifiedLines.add(line);
            continue;
          }
          modifiedLines.add(line);
        }
        
        // Ensure required fields are present
        if (!hasType) {
          modifiedLines.insert(1, 'Type=Application');
        }
        if (!hasVersion) {
          modifiedLines.insert(1, 'Version=1.0');
        }
        
        desktopContent = modifiedLines.join('\n');
      } else {
        // Create a minimal desktop file if source not found
        desktopContent = '''[Desktop Entry]
Version=1.0
Type=Application
Name=${entry.name}
Exec=${entry.exec ?? ''}
Icon=${entry.iconPath ?? 'application-default-icon'}
Terminal=false
''';
      }

      // Create a safe filename from the app name
      final safeName = entry.name
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s\-_]'), '')
          .replaceAll(RegExp(r'\s+'), '-');
      final shortcutPath = '$desktopDir/$safeName.desktop';

      // Write the desktop file
      final shortcutFile = File(shortcutPath);
      await shortcutFile.writeAsString(desktopContent);

      // Make it executable
      await Process.run('chmod', ['+x', shortcutPath]);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Desktop shortcut created for ${entry.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create desktop shortcut: $e'),
          backgroundColor: Colors.red,
        ),
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
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lock icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 32,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              // Title
              const Text(
                'Authentication Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              // Description
              Text(
                'Enter your password to uninstall the application.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              // Password field
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[700]!, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  hintText: 'Password',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    Navigator.of(context).pop(value);
                  }
                },
              ),
              const SizedBox(height: 32),
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cancel button
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // OK button
                  ElevatedButton(
                    onPressed: () {
                      if (passwordController.text.isNotEmpty) {
                        Navigator.of(context).pop(passwordController.text);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
                    onCreateShortcut: _createDesktopShortcut,
                  ),
          ),
        ],
      ),
    );
  }


}