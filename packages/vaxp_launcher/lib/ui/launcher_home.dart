import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dbus/dbus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:vaxp_core/models/desktop_entry.dart';
import 'package:file_picker/file_picker.dart';
import 'package:vaxp_core/services/dock_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/system_stats/presentation/widgets/system_stats_grid.dart';
import '../features/system_stats/presentation/cubit/system_stats_cubit.dart';
import '../features/system_stats/data/repositories/system_stats_repository.dart';
import '../widgets/app_grid.dart';
import '../widgets/password_dialog.dart';
import '../widgets/color_picker_dialog.dart';
import '../services/settings_service.dart';
import '../services/gpu_service.dart';
import '../services/package_service.dart';
import '../services/shortcut_service.dart';
import '../services/workspace_service.dart';

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

  // Settings state
  Color _backgroundColor = Colors.black;
  double _opacity = 0.7;
  String? _backgroundImagePath;
  String? _iconThemePath;

  final _settings = SettingsService();
  final _gpuService = GpuService();
  final _pkgService = PackageService();
  final _shortcutService = ShortcutService();
  final _workspaceService = WorkspaceService();

  List<Workspace> _workspaces = [];

  @override
  void initState() {
    super.initState();
    _allAppsFuture = DesktopEntry.loadAll();
    _loadApps();
    _dockService = VaxpDockService();
    _connectToDockService();
    _setupDockSignalListeners();
    _loadSettings();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not switch workspace: utility not found')));
    } else {
      await _loadWorkspaces();
    }
  }

  Future<void> _loadSettings() async {
    final s = await _settings.load();
    if (!mounted) return;
    setState(() {
      _backgroundColor = s.backgroundColor;
      _opacity = s.opacity;
      _backgroundImagePath = s.backgroundImagePath;
      _iconThemePath = s.iconThemePath;
    });
  }

  Future<void> _saveSettings() async {
    await _settings.save(
      LauncherSettings(
        backgroundColor: _backgroundColor,
        opacity: _opacity,
        backgroundImagePath: _backgroundImagePath,
        iconThemePath: _iconThemePath,
      ),
    );
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

      _minimizeSub = DBusSignalStream(
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

      _restoreSub = DBusSignalStream(
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
    final query = _searchController.text.trim();
    setState(() {
      if (query.isEmpty) {
        _filteredApps = apps;
      } else {
        _filteredApps = apps
            .where((app) => app.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      _isLoading = false;
    });
  }

  void _filterApps(String query) {
    _allAppsFuture.then((apps) {
      setState(() {
        _filteredApps = apps
            .where((app) => app.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    });
  }

  Future<void> _launchEntry(DesktopEntry entry, {bool useExternalGPU = false}) async {
    final cmd = entry.exec;
    if (cmd == null) return;
    final cleaned = cmd.replaceAll(RegExp(r'%[a-zA-Z]'), '').trim();
    if (cleaned.isEmpty) return;

    final finalCmd = useExternalGPU
        ? await _gpuService.buildGpuCommand(cleaned)
        : cleaned;

    try {
      await Process.start('/bin/sh', ['-c', finalCmd]);
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
          SnackBar(content: Text('Could not determine package name for ${entry.name}')),
        );
        return;
      }

      final uninstallCmd = await _pkgService.buildUninstallCmd(manager, packageName);
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
      final stderrOut = await process.stderr.transform(const SystemEncoding().decoder).join();

      if (!mounted) return;
      Navigator.of(context).pop();

      if (exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully uninstalled ${entry.name}'), backgroundColor: Colors.green),
        );
        await _refreshApps();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to uninstall ${entry.name}: ${stderrOut.isNotEmpty ? stderrOut : 'Uninstallation failed'}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uninstalling ${entry.name}: $e'), backgroundColor: Colors.red),
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
        SnackBar(content: Text('Desktop shortcut created for ${entry.name}'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create desktop shortcut: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<String?> _pickBackgroundImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        return result.files.single.path;
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
    return null;
  }

  Future<String?> _pickIconThemeDirectory() async {
    try {
      // Use getDirectoryPath to allow picking a folder containing themed icons
      final dir = await FilePicker.platform.getDirectoryPath();
      return dir;
    } catch (e) {
      debugPrint('Error picking icon theme directory: $e');
    }
    return null;
  }

  void _showSettingsDialog() {
    Color tempColor = _backgroundColor;
    double tempOpacity = _opacity;
    String? tempBackgroundImage = _backgroundImagePath;
    String? tempIconTheme = _iconThemePath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Launcher Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
                const SizedBox(height: 32),
                const Text('Background Color', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1),
                  itemCount: _presetColors.length,
                  itemBuilder: (context, index) {
                    final color = _presetColors[index];
                    final isSelected = tempColor == color;
                    return GestureDetector(
                      onTap: () => setDialogState(() => tempColor = color),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, spreadRadius: 1)],
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showDialog<Color>(
                      context: context,
                      builder: (c) => CustomColorPickerDialog(initialColor: tempColor),
                    );
                    if (picked != null) setDialogState(() => tempColor = picked);
                  },
                  icon: const Icon(Icons.colorize),
                  label: const Text('Custom Color'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                ),
                const SizedBox(height: 32),
                const Text('Transparency', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Slider(value: tempOpacity, min: 0.0, max: 1.0, divisions: 100, label: '${(tempOpacity * 100).round()}%', onChanged: (v) => setDialogState(() => tempOpacity = v), activeColor: Colors.blue)),
                  const SizedBox(width: 16),
                  SizedBox(width: 60, child: Text('${(tempOpacity * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
                ]),
                const SizedBox(height: 32),
                // Background Image
                const Text('Background Image', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final imagePath = await _pickBackgroundImage();
                        if (imagePath != null) {
                          setDialogState(() => tempBackgroundImage = imagePath);
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: const Text('Select Image'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    ),
                  ),
                  if (tempBackgroundImage != null) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => setDialogState(() => tempBackgroundImage = null),
                      icon: const Icon(Icons.delete),
                      label: const Text('Remove'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    ),
                  ],
                ]),
                if (tempBackgroundImage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(tempBackgroundImage!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error, color: Colors.red)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                // Icon Theme selection
                const Text('Icon Theme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final dir = await _pickIconThemeDirectory();
                        if (dir != null) setDialogState(() => tempIconTheme = dir);
                      },
                      icon: const Icon(Icons.folder),
                      label: const Text('Select Icon Theme (directory)'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    ),
                  ),
                  if (tempIconTheme != null) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => setDialogState(() => tempIconTheme = null),
                      icon: const Icon(Icons.delete),
                      label: const Text('Remove'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    ),
                  ],
                ]),
                const SizedBox(height: 8),
                Text(
                  tempIconTheme != null ? tempIconTheme! : 'No icon theme selected',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                // Preview (image + overlay)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tempColor.withOpacity(tempOpacity),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Stack(children: [
                    if (tempBackgroundImage != null)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(tempBackgroundImage!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const SizedBox(),
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: tempColor.withOpacity(tempOpacity), borderRadius: BorderRadius.circular(8)),
                      child: const Text('Preview', style: TextStyle(color: Colors.white)),
                    ),
                  ]),
                ),
                const SizedBox(height: 32),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _backgroundColor = tempColor;
                        _opacity = tempOpacity;
                        _backgroundImagePath = tempBackgroundImage;
                        _iconThemePath = tempIconTheme;
                      });
                      _saveSettings();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    child: const Text('Apply'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static final List<Color> _presetColors = [
    Colors.black,
    Colors.grey[900]!,
    Colors.grey[800]!,
    Colors.blue[900]!,
    Colors.purple[900]!,
    Colors.indigo[900]!,
    Colors.teal[900]!,
    Colors.green[900]!,
    Colors.orange[900]!,
    Colors.red[900]!,
    Colors.pink[900]!,
    Colors.amber[900]!,
    Colors.cyan[900]!,
    Colors.deepPurple[900]!,
    Colors.lime[900]!,
    Colors.brown[900]!,
  ];

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
      backgroundColor: _backgroundColor.withOpacity(_opacity),
      body: Stack(
        children: [
          if (_backgroundImagePath != null)
            Positioned.fill(
              child: Image.file(
                File(_backgroundImagePath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          Positioned.fill(
            child: Container(color: _backgroundColor.withOpacity(_opacity)),
          ),
          Column(
            children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                 SizedBox(width: MediaQuery.of(context).size.width / 2.5),
                Container(
                  alignment: Alignment.center,
                  width: MediaQuery.of(context).size.width / 5,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
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
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _showSettingsDialog,
                  icon: const Icon(Icons.settings),
                  iconSize: 28,
                  color: Colors.white,
                  tooltip: 'Settings',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white10,
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              ],
            ),
          ),
          // Workspace cards strip
          Row(
            children: [
           Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              height: 220,
              width: MediaQuery.of(context).size.width/4,
              child: BlocProvider<SystemStatsCubit>(
                create: (_) => SystemStatsCubit(SystemStatsRepository()),
                child: SystemStatsGrid(),
              ),
            ),
          ),
              Expanded(
                child: SizedBox(
                  height: 120,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _workspaces.isEmpty
                        ? const SizedBox.shrink()
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _workspaces.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, idx) {
                              final w = _workspaces[idx];
                              return GestureDetector(
                                onTap: () => _switchToWorkspace(w.index),
                                child: Container(
                                  width: 220,
                                  decoration: BoxDecoration(
                                    color: w.isCurrent ? Colors.white10 : Colors.white12,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: w.isCurrent ? Colors.blue : Colors.transparent, width: 2),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: Colors.black26,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Center(
                                            child: Text('Workspace ${w.index + 1}', style: const TextStyle(color: Colors.white70)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(w.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          ),
          // System stats grid below the search bar (provide its Cubit)

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : AppGrid(
                    apps: _filteredApps,
          iconThemeDir: _iconThemePath,
                    onLaunch: _launchEntry,
                    onPin: (e) async {
                      try {
                        await _dockService.ensureClientConnection();
                        await _dockService.pinApp(e);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Pinned ${e.name} to dock')),
                        );
                      } catch (err) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not pin ${e.name}: Make sure the VAXP Dock is running')),
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
  }
}


