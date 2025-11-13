import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dbus/dbus.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:window_manager/window_manager.dart';
import 'package:vaxp_core/models/desktop_entry.dart';
import 'package:vaxp_core/services/dock_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/system_stats/presentation/widgets/system_stats_grid.dart';
import '../features/system_stats/presentation/cubit/system_stats_cubit.dart';
import '../features/system_stats/data/repositories/system_stats_repository.dart';
import '../widgets/app_grid.dart';
import '../widgets/password_dialog.dart';
import '../services/gpu_service.dart';
import '../services/package_service.dart';
import '../services/shortcut_service.dart';
import '../services/workspace_service.dart';
import '../con/controlcenterpage.dart';
import '../features/search/presentation/widgets/search_bar.dart' as search;
import '../features/settings/presentation/widgets/settings_dialog.dart';
import '../features/settings/application/settings_cubit.dart';
import '../features/settings/application/settings_state.dart';

class LauncherHome extends StatefulWidget {
  const LauncherHome({super.key});

  @override
  State<LauncherHome> createState() => _LauncherHomeState();
}

class _LauncherHomeState extends State<LauncherHome> {
  late Future<List<DesktopEntry>> _allAppsFuture;
  List<DesktopEntry> _filteredApps = [];
  bool _isLoading = true;
  late final VaxpDockService _dockService;
  late final DBusClient _dbusClient;
  StreamSubscription<DBusSignal>? _minimizeSub;
  StreamSubscription<DBusSignal>? _restoreSub;

  final _gpuService = GpuService();
  final _pkgService = PackageService();
  final _shortcutService = ShortcutService();
  final _workspaceService = WorkspaceService();

  List<Workspace> _workspaces = [];
  int? _hoveredWorkspace;
  Set<String> _runningAppNames = {}; // Track running apps by name

  @override
  void initState() {
    super.initState();
    _allAppsFuture = DesktopEntry.loadAll();
    _loadApps();
    _dockService = VaxpDockService();
    _connectToDockService();
    _setupDockSignalListeners();
    _loadWorkspaces();
  }

  Future<void> _loadWorkspaces() async {
    try {
      final list = await _workspaceService.listWorkspaces();
      if (!mounted) return;
      setState(() => _workspaces = list);
    } catch (e) {
      debugPrint('Failed to load workspaces: $e');
    }
  }

  Future<void> _switchToWorkspace(int idx) async {
    final ok = await _workspaceService.switchTo(idx);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not switch workspace: utility not found'),
        ),
      );
    } else {
      await _loadWorkspaces();
    }
  }


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
              } catch (e) {
                debugPrint('Failed to report minimized state to dock: $e');
              }
            } catch (e, st) {
              debugPrint('Error handling MinimizeWindow signal: $e\n$st');
            }
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
    _allAppsFuture = DesktopEntry.loadAll();
    setState(() => _isLoading = true);
    final apps = await _allAppsFuture;
    if (!mounted) return;
    setState(() {
      _filteredApps = apps;
      _isLoading = false;
    });
  }


  void _filterApps(String query) {
    _allAppsFuture.then((apps) {
      if (!mounted) return;
      setState(() {
        _filteredApps = apps
            .where(
              (app) => app.name.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      });
    });
  }

  Future<void> _launchEntry(
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
      // Start the process and get its PID
      final process = await Process.start('/bin/sh', ['-c', finalCmd]);
      final shellPid = process.pid;

      // Register the running app with the dock
      try {
        await _dockService.ensureClientConnection();

        // Try to get the actual application PID after a short delay
        // This handles cases where the shell launches a detached process
        Future.delayed(const Duration(milliseconds: 500), () async {
          int actualPid = shellPid;

          // Try to find the process by extracting the command name
          try {
            final cmdName = cleaned.split(' ').first.split('/').last;
            if (cmdName.isNotEmpty && cmdName != 'sh' && cmdName != 'bash') {
              // Try to find the process by name
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

          // Register with the actual PID
          await _dockService.registerRunningApp(entry, actualPid);

          // Mark app as running in launcher
          if (mounted) {
            setState(() {
              _runningAppNames.add(entry.name);
            });
          }

          // Monitor the process and unregister when it exits
          // Check periodically if the process is still running
          _monitorProcess(actualPid, entry.name);
        });
      } catch (e) {
        debugPrint('Failed to register app with dock: $e');
        // Continue even if dock registration fails
      }

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

  Future<void> _launchWithExternalGPU(DesktopEntry entry) async {
    await _launchEntry(entry, useExternalGPU: true);
  }

  /// Monitor a process and unregister it from the dock when it exits
  void _monitorProcess(int pid, String appName) {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        // Check if process still exists
        final procFile = File('/proc/$pid/stat');
        if (!await procFile.exists()) {
          // Process has exited, unregister from dock
          try {
            await _dockService.unregisterRunningApp(pid);
          } catch (e) {
            debugPrint('Failed to unregister $appName from dock: $e');
          }
          // Remove from running apps in launcher
          if (mounted) {
            setState(() {
              _runningAppNames.remove(appName);
            });
          }
          return;
        }

        // Process still running, check again later
        _monitorProcess(pid, appName);
      } catch (e) {
        // Process likely doesn't exist, unregister
        try {
          await _dockService.unregisterRunningApp(pid);
        } catch (e2) {
          debugPrint('Failed to unregister $appName from dock: $e2');
        }
        // Remove from running apps in launcher
        if (mounted) {
          setState(() {
            _runningAppNames.remove(appName);
          });
        }
      }
    });
  }

  Future<void> _uninstallApp(DesktopEntry entry) async {
    final password = await showPasswordDialog(context);
    if (password == null || password.isEmpty) return;

    if (!mounted) return;
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
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not detect package manager')),
        );
        return;
      }

      final packageName = await _pkgService.findPackageName(entry.name);
      if (packageName == null || packageName.isEmpty) {
        if (!mounted) return;
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
        if (!mounted) return;
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
      final stderrOut = await process.stderr
          .transform(const SystemEncoding().decoder)
          .join();

      if (!mounted) return;
      Navigator.of(context).pop();

      if (exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uninstalled ${entry.name}'),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshApps();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to uninstall ${entry.name}: ${stderrOut.isNotEmpty ? stderrOut : 'Uninstallation failed'}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uninstalling ${entry.name}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _createDesktopShortcut(DesktopEntry entry) async {
    try {
      await _shortcutService.createDesktopShortcut(
        appName: entry.name,
        exec: entry.exec,
        iconPath: entry.iconPath,
      );
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

  void _showSettingsDialog() {
    final settingsCubit = context.read<SettingsCubit>();
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) => SettingsDialog(cubit: settingsCubit),
    );
  }

  @override
  void dispose() {
    _dockService.dispose();
    _minimizeSub?.cancel();
    _restoreSub?.cancel();
    _dbusClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingsState) {
        final settings = settingsState.settings;
        return Scaffold(
          backgroundColor: settings.backgroundColor.withOpacity(settings.opacity),
          body: Stack(
            children: [
              if (settings.backgroundImagePath != null)
                Positioned.fill(
                  child: Image.file(
                    File(settings.backgroundImagePath!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(),
                  ),
                ),
              Positioned.fill(
                child: Container(
                  color: settings.backgroundColor.withOpacity(settings.opacity),
                ),
              ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: MediaQuery.of(context).size.width / 2.5),
                    SizedBox(
                      width: MediaQuery.of(context).size.width / 5,
                      child: search.SearchBar(
                        onFilterApps: _filterApps,
                        allAppsFuture: _allAppsFuture,
                        onSettingsPressed: _showSettingsDialog,
                      ),
                    ),
                  ],
                ),
              ),
              // Workspace cards strip
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 200, // الارتفاع ثابت كما حددته
                      child: GlassmorphicContainer(
                        width: double.infinity,
                        height: 200,
                        borderRadius: 16,
                        linearGradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color.fromARGB(0, 0, 0, 0),
                            const Color.fromARGB(0, 0, 0, 0),
                          ],
                        ),
                        border: 1.2,
                        blur: 26,
                        borderGradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            // borderColor.withOpacity(0.1),
                            // borderColor.withOpacity(0.05),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _workspaces.isEmpty
                              ? const SizedBox.shrink()
                              : ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _workspaces.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 12),
                                  // --- (بداية التعديل) ---
                                  // تم إعادة كتابة الـ itemBuilder بالكامل
                                  itemBuilder: (context, idx) {
                                    final w = _workspaces[idx];
                                    final isHovered =
                                        _hoveredWorkspace == w.index;
                                    final isCurrent = w.isCurrent;

                                    // --- 1. تحديد الألوان بناءً على الحالة ---
                                    final Color baseColor;
                                    if (isCurrent) {
                                      // اللون النشط (أكثر سطوعاً)
                                      baseColor = Colors.white.withOpacity(
                                        0.16,
                                      );
                                    } else if (isHovered) {
                                      // اللون عند الحوم
                                      baseColor = Colors.white.withOpacity(
                                        0.12,
                                      );
                                    } else {
                                      // اللون الافتراضي (نفس بطاقات النظام)
                                      baseColor = Colors.white.withOpacity(
                                        0.08,
                                      );
                                    }

                                    // --- 2. تحديد لون الحدود ---
                                    final Color borderColor = isCurrent
                                        ? Colors.white.withOpacity(
                                            0.5,
                                          ) // إطار أبيض للنشط
                                        : Colors.transparent;

                                    return MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      onEnter: (_) => setState(
                                        () => _hoveredWorkspace = w.index,
                                      ),
                                      onExit: (_) => setState(
                                        () => _hoveredWorkspace = null,
                                      ),
                                      child: GestureDetector(
                                        onTap: () =>
                                            _switchToWorkspace(w.index),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          width:
                                              160, // <-- (مهم) عرض أصغر وأكثر أناقة
                                          decoration: BoxDecoration(
                                            color: baseColor,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ), // حواف دائرية
                                            border: Border.all(
                                              color: borderColor,
                                              width: 1.5,
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(14.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .desktop_windows_outlined, // أيقونة
                                                    color: Colors.white
                                                        .withOpacity(0.8),
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Workspace', // العنوان
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withOpacity(0.8),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              Text(
                                                w.name, // "Workspace 1" أو الاسم المخصص
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 20, // خط كبير وواضح
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  // --- (نهاية التعديل) ---
                                ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: SizedBox(
                      height: 200,
                      width: MediaQuery.of(context).size.width / 5,
                      child: BlocProvider<SystemStatsCubit>(
                        create: (_) =>
                            SystemStatsCubit(SystemStatsRepository()),
                        child: SystemStatsGrid(),
                      ),
                    ),
                  ),
                  // Control Center next to workspaces
                  SizedBox(height: 200, width: 800, child: ControlCenterPage()),
                ],
              ),

              // System stats grid below the search bar (provide its Cubit)
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : AppGrid(
                        apps: _filteredApps,
                        iconThemeDir: settings.iconThemePath,
                        runningAppNames: _runningAppNames,
                        onLaunch: _launchEntry,
                        onPin: (e) async {
                          try {
                            await _dockService.ensureClientConnection();
                            await _dockService.pinApp(e);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Pinned ${e.name} to dock'),
                              ),
                            );
                          } catch (err) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not pin ${e.name}: Make sure the VAXP Dock is running',
                                ),
                              ),
                            );
                          }
                        },
                        onInstall: _uninstallApp,
                        onCreateShortcut: _createDesktopShortcut,
                        onLaunchWithExternalGPU: _launchWithExternalGPU,
                      ),
              ),
            ],
          ),
        ],
      ),
        );
      },
    );
  }
}
