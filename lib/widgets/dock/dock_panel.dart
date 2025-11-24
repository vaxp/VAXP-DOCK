import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vaxp_core/models/desktop_entry.dart';
import '../../models/running_app.dart';
import 'dock_icon.dart';
import 'venom_dock_item.dart';
import 'animated_neon_border.dart';

class DockPanel extends StatefulWidget {
  final Function(DesktopEntry) onLaunch;
  final VoidCallback onShowLauncher;
  final VoidCallback? onMinimizeLauncher;
  final VoidCallback? onRestoreLauncher;
  final List<DesktopEntry> pinnedApps;
  final List<RunningApp> runningApps;
  final Function(String) onUnpin;
  final Function(int pid)? onFocusApp;
  final Function(int oldIndex, int newIndex)? onReorder;

  const DockPanel({
    super.key,
    required this.onLaunch,
    required this.onShowLauncher,
    this.onMinimizeLauncher,
    this.onRestoreLauncher,
    required this.pinnedApps,
    this.runningApps = const [],
    required this.onUnpin,
    this.onFocusApp,
    this.onReorder,
  });

  @override
  State<DockPanel> createState() => _DockPanelState();
}

class _DockPanelState extends State<DockPanel> {
  Widget _buildDockIcon(
    DesktopEntry entry, {
    bool isRunning = false,
    int? pid,
  }) {
    Widget iconWidget;

    if (entry.iconPath != null) {
      if (entry.isSvgIcon) {
        iconWidget = DockIcon(
          customChild: SvgPicture.file(
            File(entry.iconPath!),
            width: 40,
            height: 40,
          ),
          tooltip: entry.name,
          onTap: () {
            if (isRunning && pid != null && widget.onFocusApp != null) {
              widget.onFocusApp!(pid);
            } else {
              widget.onLaunch(entry);
            }
          },
        );
      } else {
        iconWidget = DockIcon(
          iconData: FileImage(File(entry.iconPath!)),
          tooltip: entry.name,
          onTap: () {
            if (isRunning && pid != null && widget.onFocusApp != null) {
              widget.onFocusApp!(pid);
            } else {
              widget.onLaunch(entry);
            }
          },
        );
      }
    } else {
      iconWidget = DockIcon(
        icon: Icons.apps,
        tooltip: entry.name,
        onTap: () {
          if (isRunning && pid != null && widget.onFocusApp != null) {
            widget.onFocusApp!(pid);
          } else {
            widget.onLaunch(entry);
          }
        },
      );
    }

    // Wrap all icons with VenomDockItem for neon effect
    // Running apps: cyan/purple (fast), Non-running: red (slow)
    Widget finalWidget = VenomDockItem(
      isFocused:
          isRunning, // true = نشط (سيان/بنفسجي سريع), false = غير نشط (أحمر بطيء)
      onTap: () {
        if (isRunning && pid != null && widget.onFocusApp != null) {
          widget.onFocusApp!(pid);
        } else {
          widget.onLaunch(entry);
        }
      },
      child: iconWidget,
    );

    // Wrap with context menu and running indicator
    return GestureDetector(
      onSecondaryTapUp: (details) => _showDockIconMenu(context, details, entry),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          finalWidget,
          if (isRunning)
            Positioned(
              bottom: 2,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.8),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDockIconMenu(
    BuildContext context,
    TapUpDetails details,
    DesktopEntry entry,
  ) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
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
      padding: const EdgeInsets.only(bottom: 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedNeonBorder(
            borderRadius: 18,
            borderWidth: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: const Color.fromARGB(
                  0,
                  0,
                  0,
                  0,
                ).withAlpha((0.5 * 255).toInt()),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onSecondaryTapUp: (details) {
                      final RenderBox overlay =
                          Overlay.of(context).context.findRenderObject()
                              as RenderBox;
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
                          if (widget.onMinimizeLauncher != null)
                            PopupMenuItem(
                              onTap: widget.onMinimizeLauncher,
                              child: const Text('Minimize Launcher'),
                            ),
                          if (widget.onRestoreLauncher != null)
                            PopupMenuItem(
                              onTap: widget.onRestoreLauncher,
                              child: const Text('Restore Launcher'),
                            ),
                        ],
                      );
                    },
                    child: DockIcon(
                      customChild: Image.asset(
                        'assets/logo.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                      ),
                      // icon: Icons.apps,
                      tooltip: 'Show all apps',
                      onTap: widget.onShowLauncher,
                    ),
                  ),
                  // Separator
                  Container(
                    width: 1,
                    height: 42,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.2 * 255).toInt()),
                      borderRadius: BorderRadius.circular(0.5),
                    ),
                  ),
                  // Pinned apps and running apps
                  Builder(
                    builder: (context) {
                      // Create a combined list: pinned apps with running status
                      final List<_DockItem> dockItems = [];

                      // Add pinned apps
                      for (int i = 0; i < widget.pinnedApps.length; i++) {
                        final pinned = widget.pinnedApps[i];
                        // Check if this pinned app is also running
                        final running = widget.runningApps.firstWhere(
                          (r) => r.name == pinned.name,
                          orElse: () => RunningApp(name: '', pid: -1),
                        );
                        dockItems.add(
                          _DockItem(
                            entry: pinned,
                            isPinned: true,
                            isRunning: running.pid != -1,
                            pid: running.pid != -1 ? running.pid : null,
                            pinnedIndex: i,
                          ),
                        );
                      }

                      // Add running apps that are not pinned
                      for (final running in widget.runningApps) {
                        final isPinned = widget.pinnedApps.any(
                          (p) => p.name == running.name,
                        );
                        if (!isPinned) {
                          dockItems.add(
                            _DockItem(
                              entry: running.toDesktopEntry(),
                              isPinned: false,
                              isRunning: true,
                              pid: running.pid,
                              pinnedIndex: null,
                            ),
                          );
                        }
                      }

                      if (dockItems.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: dockItems.asMap().entries.expand((itemEntry) {
                          final item = itemEntry.value;
                          final index = itemEntry.key;
                          final widgets = <Widget>[];

                          if (item.isPinned && item.pinnedIndex != null) {
                            // Draggable pinned app
                            final pinnedIdx = item
                                .pinnedIndex!; // Non-null assertion is safe here
                            widgets.add(
                              Draggable<int>(
                                data: pinnedIdx,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: _buildDockIcon(
                                    item.entry,
                                    isRunning: item.isRunning,
                                    pid: item.pid,
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: _buildDockIcon(
                                    item.entry,
                                    isRunning: item.isRunning,
                                    pid: item.pid,
                                  ),
                                ),
                                child: DragTarget<int>(
                                  onWillAcceptWithDetails: (details) =>
                                      details.data != pinnedIdx,
                                  onAcceptWithDetails: (details) {
                                    widget.onReorder?.call(
                                      details.data,
                                      pinnedIdx,
                                    );
                                  },
                                  builder:
                                      (context, candidateData, rejectedData) {
                                        return _buildDockIcon(
                                          item.entry,
                                          isRunning: item.isRunning,
                                          pid: item.pid,
                                        );
                                      },
                                ),
                              ),
                            );
                          } else {
                            // Non-draggable running app
                            widgets.add(
                              _buildDockIcon(
                                item.entry,
                                isRunning: item.isRunning,
                                pid: item.pid,
                              ),
                            );
                          }

                          // Add spacer between items
                          if (index < dockItems.length - 1) {
                            widgets.add(
                              Container(
                                width: 8,
                                height: 42,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              ),
                            );
                          }

                          return widgets;
                        }).toList(),
                      );
                    },
                  ),
                  // Right side utilities separator
                  Container(
                    width: 1,
                    height: 42,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
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
                        await Process.start('/bin/sh', [
                          '-c',
                          'xdg-open ~/Downloads',
                        ]);
                      } catch (e) {
                        if (!mounted) return;
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to open Downloads'),
                          ),
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
                        await Process.start('/bin/sh', [
                          '-c',
                          'xdg-open trash://',
                        ]);
                      } catch (e) {
                        if (!mounted) return;
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to open Trash')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper class to represent dock items (pinned or running)
class _DockItem {
  final DesktopEntry entry;
  final bool isPinned;
  final bool isRunning;
  final int? pid;
  final int? pinnedIndex; // null if not pinned

  _DockItem({
    required this.entry,
    required this.isPinned,
    required this.isRunning,
    this.pid,
    this.pinnedIndex,
  });
}
