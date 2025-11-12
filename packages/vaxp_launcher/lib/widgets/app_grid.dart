import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vaxp_core/models/desktop_entry.dart';

const double _kDotSize = 8.0;
const double _kDotSpacing = 8.0;

class AppGrid extends StatefulWidget {
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
  State<AppGrid> createState() => _AppGridState();
}

class AppIconTile extends StatefulWidget {
  final DesktopEntry entry;
  final String? iconPath;
  final bool isSvgIcon;
  final VoidCallback onLaunch;
  final void Function(DesktopEntry)? onPin;
  final void Function(DesktopEntry)? onUninstall;
  final void Function(DesktopEntry)? onCreateShortcut;
  final void Function(DesktopEntry)? onLaunchWithExternalGPU;

  const AppIconTile({
    super.key,
    required this.entry,
    required this.onLaunch,
    this.iconPath,
    required this.isSvgIcon,
    this.onPin,
    this.onUninstall,
    this.onCreateShortcut,
    this.onLaunchWithExternalGPU,
  });

  @override
  State<AppIconTile> createState() => _AppIconTileState();
}

class _AppIconTileState extends State<AppIconTile>
    with TickerProviderStateMixin {
  late final AnimationController _hoverController;
  late final AnimationController _pressController;
  late final AnimationController _menuController;
  OverlayEntry? _contextMenuEntry;
  Offset _pointerOffset = Offset.zero;

  static const Duration _hoverDuration = Duration(milliseconds: 220);
  static const Duration _pressDuration = Duration(milliseconds: 160);
  static const Duration _menuDuration = Duration(milliseconds: 180);
  static const double _menuWidth = 240;
  static const double _menuVerticalPadding = 18;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: _hoverDuration,
    );
    _pressController = AnimationController(
      vsync: this,
      duration: _pressDuration,
    );
    _menuController = AnimationController(vsync: this, duration: _menuDuration);
  }

  @override
  void dispose() {
    _removeContextMenu(immediate: true);
    _hoverController.dispose();
    _pressController.dispose();
    _menuController.dispose();
    super.dispose();
  }

  void _onPointerEnter(PointerEnterEvent _) {
    _hoverController.forward();
  }

  void _onPointerExit(PointerExitEvent _) {
    _hoverController.reverse();
    setState(() => _pointerOffset = Offset.zero);
  }

  void _onPointerHover(PointerHoverEvent event) {
    final size = context.size;
    if (size == null || size.width == 0 || size.height == 0) return;
    final dx = (event.localPosition.dx / size.width).clamp(0.0, 1.0);
    final dy = (event.localPosition.dy / size.height).clamp(0.0, 1.0);
    final next = Offset(dx - 0.5, dy - 0.5);
    if ((next - _pointerOffset).distance > 0.02) {
      setState(() => _pointerOffset = next);
    }
  }

  Future<void> _handleTap() async {
    if (_pressController.isAnimating) return;
    _removeContextMenu();
    try {
      await _pressController.forward();
      widget.onLaunch();
    } finally {
      if (mounted) {
        await _pressController.reverse();
      }
    }
  }

  void _showContextMenu(Offset globalPosition) {
    final actions = <_ContextAction>[
      if (widget.onPin != null)
        _ContextAction(
          label: 'Pin to dock',
          icon: Icons.push_pin_outlined,
          onSelected: () => widget.onPin?.call(widget.entry),
        ),
      if (widget.onCreateShortcut != null)
        _ContextAction(
          label: 'Create desktop shortcut',
          icon: Icons.desktop_windows_outlined,
          onSelected: () => widget.onCreateShortcut?.call(widget.entry),
        ),
      if (widget.onLaunchWithExternalGPU != null)
        _ContextAction(
          label: 'Run with external GPU',
          icon: Icons.memory_outlined,
          onSelected: () => widget.onLaunchWithExternalGPU?.call(widget.entry),
        ),
      if (widget.onUninstall != null)
        _ContextAction(
          label: 'Uninstall this app',
          icon: Icons.delete_forever_outlined,
          onSelected: () => widget.onUninstall?.call(widget.entry),
          isDestructive: true,
        ),
    ];

    if (actions.isEmpty) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _removeContextMenu(immediate: true);

    final screenSize = MediaQuery.of(context).size;
    const edgePadding = 18.0;
    final menuHeight =
        actions.length * 54.0 + _menuVerticalPadding * 2; // approximate height

    double left = globalPosition.dx;
    double top = globalPosition.dy;

    if (left + _menuWidth + edgePadding > screenSize.width) {
      left = math.max(edgePadding, screenSize.width - _menuWidth - edgePadding);
    }
    if (top + menuHeight + edgePadding > screenSize.height) {
      top = math.max(edgePadding, screenSize.height - menuHeight - edgePadding);
    }

    _menuController.value = 0;

    final entry = OverlayEntry(
      builder: (context) {
        return AnimatedBuilder(
          animation: _menuController,
          builder: (context, _) {
            final t = Curves.easeOut.transform(_menuController.value);
            final backdropOpacity = lerpDouble(0.0, 0.18, t)!;
            final elevation = lerpDouble(28, 48, t)!;
            final translationY = (1 - t) * 20;
            final scale = lerpDouble(0.88, 1.0, t)!;

            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _removeContextMenu,
                    onSecondaryTapDown: (_) => _removeContextMenu(),
                    child: Container(
                      color: Colors.black.withOpacity(backdropOpacity),
                    ),
                  ),
                ),
                Positioned(
                  left: left,
                  top: top,
                  child: Transform(
                    alignment: Alignment.topCenter,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..translate(0.0, translationY)
                      ..scale(scale, scale),
                    child: _ContextMenuPanel(
                      actions: actions,
                      onDismiss: _removeContextMenu,
                      elevation: elevation,
                      animationValue: t,
                      menuWidth: _menuWidth,
                      verticalPadding: _menuVerticalPadding,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    overlay.insert(entry);
    _contextMenuEntry = entry;
    _menuController.forward();
  }

  void _removeContextMenu({bool immediate = false}) {
    final entry = _contextMenuEntry;
    if (entry == null) return;

    void removeEntry() {
      entry.remove();
      if (identical(_contextMenuEntry, entry)) {
        _contextMenuEntry = null;
      }
    }

    if (immediate) {
      _menuController.stop();
      removeEntry();
      _menuController.value = 0;
      return;
    }

    if (_menuController.isAnimating ||
        _menuController.status == AnimationStatus.completed) {
      _menuController.reverse().whenComplete(removeEntry);
    } else {
      removeEntry();
    }
  }

  Widget _buildIcon() {
    final iconPath = widget.iconPath;
    if (iconPath == null || iconPath.isEmpty) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF4B6CB7), Color(0xFF182848)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.apps, size: 36, color: Colors.white),
      );
    }

    final file = File(iconPath);
    if (widget.isSvgIcon) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SvgPicture.file(
          file,
          width: 72,
          height: 72,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => const SizedBox(
            width: 72,
            height: 72,
            child: Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.file(
        file,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.apps, size: 48, color: Colors.white70),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final animation = Listenable.merge([_hoverController, _pressController]);
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: _onPointerEnter,
      onExit: _onPointerExit,
      onHover: _onPointerHover,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onSecondaryTapDown: (details) =>
            _showContextMenu(details.globalPosition),
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final hoverT = Curves.easeOutCubic.transform(
              _hoverController.value,
            );
            final pressT = Curves.easeOutQuad.transform(_pressController.value);

            final hoverScale = lerpDouble(1.0, 1.08, hoverT) ?? 1.0;
            final pressScale = lerpDouble(0.0, 0.06, pressT) ?? 0.0;
            final scale = (hoverScale - pressScale).clamp(0.9, 1.12);

            const tiltStrength = 0.25; // ~14 degrees at max
            final rotationX = -_pointerOffset.dy * tiltStrength * hoverT;
            final rotationY = _pointerOffset.dx * tiltStrength * hoverT;

            final shadowBlur = lerpDouble(18, 42, hoverT)!;
            final shadowOffset = lerpDouble(12, 28, hoverT)! - pressT * 8;
            final haloOpacity = lerpDouble(0.0, 0.28, hoverT)!;

            final matrix = Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateX(rotationX)
              ..rotateY(rotationY)
              ..scale(scale);

            final borderRadius = BorderRadius.circular(24);

            return Transform(
              alignment: Alignment.center,
              transform: matrix,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.16 + hoverT * 0.12),
                      const Color(0xFF141821).withOpacity(0.85),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08 + hoverT * 0.12),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45 + hoverT * 0.15),
                      blurRadius: shadowBlur,
                      spreadRadius: -8,
                      offset: Offset(0, shadowOffset),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.05 * hoverT),
                      blurRadius: 16,
                      spreadRadius: -12,
                      offset: const Offset(-8, -8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.18 + hoverT * 0.1),
                                Colors.white.withOpacity(0.04),
                                Colors.black.withOpacity(0.35),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: haloOpacity,
                            child: Container(
                              height: 38,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x66FFFFFF),
                                    Color(0x00000000),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: borderRadius,
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.secondary.withOpacity(
                                  0.08 * hoverT,
                                ),
                                blurRadius: 30,
                                spreadRadius: -20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildIcon(),
                            const SizedBox(height: 14),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                widget.entry.name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(
                                    lerpDouble(0.88, 1.0, hoverT)!,
                                  ),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(
                                        0.55 + hoverT * 0.15,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ContextAction {
  const _ContextAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final bool isDestructive;
}

class _ContextMenuPanel extends StatelessWidget {
  const _ContextMenuPanel({
    required this.actions,
    required this.onDismiss,
    required this.elevation,
    required this.animationValue,
    required this.menuWidth,
    required this.verticalPadding,
  });

  final List<_ContextAction> actions;
  final VoidCallback onDismiss;
  final double elevation;
  final double animationValue;
  final double menuWidth;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final surfaceGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(0.22),
        const Color(0xFF10131C).withOpacity(0.85),
      ],
    );

    final borderColor = Colors.white.withOpacity(0.16);

    return SizedBox(
      width: menuWidth,
      child: Transform(
        alignment: Alignment.topCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(0.08 * (1 - animationValue)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: elevation,
                spreadRadius: -12,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.07 * animationValue),
                blurRadius: 18,
                spreadRadius: -16,
                offset: const Offset(-10, -12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: verticalPadding),
                decoration: BoxDecoration(
                  gradient: surfaceGradient,
                  border: Border.all(color: borderColor, width: 0.9),
                ),
                child: _ContextMenuList(actions: actions, onDismiss: onDismiss),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContextMenuList extends StatelessWidget {
  const _ContextMenuList({required this.actions, required this.onDismiss});

  final List<_ContextAction> actions;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < actions.length; i++)
          _ContextMenuTile(
            action: actions[i],
            isFirst: i == 0,
            isLast: i == actions.length - 1,
            onDismiss: onDismiss,
            foregroundColor: theme.colorScheme.onSurface.withOpacity(
              actions[i].isDestructive ? 0.9 : 0.95,
            ),
          ),
      ],
    );
  }
}

class _ContextMenuTile extends StatefulWidget {
  const _ContextMenuTile({
    required this.action,
    required this.isFirst,
    required this.isLast,
    required this.onDismiss,
    required this.foregroundColor,
  });

  final _ContextAction action;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onDismiss;
  final Color foregroundColor;

  @override
  State<_ContextMenuTile> createState() => _ContextMenuTileState();
}

class _ContextMenuTileState extends State<_ContextMenuTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.action.isDestructive
        ? Colors.redAccent
        : Theme.of(context).colorScheme.secondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.onDismiss();
          Future.microtask(widget.action.onSelected);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withOpacity(
                    widget.action.isDestructive ? 0.08 : 0.12,
                  )
                : Colors.transparent,
            borderRadius: BorderRadius.vertical(
              top: widget.isFirst ? const Radius.circular(16) : Radius.zero,
              bottom: widget.isLast ? const Radius.circular(16) : Radius.zero,
            ),
            border: _hovered
                ? Border.all(color: accent.withOpacity(0.16), width: 0.8)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [accent.withOpacity(0.9), accent.withOpacity(0.4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.28),
                      blurRadius: 14,
                      spreadRadius: -6,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(widget.action.icon, size: 15, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.action.label,
                  style: TextStyle(
                    color: widget.action.isDestructive
                        ? Colors.redAccent.withOpacity(_hovered ? 0.92 : 0.8)
                        : widget.foregroundColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.15,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: Colors.white.withOpacity(_hovered ? 0.6 : 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppGridState extends State<AppGrid> {
  static const int itemsPerPage = 24;
  int _currentPage = 0;
  List<File> _themeFiles = [];
  late int _totalPages;
  final PageController _pageController = PageController();
  bool _isScrolling = false;
  DateTime _lastScrollTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadThemeFiles();
    _updateTotalPages();
  }

  void _updateTotalPages() {
    _totalPages = math.max(1, (widget.apps.length / itemsPerPage).ceil());
  }

  @override
  void didUpdateWidget(AppGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.iconThemeDir != oldWidget.iconThemeDir) {
      _loadThemeFiles();
    }
    if (widget.apps.length != oldWidget.apps.length) {
      _updateTotalPages();
      // Ensure current page is valid
      if (_currentPage >= _totalPages) {
        _currentPage = math.max(0, _totalPages - 1);
        _pageController.jumpToPage(_currentPage);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadThemeFiles() {
    _themeFiles = [];
    final dirPath = widget.iconThemeDir;
    if (dirPath == null || dirPath.isEmpty) return;
    try {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        _themeFiles = dir.listSync(recursive: true).whereType<File>().toList();
      }
    } catch (_) {
      _themeFiles = [];
    }
  }

  String? _resolveIconForEntry(DesktopEntry entry) {
    if (_themeFiles.isEmpty) return null;
    try {
      final Set<String> candidates = {};
      if (entry.iconPath != null && entry.iconPath!.isNotEmpty) {
        final raw = entry.iconPath!;
        final fn = raw.split(Platform.pathSeparator).last;
        final dot = fn.lastIndexOf('.');
        final base = dot > 0 ? fn.substring(0, dot) : fn;
        candidates.add(base.toLowerCase());
      }
      final nameBase = entry.name.toLowerCase();
      candidates.add(nameBase);
      candidates.add(nameBase.replaceAll(' ', '-'));
      candidates.add(nameBase.replaceAll(' ', '_'));
      candidates.add(nameBase.replaceAll(' ', ''));

      for (final file in _themeFiles) {
        final fn = file.path.split(Platform.pathSeparator).last;
        final dot = fn.lastIndexOf('.');
        final base = dot > 0 ? fn.substring(0, dot) : fn;
        final lower = base.toLowerCase();
        if (candidates.contains(lower) ||
            candidates.any((c) => fn.toLowerCase().contains(c))) {
          return file.path;
        }
      }
    } catch (_) {}
    return null;
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalPages, (index) {
        return Container(
          width: _kDotSize,
          height: _kDotSize,
          margin: EdgeInsets.symmetric(horizontal: _kDotSpacing / 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index
                ? Colors.blue
                // ignore: deprecated_member_use
                : Colors.grey.withOpacity(0.5),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Column(
      children: [
        Expanded(
          child: Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                final now = DateTime.now();
                if (_isScrolling &&
                    now.difference(_lastScrollTime).inMilliseconds < 300) {
                  return;
                }
                _isScrolling = true;
                _lastScrollTime = now;

                if (pointerSignal.scrollDelta.dy > 0 &&
                    _currentPage < _totalPages - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else if (pointerSignal.scrollDelta.dy < 0 &&
                    _currentPage > 0) {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }

                Future.delayed(const Duration(milliseconds: 300), () {
                  _isScrolling = false;
                });
              }
            },
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() => _currentPage = page);
              },
              itemCount: _totalPages,
              itemBuilder: (context, pageIndex) {
                final startIndex = pageIndex * itemsPerPage;
                if (startIndex >= widget.apps.length) {
                  return const SizedBox.shrink();
                }
                final endIndex = math.min(
                  startIndex + itemsPerPage,
                  widget.apps.length,
                );
                final pageApps = widget.apps.sublist(startIndex, endIndex);

                return Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        left: size.width * 0.083,
                        right: size.width * 0.083,
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              crossAxisSpacing: 18,
                              mainAxisSpacing: 18,
                              childAspectRatio: 1.45,
                            ),
                        itemCount: pageApps.length,
                        itemBuilder: (context, index) {
                          final entry = pageApps[index];
                          final themed = _resolveIconForEntry(entry);
                          final iconPath = themed ?? entry.iconPath;
                          final isSvg =
                              iconPath != null &&
                              iconPath.toLowerCase().endsWith('.svg');

                          return AppIconTile(
                            entry: entry,
                            iconPath: iconPath,
                            isSvgIcon: isSvg,
                            onLaunch: () => widget.onLaunch(entry),
                            onPin: widget.onPin,
                            onUninstall: widget.onInstall,
                            onCreateShortcut: widget.onCreateShortcut,
                            onLaunchWithExternalGPU:
                                widget.onLaunchWithExternalGPU,
                          );
                        },
                      ),
                    ),
                    if (_totalPages > 1) ...[
                      // Left arrow
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _currentPage > 0
                              ? IconButton(
                                  onPressed: () {
                                    _pageController.previousPage(
                                      duration: const Duration(
                                        milliseconds: 10,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.arrow_circle_left_rounded,
                                    color: Colors.white70,
                                    size: 48,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      // Right arrow
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _currentPage < _totalPages - 1
                              ? IconButton(
                                  onPressed: () {
                                    _pageController.nextPage(
                                      duration: const Duration(
                                        milliseconds: 10,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.arrow_circle_right_rounded,
                                    color: Colors.white70,
                                    size: 48,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        if (_totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildPageIndicator(),
          ),
      ],
    );
  }
}
