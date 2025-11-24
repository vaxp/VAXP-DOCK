import 'package:flutter/material.dart';
import '../../core/enums/view_mode.dart';

class LauncherSearchBar extends StatelessWidget {
  const LauncherSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onSettingsPressed,
    required this.viewMode,
    required this.onViewModeToggle,
  });

  final TextEditingController controller;
  final Function(String) onChanged;
  final Function(String) onSubmitted;
  final VoidCallback onSettingsPressed;
  final ViewMode viewMode;
  final VoidCallback onViewModeToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: MediaQuery.of(context).size.width / 2.5),
          Container(
            alignment: Alignment.center,
            width: MediaQuery.of(context).size.width / 5,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 22,
                  spreadRadius: -12,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.08),
                  blurRadius: 10,
                  spreadRadius: -8,
                  offset: const Offset(-6, -6),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search applications...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.04),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          // View mode toggle button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 18,
                    spreadRadius: -10,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.08),
                    blurRadius: 8,
                    spreadRadius: -8,
                    offset: const Offset(-4, -4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: onViewModeToggle,
                icon: Icon(
                  viewMode == ViewMode.grid
                      ? Icons.view_carousel
                      : Icons.view_module,
                ),
                iconSize: 26,
                color: Colors.white,
                tooltip: viewMode == ViewMode.grid
                    ? 'Switch to Paged View'
                    : 'Switch to Grid View',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.all(6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 18,
                    spreadRadius: -10,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.08),
                    blurRadius: 8,
                    spreadRadius: -8,
                    offset: const Offset(-4, -4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: onSettingsPressed,
                icon: const Icon(Icons.settings),
                iconSize: 26,
                color: Colors.white,
                tooltip: 'Settings',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.all(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
