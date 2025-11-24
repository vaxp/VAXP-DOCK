import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vaxp_core/models/desktop_entry.dart';

/// Widget for displaying apps in a paged view with page indicators
class PagedAppView extends StatefulWidget {
  const PagedAppView({
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
  State<PagedAppView> createState() => _PagedAppViewState();
}

class _PagedAppViewState extends State<PagedAppView>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late FocusNode _focusNode;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _focusNode = FocusNode();
    // Auto-focus to enable keyboard navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(PagedAppView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.apps.length != oldWidget.apps.length) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Navigate to next page
  void _nextPage() {
    if (_currentPage < _getPages(context).length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Navigate to previous page
  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Handle keyboard events
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _nextPage();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _previousPage();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// Calculate number of apps per page
  /// Fixed layout: 4 rows × 6 columns = 24 apps per page
  int _getAppsPerPage(BuildContext context) {
    // Fixed grid: 4 rows × 6 columns
    const rows = 4;
    const columns = 6;
    return rows * columns; // Always 24 apps per page
  }

  /// Split apps into pages
  List<List<DesktopEntry>> _getPages(BuildContext context) {
    final appsPerPage = _getAppsPerPage(context);
    final pages = <List<DesktopEntry>>[];

    for (var i = 0; i < widget.apps.length; i += appsPerPage) {
      final end = (i + appsPerPage).clamp(0, widget.apps.length);
      pages.add(widget.apps.sublist(i, end));
    }

    return pages.isEmpty ? [[]] : pages;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _getPages(context);

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        // Handle mouse scroll
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            if (pointerSignal.scrollDelta.dy > 0) {
              _nextPage();
            } else if (pointerSignal.scrollDelta.dy < 0) {
              _previousPage();
            }
          }
        },
        child: Stack(
          children: [
            Column(
              children: [
                // PageView with apps
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: pages.length,
                    itemBuilder: (context, pageIndex) {
                      return AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          final size = MediaQuery.of(context).size;
                          return GridView.builder(
                            padding: EdgeInsets.symmetric(
                              // اجعلها 18% لكن لا تقل عن 20 بكسل ولا تزيد عن 400 بكسل
                              
                              horizontal: (size.width * 0.18).clamp(
                                20.0,
                                400.0,
                              ),
                              vertical: (size.height * 0.04).clamp(10.0, 60.0),
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 6, // Fixed 6 columns
                                  childAspectRatio: 1,
                                  crossAxisSpacing: 1,
                                  mainAxisSpacing: 1,
                                ),
                            itemCount: pages[pageIndex].length,
                            itemBuilder: (context, index) {
                              final app = pages[pageIndex][index];

                              // Staggered animation calculation
                              final double animationStart = (index * 0.02)
                                  .clamp(0.0, 0.8);
                              final double animationEnd = (animationStart + 0.4)
                                  .clamp(0.0, 1.0);

                              final Animation<double> opacity =
                                  Tween<double>(begin: 0.0, end: 1.0).animate(
                                    CurvedAnimation(
                                      parent: _animationController,
                                      curve: Interval(
                                        animationStart,
                                        animationEnd,
                                        curve: Curves.easeOut,
                                      ),
                                    ),
                                  );

                              final Animation<double> scale =
                                  Tween<double>(begin: 0.8, end: 1.0).animate(
                                    CurvedAnimation(
                                      parent: _animationController,
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
                                    isRunning: widget.runningAppNames.contains(
                                      app.name,
                                    ),
                                    onLaunch: () => widget.onLaunch(app),
                                    onPin: () => widget.onPin(app),
                                    onInstall: () => widget.onInstall(app),
                                    onCreateShortcut: () =>
                                        widget.onCreateShortcut(app),
                                    onLaunchWithExternalGPU: () =>
                                        widget.onLaunchWithExternalGPU(app),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),

                // Page indicators
                if (pages.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Navigation buttons (left and right arrows)
            if (pages.length > 1) ...[
              // Left arrow
              if (_currentPage > 0)
                Positioned(
                  left: 16,
                  top: 0,
                  bottom: 80,
                  child: Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _previousPage,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Right arrow
              if (_currentPage < pages.length - 1)
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 80,
                  child: Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _nextPage,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Individual app item widget (reused from AppGrid)
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
                    width: 96,
                    height: 96,
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
          width: 96,
          height: 96,
          placeholderBuilder: (_) =>
              const Icon(Icons.apps, color: Colors.white54, size: 72),
        );
      } else {
        return Image.file(
          File(widget.app.iconPath!),
          width: 96,
          height: 96,
          cacheWidth: 96,
          cacheHeight: 96,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.apps, color: Colors.white54, size: 72),
        );
      }
    }
    return const Icon(Icons.apps, color: Colors.white54, size: 72);
  }
}
