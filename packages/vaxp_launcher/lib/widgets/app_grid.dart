import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vaxp_core/models/desktop_entry.dart';

class AppGrid extends StatelessWidget {
  final List<DesktopEntry> apps;
  final String? iconThemeDir;
  final void Function(DesktopEntry) onLaunch;
  final void Function(DesktopEntry)? onPin;
  final void Function(DesktopEntry)? onInstall;
  final void Function(DesktopEntry)? onCreateShortcut;
  final void Function(DesktopEntry)? onLaunchWithExternalGPU;

  const AppGrid({
    super.key, 
    required this.apps, 
    required this.onLaunch,
    this.iconThemeDir,
    this.onPin,
    this.onInstall,
    this.onCreateShortcut,
    this.onLaunchWithExternalGPU,
  });

  @override
  Widget build(BuildContext context) {
    // Preload theme files if a directory was provided to avoid repeated IO
    List<File> themeFiles = [];
    if (iconThemeDir != null) {
      try {
        final dir = Directory(iconThemeDir!);
        if (dir.existsSync()) {
          themeFiles = dir
              .listSync(recursive: true)
              .whereType<File>()
              .toList();
        }
      } catch (e) {
        // ignore errors and fall back to original icons
      }
    }
    return GridView.builder(
      
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(

        crossAxisCount: 6,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2,
      ),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final e = apps[index];
        return GestureDetector(
          onSecondaryTapUp: (onPin == null && onInstall == null && onCreateShortcut == null && onLaunchWithExternalGPU == null) ? null : (details) {
            final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
            final position = RelativeRect.fromRect(
              Rect.fromPoints(
                details.globalPosition,
                details.globalPosition,
              ),
              Offset.zero & overlay.size,
            );
            
            final List<PopupMenuEntry> menuItems = [];
            
            if (onPin != null) {
              menuItems.add(
                PopupMenuItem(
                  child: const Text('Pin to dock'),
                  onTap: () {
                    Navigator.of(context).maybePop();
                    onPin?.call(e);
                  },
                ),
              );
            }
            
            if (onInstall != null) {
              menuItems.add(
                PopupMenuItem(
                  child: const Text('Uninstall this app'),
                  onTap: () {
                    Navigator.of(context).maybePop();
                    onInstall?.call(e);
                  },
                ),
              );
            }
            
            if (onCreateShortcut != null) {
              menuItems.add(
                PopupMenuItem(
                  child: const Text('Create desktop shortcut'),
                  onTap: () {
                    Navigator.of(context).maybePop();
                    onCreateShortcut?.call(e);
                  },
                ),
              );
            }
            
            if (onLaunchWithExternalGPU != null) {
              menuItems.add(
                PopupMenuItem(
                  child: const Text('Run with external GPU'),
                  onTap: () {
                    Navigator.of(context).maybePop();
                    onLaunchWithExternalGPU?.call(e);
                  },
                ),
              );
            }
            
            showMenu(
              context: context,
              position: position,
              items: menuItems,
            );
          },
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              onLaunch(e);
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color.fromARGB(0, 0, 0, 0),
                border: Border.all(color: Colors.transparent),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Builder(
                    builder: (context) {
                      // Try to resolve a themed icon first when available
                      String? themedPath;
                      if (themeFiles.isNotEmpty) {
                        try {
                          // Build candidate names from desktop entry
                          final candidates = <String>{};
                          if (e.iconPath != null && e.iconPath!.isNotEmpty) {
                            final raw = e.iconPath!;
                            final fn = raw.split(Platform.pathSeparator).last;
                            final dot = fn.lastIndexOf('.');
                            final base = dot > 0 ? fn.substring(0, dot) : fn;
                            candidates.add(base.toLowerCase());
                          }
                          final nameBase = e.name.toLowerCase();
                          candidates.add(nameBase);
                          candidates.add(nameBase.replaceAll(' ', '-'));
                          candidates.add(nameBase.replaceAll(' ', '_'));
                          candidates.add(nameBase.replaceAll(' ', ''));

                          for (final f in themeFiles) {
                            final fn = f.path.split(Platform.pathSeparator).last;
                            final dot = fn.lastIndexOf('.');
                            final base = dot > 0 ? fn.substring(0, dot) : fn;
                            final low = base.toLowerCase();
                            if (candidates.contains(low) || candidates.any((c) => fn.toLowerCase().contains(c))) {
                              themedPath = f.path;
                              break;
                            }
                          }
                        } catch (_) {
                          themedPath = null;
                        }
                      }

                      if (themedPath != null) {
                        // Render themed icon based on its type
                        if (themedPath.toLowerCase().endsWith('.svg')) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: SvgPicture.file(
                              File(themedPath),
                              width: 56,
                              height: 56,
                            ),
                          );
                        }

                        return CircleAvatar(
                          backgroundColor: Colors.transparent,
                          radius: 28,
                          backgroundImage: FileImage(File(themedPath)),
                        );
                      }

                      // Fallback to original icon
                      if (e.iconPath == null) {
                        return const Icon(Icons.apps, size: 48);
                      }

                      if (e.isSvgIcon) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: SvgPicture.file(
                            File(e.iconPath!),
                            width: 56,
                            height: 56,
                          ),
                        );
                      }

                      return CircleAvatar(
                        backgroundColor: Colors.transparent,
                        radius: 28,
                        backgroundImage: FileImage(File(e.iconPath!)),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}