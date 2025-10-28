import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vaxp_core/models/desktop_entry.dart';
import 'package:vaxp_core/services/dock_service.dart';
import 'dock_icon.dart';

class DockPanel extends StatefulWidget {
  final Function(DesktopEntry) onLaunch;
  final VoidCallback onShowLauncher;
  final List<DesktopEntry> pinnedApps;
  final Function(String) onUnpin;
  
  const DockPanel({
    super.key,
    required this.onLaunch,
    required this.onShowLauncher,
    required this.pinnedApps,
    required this.onUnpin,
  });

  @override
  State<DockPanel> createState() => _DockPanelState();
}

class _DockPanelState extends State<DockPanel> {
  void _showDockIconMenu(BuildContext context, TapUpDetails details, DesktopEntry entry) {
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
          onTap: () => widget.onUnpin(entry.name),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 31.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DockIcon(
                  icon: Icons.apps,
                  tooltip: 'Show all apps',
                  onTap: widget.onShowLauncher,
                ),
                // Separator
                Container(
                  width: 1,
                  height: 33,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(0.5),
                  ),
                ),
                // Pinned apps
                if (widget.pinnedApps.isNotEmpty)
                  ...widget.pinnedApps.asMap().entries.expand(
                    (entry) {
                      if (entry.value.iconPath != null) {
                        Widget icon;
                        if (entry.value.isSvgIcon) {
                          icon = GestureDetector(
                            onSecondaryTapUp: (details) => _showDockIconMenu(context, details, entry.value),
                            child: DockIcon(
                              customChild: SvgPicture.file(
                                File(entry.value.iconPath!),
                                width: 30,
                                height: 30,
                              ),
                              tooltip: entry.value.name,
                              onTap: () => widget.onLaunch(entry.value),
                              name: entry.value.name,
                            ),
                          );
                        } else {
                          icon = GestureDetector(
                            onSecondaryTapUp: (details) => _showDockIconMenu(context, details, entry.value),
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
                          if (entry.key < widget.pinnedApps.length - 1) const SizedBox(width: 4),
                        ];
                      } else {
                        return [
                          GestureDetector(
                            onSecondaryTapUp: (details) => _showDockIconMenu(context, details, entry.value),
                            child: DockIcon(
                              icon: Icons.apps,
                              tooltip: entry.value.name,
                              onTap: () => widget.onLaunch(entry.value),
                              name: entry.value.name,
                            ),
                          ),
                          if (entry.key < widget.pinnedApps.length - 1) const SizedBox(width: 4),
                        ];
                      }
                    },
                  ),
                // Right side utilities separator
                Container(
                  width: 1,
                  height: 36,
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