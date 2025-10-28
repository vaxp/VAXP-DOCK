import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaxp_core/models/desktop_entry.dart';
import 'package:vaxp_core/services/dock_service.dart';
import 'widgets/dock/dock_panel.dart';

void main() async {
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

  @override
  void initState() {
    super.initState();
    widget.dockService.onPinRequest = _handlePinRequest;
    widget.dockService.onUnpinRequest = _handleUnpinRequest;
    // Ensure Flutter bindings are initialized for shared_preferences
    WidgetsFlutterBinding.ensureInitialized();
    _loadPinnedApps();
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
      }
    });
  }

  void _handleUnpinRequest(String name) {
    setState(() {
      _pinnedApps.removeWhere((app) => app.name == name);
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch ${entry.name}: $e')),
      );
    }
  }

  void _launchLauncher() async {
    try {
      await Process.start('/bin/sh', ['-c', 'vaxp-launcher']);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to launch VAXP Launcher')),
      );
    }
  }

  @override
  void dispose() {
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
              pinnedApps: _pinnedApps,
              onUnpin: (name) => _handleUnpinRequest(name),
            ),
          ),
        ],
      ),
    );
  }
}