import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/system_stats/presentation/widgets/system_stats_grid.dart';
import '../features/system_stats/presentation/cubit/system_stats_cubit.dart';
import '../features/system_stats/data/repositories/system_stats_repository.dart';
import '../widgets/app_grid.dart';
import '../con/controlcenterpage.dart';
import 'controllers/launcher_controller.dart';
import 'widgets/launcher_search_bar.dart';
import 'widgets/workspace_selector.dart';
import 'widgets/launcher_settings_dialog.dart';
import 'widgets/animated_neon_border.dart';

class LauncherHome extends StatefulWidget {
  const LauncherHome({super.key});

  @override
  State<LauncherHome> createState() => _LauncherHomeState();
}

class _LauncherHomeState extends State<LauncherHome> {
  late final LauncherController _controller;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = LauncherController(context);
    _controller.init();
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.disposeController();
    _searchController.dispose();
    super.dispose();
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) => LauncherSettingsDialog(
        initialBackgroundColor: _controller.backgroundColor,
        initialOpacity: _controller.opacity,
        initialBackgroundImagePath: _controller.backgroundImagePath,
        initialIconThemePath: _controller.iconThemePath,
        onApply: _controller.saveSettings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _controller.backgroundColor.withOpacity(
        _controller.opacity,
      ),
      body: Stack(
        children: [
          if (_controller.backgroundImagePath != null)
            Positioned.fill(
              child: Image.file(
                File(_controller.backgroundImagePath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          Positioned.fill(
            child: Container(
              color: _controller.backgroundColor.withOpacity(
                _controller.opacity,
              ),
            ),
          ),
          Column(
            children: [
              LauncherSearchBar(
                controller: _searchController,
                onChanged: _controller.filterApps,
                onSubmitted: _controller.handleSearchSubmit,
                onSettingsPressed: _showSettingsDialog,
                viewMode: _controller.viewMode,
                onViewModeToggle: _controller.toggleViewMode,
              ),

              // Workspace cards strip
              Row(
                children: [
                  Expanded(
                    child: AnimatedNeonBorder(
                      child: WorkspaceSelector(
                        workspaces: _controller.workspaces,
                        hoveredWorkspace: _controller.hoveredWorkspace,
                        onWorkspaceHover: _controller.setHoveredWorkspace,
                        onWorkspaceTap: _controller.switchToWorkspace,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: SizedBox(
                      height: 200,
                      width: MediaQuery.of(context).size.width / 5,
                      child: AnimatedNeonBorder(
                        child: BlocProvider<SystemStatsCubit>(
                          create: (_) =>
                              SystemStatsCubit(SystemStatsRepository()),
                          child: SystemStatsGrid(),
                        ),
                      ),
                    ),
                  ),
                  // Control Center next to workspaces
                  SizedBox(
                    height: 200,
                    width: 800,
                    child: AnimatedNeonBorder(child: ControlCenterPage()),
                  ),
                ],
              ),

              // Apps Grid
              Expanded(
                child: AppGrid(
                  apps: _controller.filteredApps,
                  iconThemeDir: _controller.iconThemePath,
                  runningAppNames: _controller.runningAppNames,
                  onLaunch: _controller.launchEntry,
                  onPin: _controller.pinApp,
                  onInstall: _controller.uninstallApp,
                  onCreateShortcut: _controller.createDesktopShortcut,
                  onLaunchWithExternalGPU: (entry) =>
                      _controller.launchEntry(entry, useExternalGPU: true),
                  viewMode: _controller.viewMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
