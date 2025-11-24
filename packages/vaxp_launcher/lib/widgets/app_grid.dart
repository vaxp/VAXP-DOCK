import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vaxp_core/models/desktop_entry.dart';

class AppGrid extends StatefulWidget {
  const AppGrid({
    super.key,
    required this.apps,
    required this.iconThemeDir,
    required this.runningAppNames,
    required this.onLaunch,
    required this.onPin,
    required this.onInstall,
    required this.onCreateShortcut,
    required this.onLaunchWithExternalGPU,
  });

  final List<DesktopEntry> apps;
  final String? iconThemeDir;
  final Set<String> runningAppNames;
  final Function(DesktopEntry) onLaunch;
  final Function(DesktopEntry) onPin;
  final Function(DesktopEntry) onInstall;
  final Function(DesktopEntry) onCreateShortcut;
  final Function(DesktopEntry) onLaunchWithExternalGPU;

  @override
  State<AppGrid> createState() => _AppGridState();
}

class _AppGridState extends State<AppGrid> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void didUpdateWidget(AppGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.apps.length != oldWidget.apps.length) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120,
            childAspectRatio: 0.85,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: widget.apps.length,
          itemBuilder: (context, index) {
            final app = widget.apps[index];

            // Staggered animation calculation
            final double animationStart = (index * 0.02).clamp(0.0, 0.8);
            final double animationEnd = (animationStart + 0.4).clamp(0.0, 1.0);

            final Animation<double> opacity =
                Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _controller,
                    curve: Interval(
                      animationStart,
                      animationEnd,
                      curve: Curves.easeOut,
                    ),
                  ),
                );

            final Animation<double> scale = Tween<double>(begin: 0.8, end: 1.0)
                .animate(
                  CurvedAnimation(
                    parent: _controller,
                    curve: Interval(
                      animationStart,
                      animationEnd,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                );

            return FadeTransition(
              opacity: opacity,
              child: ScaleTransition(
                scale: scale,
                child: _AppGridItem(
                  app: app,
                  isRunning: widget.runningAppNames.contains(app.name),
                  onLaunch: () => widget.onLaunch(app),
                  onPin: () => widget.onPin(app),
                  onInstall: () => widget.onInstall(app),
                  onCreateShortcut: () => widget.onCreateShortcut(app),
                  onLaunchWithExternalGPU: () =>
                      widget.onLaunchWithExternalGPU(app),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AppGridItem extends StatefulWidget {
  const _AppGridItem({
    required this.app,
    required this.isRunning,
    required this.onLaunch,
    required this.onPin,
    required this.onInstall,
    required this.onCreateShortcut,
    required this.onLaunchWithExternalGPU,
  });

  final DesktopEntry app;
  final bool isRunning;
  final VoidCallback onLaunch;
  final VoidCallback onPin;
  final VoidCallback onInstall;
  final VoidCallback onCreateShortcut;
  final VoidCallback onLaunchWithExternalGPU;

  @override
  State<_AppGridItem> createState() => _AppGridItemState();
}

class _AppGridItemState extends State<_AppGridItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onLaunch,
        onSecondaryTapUp: (details) {
          final RenderBox overlay =
              Overlay.of(context).context.findRenderObject() as RenderBox;
          showMenu(
            context: context,
            position: RelativeRect.fromRect(
              details.globalPosition & Size.zero,
              Offset.zero & overlay.size,
            ),
            color: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            items: <PopupMenuEntry<dynamic>>[
              PopupMenuItem(
                onTap: widget.onPin,
                child: const Row(
                  children: [
                    Icon(
                      Icons.push_pin_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text('Pin to Dock', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: widget.onCreateShortcut,
                child: const Row(
                  children: [
                    Icon(Icons.shortcut, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Create Shortcut',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: widget.onLaunchWithExternalGPU,
                child: const Row(
                  children: [
                    Icon(Icons.memory, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Launch with GPU',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                onTap: widget.onInstall,
                child: const Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Uninstall',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: _isHovered
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 12,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: _buildIcon(),
                  ),
                  if (widget.isRunning)
                    Positioned(
                      bottom: -4,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white,
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  widget.app.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: _isHovered ? 1.0 : 0.9,
                    ),
                    fontSize: 13,
                    fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: 0.2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (widget.app.iconPath != null) {
      if (widget.app.iconPath!.endsWith('.svg')) {
        return SvgPicture.file(
          File(widget.app.iconPath!),
          width: 64,
          height: 64,
          placeholderBuilder: (_) =>
              const Icon(Icons.apps, color: Colors.white54, size: 48),
        );
      } else {
        return Image.file(
          File(widget.app.iconPath!),
          width: 64,
          height: 64,
          cacheWidth: 64,
          cacheHeight: 64,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.apps, color: Colors.white54, size: 48),
        );
      }
    }
    return const Icon(Icons.apps, color: Colors.white54, size: 48);
  }
}
