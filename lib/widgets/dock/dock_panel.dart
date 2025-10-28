import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/desktop_entry.dart';
import 'dock_icon.dart';
import '../app_launcher/app_grid.dart';

class DockPanel extends StatefulWidget {
  final Function(DesktopEntry) onLaunch;
  
  const DockPanel({
    super.key,
    required this.onLaunch,
  });

  @override
  State<DockPanel> createState() => _DockPanelState();
}

class _DockPanelState extends State<DockPanel> {
  late Future<List<DesktopEntry>> _allAppsFuture;
  List<DesktopEntry> _pinned = [];
  bool _isAppGridOpen = false;

  @override
  void initState() {
    super.initState();
    _allAppsFuture = DesktopEntry.loadAll();
    _loadPinnedApps();
  }

  Future<void> _loadPinnedApps() async {
    final apps = await _allAppsFuture;
    if (!mounted) return;
    setState(() {
      _pinned = apps.take(6).toList();
    });
  }

  void _openAppGrid(List<DesktopEntry> apps) async {
    setState(() {
      _isAppGridOpen = true;
    });
    
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SizedBox(
          width: 1200,
          height: 900,
          child: AppGrid(
            apps: apps,
            onLaunch: widget.onLaunch,
            onPin: _pinToDock,
          ),
        ),
      ),
    );
    
    setState(() {
      _isAppGridOpen = false;
    });
  }

  void _showDockIconMenu(BuildContext context, TapUpDetails details, int index) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        details.globalPosition,
        details.globalPosition,
      ),
      Offset.zero & overlay.size,
    );
    
    showMenu(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          child: const Text('Unpin from dock'),
          onTap: () {
            setState(() {
              _pinned.removeAt(index);
            });
          },
        ),
      ],
    );
  }

  void _pinToDock(DesktopEntry entry) {
    if (_pinned.length < 10 && !_pinned.any((e) => e.name == entry.name)) {
      setState(() {
        _pinned.add(entry);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAppGridOpen) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DockIcon(
                  icon: Icons.apps,
                  tooltip: 'Show all apps',
                  onTap: () async {
                    final apps = await _allAppsFuture;
                    _openAppGrid(apps);
                  },
                ),
                // Separator
                Container(
                  width: 1,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(0.5),
                  ),
                ),
                // Pinned apps
                if (_pinned.isNotEmpty)
                  ..._pinned.asMap().entries.expand(
                    (entry) {
                      if (entry.value.iconPath != null) {
                        Widget icon;
                        if (entry.value.isSvgIcon) {
                          icon = GestureDetector(
                            onSecondaryTapUp: (details) => _showDockIconMenu(context, details, entry.key),
                            child: DockIcon(
                              customChild: SvgPicture.file(
                                File(entry.value.iconPath!),
                                width: 48,
                                height: 48,
                              ),
                              tooltip: entry.value.name,
                              onTap: () => widget.onLaunch(entry.value),
                              name: entry.value.name,
                            ),
                          );
                        } else {
                          icon = GestureDetector(
                            onSecondaryTapUp: (details) => _showDockIconMenu(context, details, entry.key),
                            child: DockIcon(
                              iconData: FileImage(File(entry.value.iconPath!)),
                              tooltip: entry.value.name,
                              onTap: () => widget.onLaunch(entry.value),
                              name: entry.value.name,
                            ),
                          );
                        }
                        return [
                          icon,
                          if (entry.key < _pinned.length - 1) const SizedBox(width: 4),
                        ];
                      } else {
                        return [
                          GestureDetector(
                            onSecondaryTapUp: (details) => _showDockIconMenu(context, details, entry.key),
                            child: DockIcon(
                              icon: Icons.apps,
                              tooltip: entry.value.name,
                              onTap: () => widget.onLaunch(entry.value),
                              name: entry.value.name,
                            ),
                          ),
                          if (entry.key < _pinned.length - 1) const SizedBox(width: 4),
                        ];
                      }
                    },
                  ),
                // Right side utilities separator
                Container(
                  width: 1,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(0.5),
                  ),
                ),
                // Downloads folder
                DockIcon(
                  icon: Icons.folder,
                  tooltip: 'Downloads',
                  onTap: () async {
                    try {
                      await Process.start('/bin/sh', ['-c', 'xdg-open ~/Downloads']);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to open Downloads')),
                      );
                    }
                  },
                ),
                // Trash
                DockIcon(
                  icon: Icons.delete_outline,
                  tooltip: 'Trash',
                  onTap: () async {
                    try {
                      await Process.start('/bin/sh', ['-c', 'xdg-open trash://']);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to open Trash')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}