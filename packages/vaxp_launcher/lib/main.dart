import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vaxp_core/models/desktop_entry.dart';
import 'package:vaxp_core/services/dock_service.dart';
import 'widgets/app_grid.dart';

void main() {
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

  Future<void> _connectToDockService() async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 1);
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        await _dockService.ensureClientConnection();
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
      Navigator.of(context).pop(); // Close launcher after launching app
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
          duration: const Duration(seconds: 4),
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

  @override
  void dispose() {
    _searchController.dispose();
    _dockService.dispose();
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
                  ),
          ),
        ],
      ),
    );
  }


}