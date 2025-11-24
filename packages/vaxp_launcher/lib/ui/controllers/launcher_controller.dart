import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dbus/dbus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:vaxp_core/models/desktop_entry.dart';
import 'package:vaxp_core/services/dock_service.dart';
import '../../core/enums/view_mode.dart';
import '../../features/search/application/search_handler.dart';
import '../../services/app_watcher_service.dart';
import '../../services/gpu_service.dart';
import '../../services/icon_theme_service.dart';
import '../../services/package_service.dart';
import '../../services/settings_service.dart';
import '../../services/shortcut_service.dart';
import '../../services/workspace_service.dart';
import '../../widgets/password_dialog.dart';

class LauncherController extends ChangeNotifier {
  LauncherController(this.context);

  final BuildContext context;
  final _settings = SettingsService();
  final _gpuService = GpuService();
  final _pkgService = PackageService();
  final _shortcutService = ShortcutService();
  final _workspaceService = WorkspaceService();
  final _appWatcher = AppWatcherService();
  final _iconTheme = IconThemeService();

  late final VaxpDockService _dockService;
  late final DBusClient _dbusClient;

  StreamSubscription<DBusSignal>? _minimizeSub;
  StreamSubscription<DBusSignal>? _restoreSub;
  StreamSubscription? _appWatchSub;

  SearchHandler? _searchHandler;

  // State
  List<DesktopEntry> filteredApps = [];
  bool isLoading = true;
  Set<String> runningAppNames = {};
  List<Workspace> workspaces = [];
  int? hoveredWorkspace;

  // Settings State
  Color backgroundColor = Colors.black;
  double opacity = 0.7;
  String? backgroundImagePath;
  String? iconThemePath;
  ViewMode viewMode = ViewMode.grid;

  Future<List<DesktopEntry>>? _allAppsFuture;

  void init() {
    _allAppsFuture = DesktopEntry.loadAll();
    _loadApps();
    _dockService = VaxpDockService();
    _connectToDockService();
    _setupDockSignalListeners();
    _loadSettings().then((_) {
      // Load apps immediately first (fast startup)
      _loadApps().then((_) {
        // Then load theme in background and refresh icons
        _iconTheme.loadTheme(iconThemePath).then((_) {
          refreshApps();
        });
      });
    });
    _loadWorkspaces();

    _appWatcher.startWatching();
    _appWatchSub = _appWatcher.onAppsChanged.listen((_) {
      refreshApps();
    });

    // Initialize search handler
    _searchHandler = SearchHandler(
      context: context,
      onResetSearch: () => filterApps(''),
    );
  }

  void disposeController() {
    _dockService.dispose();
    _minimizeSub?.cancel();
    _restoreSub?.cancel();
    _dbusClient.close();
    _appWatchSub?.cancel();
    _appWatcher.dispose();
    super.dispose();
  }

  // --- App Loading & Filtering ---

  Future<void> _loadApps() async {
    isLoading = true;
    notifyListeners();

    if (_allAppsFuture == null) {
      _allAppsFuture = DesktopEntry.loadAll();
    }
    final apps = await _allAppsFuture!;

    for (final app in apps) {
      final resolvedIcon = _iconTheme.resolveIcon(app);
      if (resolvedIcon != null) {
        app.iconPath = resolvedIcon;
      }
    }

    filteredApps = apps;
    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshApps([String query = '']) async {
    _allAppsFuture = DesktopEntry.loadAll();
    final apps = await _allAppsFuture!;

    for (final app in apps) {
      final resolvedIcon = _iconTheme.resolveIcon(app);
      if (resolvedIcon != null) {
        app.iconPath = resolvedIcon;
      }
    }

    if (query.isEmpty) {
      filteredApps = apps;
    } else {
      filteredApps = apps
          .where((app) => app.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    isLoading = false;
    notifyListeners();
  }

  void filterApps(String query) {
    if (_allAppsFuture == null) {
      _allAppsFuture = DesktopEntry.loadAll();
    }
    _allAppsFuture!.then((apps) {
      filteredApps = apps
          .where((app) => app.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      notifyListeners();
    });
  }

  void handleSearchSubmit(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      filterApps('');
      return;
    }
    if (_searchHandler?.handleSearch(query) ?? false) {
      return;
    }
    filterApps(query);
  }

  // --- Launching ---

  Future<void> launchEntry(
    DesktopEntry entry, {
    bool useExternalGPU = false,
  }) async {
    final cmd = entry.exec;
    if (cmd == null) return;
    final cleaned = cmd.replaceAll(RegExp(r'%[a-zA-Z]'), '').trim();
    if (cleaned.isEmpty) return;

    final finalCmd = useExternalGPU
        ? await _gpuService.buildGpuCommand(cleaned)
        : cleaned;

    try {
      final process = await Process.start('/bin/sh', ['-c', finalCmd]);
      final shellPid = process.pid;

      try {
        await _dockService.ensureClientConnection();
        Future.delayed(const Duration(milliseconds: 500), () async {
          int actualPid = shellPid;
          try {
            final cmdName = cleaned.split(' ').first.split('/').last;
            if (cmdName.isNotEmpty && cmdName != 'sh' && cmdName != 'bash') {
              final pgrepResult = await Process.run('pgrep', ['-f', cmdName]);
              if (pgrepResult.exitCode == 0) {
                final pids = (pgrepResult.stdout as String).trim().split('\n');
                if (pids.isNotEmpty && pids[0].isNotEmpty) {
                  final foundPid = int.tryParse(pids[0]);
                  if (foundPid != null && foundPid != shellPid) {
                    actualPid = foundPid;
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Could not find actual PID, using shell PID: $e');
          }

          await _dockService.registerRunningApp(entry, actualPid);
          runningAppNames.add(entry.name);
          notifyListeners();
          _monitorProcess(actualPid, entry.name);
        });
      } catch (e) {
        debugPrint('Failed to register app with dock: $e');
      }

      await windowManager.minimize();
      try {
        await _dockService.reportLauncherState('minimized');
      } catch (e) {
        debugPrint('Failed to report minimized state to dock: $e');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch ${entry.name}: $e')),
      );
    }
  }

  void _monitorProcess(int pid, String appName) {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final procFile = File('/proc/$pid/stat');
        if (!await procFile.exists()) {
          try {
            await _dockService.unregisterRunningApp(pid);
          } catch (_) {}
          runningAppNames.remove(appName);
          notifyListeners();
          return;
        }
        _monitorProcess(pid, appName);
      } catch (_) {
        try {
          await _dockService.unregisterRunningApp(pid);
        } catch (_) {}
        runningAppNames.remove(appName);
        notifyListeners();
      }
    });
  }

  // --- Uninstall & Shortcuts ---

  Future<void> uninstallApp(DesktopEntry entry) async {
    final password = await showPasswordDialog(context);
    if (password == null || password.isEmpty) return;

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
      final manager = await _pkgService.detectPackageManager();
      if (manager == null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not detect package manager')),
        );
        return;
      }

      final packageName = await _pkgService.findPackageName(entry.name);
      if (packageName == null || packageName.isEmpty) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not determine package name for ${entry.name}'),
          ),
        );
        return;
      }

      final uninstallCmd = await _pkgService.buildUninstallCmd(
        manager,
        packageName,
      );
      if (uninstallCmd == null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unsupported package manager')),
        );
        return;
      }

      final process = await Process.start(
        uninstallCmd[0],
        uninstallCmd.sublist(1),
        mode: ProcessStartMode.normal,
      );
      process.stdin.writeln(password);
      await process.stdin.close();

      final exitCode = await process.exitCode;
      Navigator.of(context).pop();

      if (exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uninstalled ${entry.name}'),
            backgroundColor: Colors.green,
          ),
        );
        await refreshApps();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uninstallation failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uninstalling ${entry.name}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void createDesktopShortcut(DesktopEntry entry) async {
    try {
      await _shortcutService.createDesktopShortcut(
        appName: entry.name,
        exec: entry.exec,
        iconPath: entry.iconPath,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Desktop shortcut created for ${entry.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create desktop shortcut: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> pinApp(DesktopEntry e) async {
    try {
      await _dockService.ensureClientConnection();
      await _dockService.pinApp(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Pinned ${e.name} to dock')));
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not pin ${e.name}: Make sure the VAXP Dock is running',
          ),
        ),
      );
    }
  }

  // --- Settings ---

  Future<void> _loadSettings() async {
    final s = await _settings.load();
    backgroundColor = s.backgroundColor;
    opacity = s.opacity;
    backgroundImagePath = s.backgroundImagePath;
    iconThemePath = s.iconThemePath;
    viewMode = s.viewMode;
    notifyListeners();
  }

  Future<void> saveSettings(
    Color color,
    double op,
    String? bgPath,
    String? iconPath,
  ) async {
    backgroundColor = color;
    opacity = op;
    backgroundImagePath = bgPath;
    iconThemePath = iconPath;
    notifyListeners();

    await _settings.save(
      LauncherSettings(
        backgroundColor: backgroundColor,
        opacity: opacity,
        backgroundImagePath: backgroundImagePath,
        iconThemePath: iconThemePath,
        viewMode: viewMode,
      ),
    );

    // Reload theme if changed
    _iconTheme.loadTheme(iconThemePath).then((_) => refreshApps());
  }

  /// Toggle between grid and paged view modes
  void toggleViewMode() {
    viewMode = viewMode == ViewMode.grid ? ViewMode.paged : ViewMode.grid;
    notifyListeners();

    // Save the new view mode preference
    _settings.save(
      LauncherSettings(
        backgroundColor: backgroundColor,
        opacity: opacity,
        backgroundImagePath: backgroundImagePath,
        iconThemePath: iconThemePath,
        viewMode: viewMode,
      ),
    );
  }

  // --- Workspaces ---

  Future<void> _loadWorkspaces() async {
    try {
      workspaces = await _workspaceService.listWorkspaces();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load workspaces: $e');
    }
  }

  Future<void> switchToWorkspace(int idx) async {
    final ok = await _workspaceService.switchTo(idx);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not switch workspace: utility not found'),
        ),
      );
    } else {
      await _loadWorkspaces();
    }
  }

  void setHoveredWorkspace(int? index) {
    hoveredWorkspace = index;
    notifyListeners();
  }

  // --- Dock Communication ---

  Future<void> _connectToDockService() async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 1);
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        await _dockService.ensureClientConnection();
        try {
          await _dockService.reportLauncherState('visible');
        } catch (_) {}
        return;
      } catch (e) {
        retryCount++;
        if (retryCount == maxRetries) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to connect to dock service: $e')),
          );
          return;
        }
        await Future.delayed(retryDelay);
      }
    }
  }

  void _setupDockSignalListeners() {
    try {
      _dbusClient = DBusClient.session();

      _minimizeSub =
          DBusSignalStream(
            _dbusClient,
            interface: vaxpInterfaceName,
            name: 'MinimizeWindow',
            signature: DBusSignature('s'),
          ).asBroadcastStream().listen((signal) async {
            try {
              await windowManager.minimize();
              try {
                await _dockService.reportLauncherState('minimized');
              } catch (_) {}
            } catch (_) {}
          });

      _restoreSub =
          DBusSignalStream(
            _dbusClient,
            interface: vaxpInterfaceName,
            name: 'RestoreWindow',
            signature: DBusSignature('s'),
          ).asBroadcastStream().listen((signal) async {
            try {
              await windowManager.restore();
              await windowManager.show();
              await windowManager.focus();
              try {
                await _dockService.reportLauncherState('visible');
              } catch (_) {}
            } catch (_) {}
          });
    } catch (e) {
      debugPrint('Failed to set up dock signal listeners: $e');
    }
  }
}
