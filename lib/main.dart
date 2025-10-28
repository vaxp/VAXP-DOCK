import 'dart:io';
import 'package:flutter/material.dart';
import 'models/desktop_entry.dart';
import 'widgets/dock/dock_panel.dart';

void main() {
  runApp(const DockApp());
}

class DockApp extends StatelessWidget {
  const DockApp({super.key});

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
      home: const DockHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DockHome extends StatefulWidget {
  const DockHome({super.key});

  @override
  State<DockHome> createState() => _DockHomeState();
}

class _DockHomeState extends State<DockHome> {
  String? _backgroundImagePath;

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
            ),
          ),
        ],
      ),
    );
  }
}