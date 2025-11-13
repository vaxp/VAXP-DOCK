import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dbus/dbus.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:window_manager/window_manager.dart';
import 'package:vaxp_core/models/desktop_entry.dart';
import 'package:file_picker/file_picker.dart';
import 'package:vaxp_core/services/dock_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:math_expressions/math_expressions.dart';
import '../features/system_stats/presentation/widgets/system_stats_grid.dart';
import '../features/system_stats/presentation/cubit/system_stats_cubit.dart';
import '../features/system_stats/data/repositories/system_stats_repository.dart';
import '../widgets/app_grid.dart';
import '../widgets/password_dialog.dart';
import '../widgets/color_picker_dialog.dart';
import '../services/settings_service.dart';
import '../services/gpu_service.dart';
import '../services/package_service.dart';
import '../services/shortcut_service.dart';
import '../services/workspace_service.dart';
import '../con/controlcenterpage.dart';

class LauncherHome extends StatefulWidget {
  const LauncherHome({super.key});

  @override
  State<LauncherHome> createState() => _LauncherHomeState();
}

class _ConsoleEntry {
  _ConsoleEntry(this.text, {this.isError = false});

  final String text;
  final bool isError;
}

enum _SearchResultType { directory, application, archive, image, video, other }

class _SearchResult {
  _SearchResult({required this.path, required this.name, required this.type});

  final String path;
  final String name;
  final _SearchResultType type;
}

class _CommandConsoleDialog extends StatefulWidget {
  const _CommandConsoleDialog({required this.command, required this.process});

  final String command;
  final Process process;

  @override
  State<_CommandConsoleDialog> createState() => _CommandConsoleDialogState();
}

class _CommandConsoleDialogState extends State<_CommandConsoleDialog> {
  final List<_ConsoleEntry> _entries = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  bool _isDone = false;
  int? _exitCode;

  @override
  void initState() {
    super.initState();
    _entries.add(_ConsoleEntry('\$ ${widget.command}\n', isError: false));
    _stdoutSub = widget.process.stdout
        .transform(utf8.decoder)
        .listen(
          (data) => _appendOutput(data, false),
          onError: (error) => _appendOutput('$error\n', true),
        );
    _stderrSub = widget.process.stderr
        .transform(utf8.decoder)
        .listen(
          (data) => _appendOutput(data, true),
          onError: (error) => _appendOutput('$error\n', true),
        );
    widget.process.exitCode.then((code) {
      if (!mounted) return;
      setState(() {
        _isDone = true;
        _exitCode = code;
        final message = '\n[process exited with code $code]\n';
        _entries.add(_ConsoleEntry(message, isError: code != 0));
      });
      _scheduleScroll();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _inputFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    if (!_isDone) {
      widget.process.kill(ProcessSignal.sigterm);
    }
    try {
      widget.process.stdin.close();
    } catch (_) {}
    super.dispose();
  }

  void _appendOutput(String data, bool isError) {
    if (data.isEmpty) return;
    final sanitized = data.replaceAll('\r\n', '\n');
    setState(() {
      _entries.add(_ConsoleEntry(sanitized, isError: isError));
    });
    _scheduleScroll();
  }

  void _scheduleScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendInput() {
    if (_isDone) return;
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    try {
      widget.process.stdin.writeln(text);
    } catch (e) {
      _appendOutput('\n[stdin error: $e]\n', true);
    }
    _inputController.clear();
  }

  void _terminateProcess() {
    if (_isDone) return;
    widget.process.kill(ProcessSignal.sigterm);
    _appendOutput('\n[process terminated]\n', true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Dialog(
      backgroundColor: const Color(0xFF1F252F),
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 720,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.terminal, color: Colors.white70),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Command Console',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_exitCode != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _exitCode == 0
                            ? Colors.green.withOpacity(0.2)
                            : Colors.redAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Exit ${_exitCode ?? 0}',
                        style: TextStyle(
                          color: _exitCode == 0
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: SelectableText(
                  widget.command,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141923),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10, width: 0.8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _entries.length,
                      itemBuilder: (_, index) {
                        final entry = _entries[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: SelectableText(
                            entry.text,
                            style: TextStyle(
                              color: entry.isError
                                  ? Colors.redAccent
                                  : Colors.white70,
                              fontFamily: 'monospace',
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      focusNode: _inputFocusNode,
                      enabled: !_isDone,
                      onSubmitted: (_) => _sendInput(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        hintText: _isDone
                            ? 'Process finished'
                            : 'Type input and press Enter',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: accent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isDone ? null : _sendInput,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('Send'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!_isDone)
                    TextButton(
                      onPressed: _terminateProcess,
                      child: const Text(
                        'Terminate',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _isDone
                        ? () => Navigator.of(context).pop()
                        : null,
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: _isDone ? Colors.white : Colors.white24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassDialogShell extends StatelessWidget {
  const _GlassDialogShell({
    required this.child,
    required this.title,
    required this.onClose,
    this.width = 520,
  });

  final Widget child;
  final String title;
  final VoidCallback onClose;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.18),
                const Color(0xFF0E141F).withOpacity(0.88),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 36,
                spreadRadius: -18,
                offset: const Offset(0, 28),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 20, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    _GlassIconButton(icon: Icons.close_rounded, onTap: onClose),
                  ],
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassSection extends StatelessWidget {
  const _GlassSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.black.withOpacity(0.35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 26,
            spreadRadius: -16,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _GlassButton extends StatefulWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.accent = const Color(0xFF2D9CFF),
    this.destructive = false,
    this.filled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color accent;
  final bool destructive;
  final bool filled;

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color baseAccent = widget.destructive
        ? Colors.redAccent
        : widget.accent;
    final bool filled = widget.filled || widget.destructive;

    final gradientColors = filled
        ? [
            baseAccent.withOpacity(_hovered ? 0.94 : 0.82),
            baseAccent.withOpacity(_hovered ? 0.62 : 0.46),
          ]
        : [
            Colors.white.withOpacity(_hovered ? 0.18 : 0.12),
            Colors.white.withOpacity(_hovered ? 0.06 : 0.02),
          ];

    final borderColor = filled
        ? baseAccent.withOpacity(_hovered ? 0.42 : 0.3)
        : Colors.white.withOpacity(_hovered ? 0.28 : 0.18);

    final textColor = filled ? Colors.white : Colors.white.withOpacity(0.9);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: filled
                    ? baseAccent.withOpacity(0.28)
                    : Colors.black.withOpacity(0.2),
                blurRadius: filled ? 22 : 18,
                spreadRadius: -10,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 18, color: textColor),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatefulWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(_hovered ? 0.22 : 0.12),
            border: Border.all(
              color: Colors.white.withOpacity(_hovered ? 0.35 : 0.18),
              width: 0.9,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ),
    );
  }
}

class _LauncherHomeState extends State<LauncherHome> {
  late Future<List<DesktopEntry>> _allAppsFuture;
  final _searchController = TextEditingController();
  List<DesktopEntry> _filteredApps = [];
  bool _isLoading = true;
  late final VaxpDockService _dockService;
  late final DBusClient _dbusClient;
  StreamSubscription<DBusSignal>? _minimizeSub;
  StreamSubscription<DBusSignal>? _restoreSub;

  // Settings state
  Color _backgroundColor = Colors.black;
  double _opacity = 0.7;
  String? _backgroundImagePath;
  String? _iconThemePath;

  final _settings = SettingsService();
  final _gpuService = GpuService();
  final _pkgService = PackageService();
  final _shortcutService = ShortcutService();
  final _workspaceService = WorkspaceService();

  List<Workspace> _workspaces = [];
  int? _hoveredWorkspace;
  Set<String> _runningAppNames = {}; // Track running apps by name

  static const int _fileSearchMaxDepth = 4;
  static const int _fileSearchMaxResults = 50;
  static const Set<String> _fileSearchExcludedDirectoryNames = {
    'desktop',
    'home',
    '.cache',
    '.config',
    '.local',
    '.npm',
    '.cargo',
    '.dart_tool',
    '.idea',
    '.venv',
    '__pycache__',
    'build',
    'dist',
    'node_modules',
    'target',
    'vendor',
  };
  static const Set<String> _archiveExtensions = {
    '.zip',
    '.tar',
    '.tar.gz',
    '.tar.bz2',
    '.tar.xz',
    '.tgz',
    '.tbz',
    '.tbz2',
    '.txz',
    '.gz',
    '.bz2',
    '.xz',
    '.7z',
    '.rar',
  };
  static const Set<String> _imageExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.bmp',
    '.svg',
    '.webp',
    '.tiff',
    '.ico',
  };
  static const Set<String> _videoExtensions = {
    '.mp4',
    '.mkv',
    '.mov',
    '.avi',
    '.webm',
    '.flv',
    '.wmv',
    '.mpeg',
    '.mpg',
  };
  static const Set<String> _applicationExtensions = {
    '.desktop',
    '.appimage',
    '.sh',
    '.run',
    '.bin',
    '.deb',
    '.rpm',
    '.flatpakref',
    '.flatpakrepo',
  };

  @override
  void initState() {
    super.initState();
    _allAppsFuture = DesktopEntry.loadAll();
    _loadApps();
    _dockService = VaxpDockService();
    _connectToDockService();
    _setupDockSignalListeners();
    _loadSettings();
    _loadWorkspaces();
  }

  Future<void> _loadWorkspaces() async {
    try {
      final list = await _workspaceService.listWorkspaces();
      if (!mounted) return;
      setState(() => _workspaces = list);
    } catch (e) {
      debugPrint('Failed to load workspaces: $e');
    }
  }

  Future<void> _switchToWorkspace(int idx) async {
    final ok = await _workspaceService.switchTo(idx);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not switch workspace: utility not found'),
        ),
      );
    } else {
      await _loadWorkspaces();
    }
  }

  Future<void> _loadSettings() async {
    final s = await _settings.load();
    if (!mounted) return;
    setState(() {
      _backgroundColor = s.backgroundColor;
      _opacity = s.opacity;
      _backgroundImagePath = s.backgroundImagePath;
      _iconThemePath = s.iconThemePath;
    });
  }

  Future<void> _saveSettings() async {
    await _settings.save(
      LauncherSettings(
        backgroundColor: _backgroundColor,
        opacity: _opacity,
        backgroundImagePath: _backgroundImagePath,
        iconThemePath: _iconThemePath,
      ),
    );
  }

  Future<void> _connectToDockService() async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 1);
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        await _dockService.ensureClientConnection();
        try {
          await _dockService.reportLauncherState('visible');
        } catch (_) {}
        return;
      } catch (e) {
        retryCount++;
        if (retryCount == maxRetries) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to connect to dock service: $e')),
          );
          return;
        }
        await Future.delayed(retryDelay);
      }
    }
  }

  void _setupDockSignalListeners() {
    try {
      _dbusClient = DBusClient.session();

      _minimizeSub =
          DBusSignalStream(
            _dbusClient,
            interface: vaxpInterfaceName,
            name: 'MinimizeWindow',
            signature: DBusSignature('s'),
          ).asBroadcastStream().listen((signal) async {
            try {
              await windowManager.minimize();
              try {
                await _dockService.reportLauncherState('minimized');
              } catch (e) {
                debugPrint('Failed to report minimized state to dock: $e');
              }
            } catch (e, st) {
              debugPrint('Error handling MinimizeWindow signal: $e\n$st');
            }
          });

      _restoreSub =
          DBusSignalStream(
            _dbusClient,
            interface: vaxpInterfaceName,
            name: 'RestoreWindow',
            signature: DBusSignature('s'),
          ).asBroadcastStream().listen((signal) async {
            try {
              await windowManager.restore();
              await windowManager.show();
              await windowManager.focus();
              try {
                await _dockService.reportLauncherState('visible');
              } catch (e) {
                debugPrint('Failed to report visible state to dock: $e');
              }
            } catch (e, st) {
              debugPrint('Error handling RestoreWindow signal: $e\n$st');
            }
          });
    } catch (e) {
      debugPrint('Failed to set up dock signal listeners: $e');
    }
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    final apps = await _allAppsFuture;
    if (!mounted) return;
    setState(() {
      _filteredApps = apps;
      _isLoading = false;
    });
  }

  Future<void> _refreshApps() async {
    _allAppsFuture = DesktopEntry.loadAll();
    setState(() => _isLoading = true);
    final apps = await _allAppsFuture;
    if (!mounted) return;
    final query = _searchController.text.trim();
    setState(() {
      if (query.isEmpty) {
        _filteredApps = apps;
      } else {
        _filteredApps = apps
            .where(
              (app) => app.name.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
      _isLoading = false;
    });
  }

  void _handleSearchSubmit(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      _filterApps('');
      return;
    }
    if (_handleSpecialSearch(query)) {
      return;
    }
    _filterApps(query);
  }

  bool _handleSpecialSearch(String query) {
    final lower = query.toLowerCase();
    if (lower.startsWith('vater:')) {
      final command = query.substring('vater:'.length).trim();
      if (command.isEmpty) {
        _showSnackMessage('Enter a command after "vater:".');
      } else {
        _executeShellCommand(command);
      }
      return true;
    }
    if (query.startsWith('!:')) {
      final expression = query.substring('!:'.length).trim();
      if (expression.isEmpty) {
        _showSnackMessage('Enter an expression after "!:" to calculate.');
      } else {
        _evaluateMathExpression(expression);
      }
      return true;
    }
    if (lower.startsWith('vafile:')) {
      final term = query.substring('vafile:'.length).trim();
      if (term.isEmpty) {
        _showSnackMessage('Enter a search term after "vafile:".');
      } else {
        _performFileSearch(term);
      }
      return true;
    }
    if (lower.startsWith('g:')) {
      final term = query.substring(2).trim();
      if (term.isEmpty) {
        _showSnackMessage('Enter a search term after "g:".');
      } else {
        final url =
            'https://github.com/search?q=${Uri.encodeQueryComponent(term)}';
        unawaited(_launchWebSearch(url, description: 'GitHub'));
        _resetSearchField();
      }
      return true;
    }
    if (lower.startsWith('s:')) {
      final term = query.substring(2).trim();
      if (term.isEmpty) {
        _showSnackMessage('Enter a search term after "s:".');
      } else {
        final url =
            'https://www.google.com/search?q=${Uri.encodeQueryComponent(term)}';
        unawaited(_launchWebSearch(url, description: 'Google'));
        _resetSearchField();
      }
      return true;
    }
    return false;
  }

  void _filterApps(String query) {
    _allAppsFuture.then((apps) {
      if (!mounted) return;
      setState(() {
        _filteredApps = apps
            .where(
              (app) => app.name.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      });
    });
  }

  Future<void> _launchEntry(
    DesktopEntry entry, {
    bool useExternalGPU = false,
  }) async {
    final cmd = entry.exec;
    if (cmd == null) return;
    final cleaned = cmd.replaceAll(RegExp(r'%[a-zA-Z]'), '').trim();
    if (cleaned.isEmpty) return;

    final finalCmd = useExternalGPU
        ? await _gpuService.buildGpuCommand(cleaned)
        : cleaned;

    try {
      // Start the process and get its PID
      final process = await Process.start('/bin/sh', ['-c', finalCmd]);
      final shellPid = process.pid;

      // Register the running app with the dock
      try {
        await _dockService.ensureClientConnection();

        // Try to get the actual application PID after a short delay
        // This handles cases where the shell launches a detached process
        Future.delayed(const Duration(milliseconds: 500), () async {
          int actualPid = shellPid;

          // Try to find the process by extracting the command name
          try {
            final cmdName = cleaned.split(' ').first.split('/').last;
            if (cmdName.isNotEmpty && cmdName != 'sh' && cmdName != 'bash') {
              // Try to find the process by name
              final pgrepResult = await Process.run('pgrep', ['-f', cmdName]);
              if (pgrepResult.exitCode == 0) {
                final pids = (pgrepResult.stdout as String).trim().split('\n');
                if (pids.isNotEmpty && pids[0].isNotEmpty) {
                  final foundPid = int.tryParse(pids[0]);
                  if (foundPid != null && foundPid != shellPid) {
                    actualPid = foundPid;
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Could not find actual PID, using shell PID: $e');
          }

          // Register with the actual PID
          await _dockService.registerRunningApp(entry, actualPid);

          // Mark app as running in launcher
          if (mounted) {
            setState(() {
              _runningAppNames.add(entry.name);
            });
          }

          // Monitor the process and unregister when it exits
          // Check periodically if the process is still running
          _monitorProcess(actualPid, entry.name);
        });
      } catch (e) {
        debugPrint('Failed to register app with dock: $e');
        // Continue even if dock registration fails
      }

      await windowManager.minimize();
      try {
        await _dockService.reportLauncherState('minimized');
      } catch (e) {
        debugPrint('Failed to report minimized state to dock: $e');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch ${entry.name}: $e')),
      );
    }
  }

  Future<void> _launchWithExternalGPU(DesktopEntry entry) async {
    await _launchEntry(entry, useExternalGPU: true);
  }

  /// Monitor a process and unregister it from the dock when it exits
  void _monitorProcess(int pid, String appName) {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        // Check if process still exists
        final procFile = File('/proc/$pid/stat');
        if (!await procFile.exists()) {
          // Process has exited, unregister from dock
          try {
            await _dockService.unregisterRunningApp(pid);
          } catch (e) {
            debugPrint('Failed to unregister $appName from dock: $e');
          }
          // Remove from running apps in launcher
          if (mounted) {
            setState(() {
              _runningAppNames.remove(appName);
            });
          }
          return;
        }

        // Process still running, check again later
        _monitorProcess(pid, appName);
      } catch (e) {
        // Process likely doesn't exist, unregister
        try {
          await _dockService.unregisterRunningApp(pid);
        } catch (e2) {
          debugPrint('Failed to unregister $appName from dock: $e2');
        }
        // Remove from running apps in launcher
        if (mounted) {
          setState(() {
            _runningAppNames.remove(appName);
          });
        }
      }
    });
  }

  Future<void> _uninstallApp(DesktopEntry entry) async {
    final password = await showPasswordDialog(context);
    if (password == null || password.isEmpty) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Uninstalling application...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final manager = await _pkgService.detectPackageManager();
      if (manager == null) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not detect package manager')),
        );
        return;
      }

      final packageName = await _pkgService.findPackageName(entry.name);
      if (packageName == null || packageName.isEmpty) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not determine package name for ${entry.name}'),
          ),
        );
        return;
      }

      final uninstallCmd = await _pkgService.buildUninstallCmd(
        manager,
        packageName,
      );
      if (uninstallCmd == null) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unsupported package manager')),
        );
        return;
      }

      final process = await Process.start(
        uninstallCmd[0],
        uninstallCmd.sublist(1),
        mode: ProcessStartMode.normal,
      );
      process.stdin.writeln(password);
      await process.stdin.close();

      final exitCode = await process.exitCode;
      final stderrOut = await process.stderr
          .transform(const SystemEncoding().decoder)
          .join();

      if (!mounted) return;
      Navigator.of(context).pop();

      if (exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uninstalled ${entry.name}'),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshApps();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to uninstall ${entry.name}: ${stderrOut.isNotEmpty ? stderrOut : 'Uninstallation failed'}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uninstalling ${entry.name}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _createDesktopShortcut(DesktopEntry entry) async {
    try {
      await _shortcutService.createDesktopShortcut(
        appName: entry.name,
        exec: entry.exec,
        iconPath: entry.iconPath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Desktop shortcut created for ${entry.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create desktop shortcut: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _pickBackgroundImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        return result.files.single.path;
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
    return null;
  }

  Future<String?> _pickIconThemeDirectory() async {
    try {
      // Use getDirectoryPath to allow picking a folder containing themed icons
      final dir = await FilePicker.platform.getDirectoryPath();
      return dir;
    } catch (e) {
      debugPrint('Error picking icon theme directory: $e');
    }
    return null;
  }

  void _showSettingsDialog() {
    Color tempColor = _backgroundColor;
    double tempOpacity = _opacity;
    String? tempBackgroundImage = _backgroundImagePath;
    String? tempIconTheme = _iconThemePath;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: _GlassDialogShell(
            width: 540,
            title: 'Launcher Settings',
            onClose: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GlassSection(
                      title: 'Background appearance',
                      subtitle:
                          'Blend the launcher with your desktop using color, opacity, and wallpaper.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Color presets',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 8,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 1,
                                ),
                            itemCount: _presetColors.length,
                            itemBuilder: (context, index) {
                              final color = _presetColors[index];
                              final isSelected = tempColor == color;
                              return GestureDetector(
                                onTap: () =>
                                    setDialogState(() => tempColor = color),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.45),
                                        blurRadius: isSelected ? 12 : 6,
                                        spreadRadius: isSelected ? 2 : 0,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 20,
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _GlassButton(
                            icon: Icons.colorize,
                            label: 'Custom color',
                            onPressed: () async {
                              final picked = await showDialog<Color>(
                                context: context,
                                builder: (c) => CustomColorPickerDialog(
                                  initialColor: tempColor,
                                ),
                              );
                              if (picked != null) {
                                setDialogState(() => tempColor = picked);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Transparency',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: Colors.blueAccent,
                                    inactiveTrackColor: Colors.white24,
                                    trackHeight: 4,
                                    thumbColor: Colors.blueAccent,
                                    overlayColor: Colors.blueAccent.withOpacity(
                                      0.2,
                                    ),
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 8,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 16,
                                    ),
                                  ),
                                  child: Slider(
                                    value: tempOpacity,
                                    min: 0.0,
                                    max: 1.0,
                                    divisions: 100,
                                    onChanged: (value) => setDialogState(
                                      () => tempOpacity = value,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: Colors.white.withOpacity(0.08),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.14),
                                  ),
                                ),
                                child: Text(
                                  '${(tempOpacity * 100).round()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Wallpaper',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _GlassButton(
                                  icon: Icons.image_outlined,
                                  label: 'Select image',
                                  onPressed: () async {
                                    final imagePath =
                                        await _pickBackgroundImage();
                                    if (imagePath != null) {
                                      setDialogState(
                                        () => tempBackgroundImage = imagePath,
                                      );
                                    }
                                  },
                                ),
                              ),
                              if (tempBackgroundImage != null) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _GlassButton(
                                    icon: Icons.delete_outline,
                                    label: 'Remove wallpaper',
                                    onPressed: () => setDialogState(
                                      () => tempBackgroundImage = null,
                                    ),
                                    destructive: true,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (tempBackgroundImage != null) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: SizedBox(
                                height: 140,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(
                                      File(tempBackgroundImage!),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                color: Colors.black54,
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.broken_image_outlined,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                    ),
                                    BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 10,
                                        sigmaY: 10,
                                      ),
                                      child: Container(
                                        color: tempColor.withOpacity(
                                          tempOpacity,
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'Wallpaper preview',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _GlassSection(
                      title: 'Icon theme',
                      subtitle:
                          'Select a folder containing themed icons to restyle your apps.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _GlassButton(
                                  icon: Icons.folder_open_outlined,
                                  label: 'Select icon theme directory',
                                  onPressed: () async {
                                    final dir = await _pickIconThemeDirectory();
                                    if (dir != null) {
                                      setDialogState(() => tempIconTheme = dir);
                                    }
                                  },
                                ),
                              ),
                              if (tempIconTheme != null) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _GlassButton(
                                    icon: Icons.clear_outlined,
                                    label: 'Clear selection',
                                    onPressed: () => setDialogState(
                                      () => tempIconTheme = null,
                                    ),
                                    destructive: true,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.white.withOpacity(0.05),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: Text(
                              tempIconTheme ?? 'No icon theme selected',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: _GlassButton(
                            icon: Icons.close_rounded,
                            label: 'Cancel',
                            onPressed: () => Navigator.of(context).pop(),
                            accent: Colors.white70,
                            filled: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _GlassButton(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'Apply settings',
                            onPressed: () {
                              setState(() {
                                _backgroundColor = tempColor;
                                _opacity = tempOpacity;
                                _backgroundImagePath = tempBackgroundImage;
                                _iconThemePath = tempIconTheme;
                              });
                              _saveSettings();
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _executeShellCommand(String command) async {
    String? password;
    String commandToRun = command;

    if (_commandRequiresSudo(command)) {
      password = await showPasswordDialog(context);
      if (!mounted) return;
      if (password == null || password.trim().isEmpty) {
        _showSnackMessage('Command cancelled.');
        return;
      }
      commandToRun = _injectSudoStdinFlag(command);
      password = password.trim();
    }

    late final Process process;
    try {
      process = await Process.start('/bin/sh', ['-c', commandToRun]);
    } catch (e, st) {
      debugPrint('Failed to start command "$command": $e\n$st');
      _showSnackMessage(
        'Failed to start command: $e',
        backgroundColor: Colors.redAccent,
      );
      return;
    }

    if (password != null) {
      try {
        process.stdin.writeln(password);
        await process.stdin.flush();
      } catch (e, st) {
        debugPrint('Failed to send password to "$command": $e\n$st');
        _showSnackMessage(
          'Failed to submit password: $e',
          backgroundColor: Colors.redAccent,
        );
      }
    }

    await _showCommandConsole(command, process);
    _resetSearchField();
  }

  Future<void> _showCommandConsole(String command, Process process) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          _CommandConsoleDialog(command: command, process: process),
    );
  }

  Future<void> _evaluateMathExpression(String expression) async {
    try {
      final parser = Parser();
      final exp = parser.parse(expression);
      final contextModel = ContextModel()
        ..bindVariableName('pi', Number(math.pi))
        ..bindVariableName('e', Number(math.e));
      final value = exp.evaluate(EvaluationType.REAL, contextModel);

      if (!mounted) return;

      final formatted = _formatResultValue(value);
      await _showInfoDialog(
        title: 'Calculation Result',
        content: SizedBox(
          width: 360,
          child: SelectableText(
            '$expression\n= $formatted',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ),
      );
      _resetSearchField();
    } catch (e, st) {
      debugPrint('Failed to evaluate expression "$expression": $e\n$st');
      _showSnackMessage(
        'Could not evaluate expression.',
        backgroundColor: Colors.redAccent,
      );
    }
  }

  Future<void> _performFileSearch(String term) async {
    List<_SearchResult> results = [];
    try {
      await _runWithLoading('Searching files...', () async {
        results = await _searchFileSystem(term);
      });
    } catch (e, st) {
      debugPrint('File search failed for "$term": $e\n$st');
      _showSnackMessage(
        'File search failed: $e',
        backgroundColor: Colors.redAccent,
      );
      return;
    }

    if (!mounted) return;

    await _showFileResultsDialog(term, results);
    _resetSearchField();
  }

  Future<List<_SearchResult>> _searchFileSystem(String term) async {
    final query = term.toLowerCase();
    if (query.isEmpty) {
      return [];
    }

    final matches = <_SearchResult>[];
    final visited = <String>{};
    final queue = Queue<MapEntry<Directory, int>>();

    final homePath = Platform.environment['HOME'] ?? Directory.current.path;
    final roots = <String>{
      homePath,
      '$homePath/Desktop',
      '$homePath/.local/share/applications',
      '/usr/share/applications',
      '/usr/local/share/applications',
    };

    for (final path in roots) {
      final dir = Directory(path);
      if (await dir.exists() && visited.add(dir.path)) {
        queue.add(MapEntry(dir, 0));
      }
    }

    while (queue.isNotEmpty && matches.length < _fileSearchMaxResults) {
      final entry = queue.removeFirst();
      final dir = entry.key;
      final depth = entry.value;

      if (depth > _fileSearchMaxDepth) {
        continue;
      }

      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (matches.length >= _fileSearchMaxResults) break;
          final path = entity.path;
          final segments = path.split(Platform.pathSeparator);
          final name = segments.isNotEmpty ? segments.last : path;
          final lowerName = name.toLowerCase();

          final type = await _classifySearchEntity(entity, lowerName);

          if (lowerName.contains(query)) {
            matches.add(_SearchResult(path: path, name: name, type: type));
          }

          if (type == _SearchResultType.directory) {
            final shouldTraverse =
                depth < _fileSearchMaxDepth - 1 &&
                !lowerName.startsWith('.') &&
                !_fileSearchExcludedDirectoryNames.contains(lowerName);
            if (shouldTraverse) {
              final dirEntity = Directory(path);
              if (visited.add(dirEntity.path)) {
                queue.add(MapEntry(dirEntity, depth + 1));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Skipping directory ${dir.path}: $e');
      }
    }

    matches.sort((a, b) {
      final typeCompare = a.type.index.compareTo(b.type.index);
      if (typeCompare != 0) return typeCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return matches;
  }

  Future<_SearchResultType> _classifySearchEntity(
    FileSystemEntity entity,
    String lowerName,
  ) async {
    if (entity is Directory) return _SearchResultType.directory;
    if (_applicationExtensions.any(lowerName.endsWith)) {
      return _SearchResultType.application;
    }
    if (_archiveExtensions.any(lowerName.endsWith)) {
      return _SearchResultType.archive;
    }
    if (_imageExtensions.any(lowerName.endsWith)) {
      return _SearchResultType.image;
    }
    if (_videoExtensions.any(lowerName.endsWith)) {
      return _SearchResultType.video;
    }

    try {
      final stat = await entity.stat();
      if (stat.type == FileSystemEntityType.directory) {
        return _SearchResultType.directory;
      }
      final modeString = stat.modeString();
      if (modeString.contains('x')) {
        return _SearchResultType.application;
      }
    } catch (_) {}

    return _SearchResultType.other;
  }

  Future<void> _showFileResultsDialog(
    String term,
    List<_SearchResult> results,
  ) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1F252F),
        title: Text(
          'File search: ${term.isEmpty ? 'Unnamed query' : term}',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 520,
          child: results.isEmpty
              ? const Text(
                  'No files found.',
                  style: TextStyle(color: Colors.white70),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white24, height: 1),
                    itemBuilder: (_, index) {
                      final result = results[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _iconForSearchType(result.type),
                          color: _colorForSearchType(result.type),
                        ),
                        title: Text(
                          result.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${_labelForSearchType(result.type)} • ${result.path}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () async {
                          Navigator.of(dialogContext).pop();
                          await _openPath(result.path);
                        },
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPath(String targetPath) async {
    try {
      final file = File(targetPath);
      final directory = Directory(targetPath);
      if (!file.existsSync() && !directory.existsSync()) {
        _showSnackMessage(
          'File not found: $targetPath',
          backgroundColor: Colors.redAccent,
        );
        return;
      }
      final result = await Process.run('xdg-open', [targetPath]);
      if (result.exitCode != 0) {
        _showSnackMessage(
          'Unable to open file (exit code ${result.exitCode}).',
          backgroundColor: Colors.redAccent,
        );
      }
    } catch (e, st) {
      debugPrint('Failed to open path $targetPath: $e\n$st');
      _showSnackMessage(
        'Failed to open file: $e',
        backgroundColor: Colors.redAccent,
      );
    }
  }

  Future<void> _launchWebSearch(
    String url, {
    required String description,
  }) async {
    try {
      final result = await Process.run('xdg-open', [url]);
      if (result.exitCode != 0) {
        _showSnackMessage(
          'Failed to open $description search (exit code ${result.exitCode}).',
          backgroundColor: Colors.redAccent,
        );
      }
    } catch (e, st) {
      debugPrint('Failed to launch $description search ($url): $e\n$st');
      _showSnackMessage(
        'Failed to open $description search: $e',
        backgroundColor: Colors.redAccent,
      );
    }
  }

  Future<void> _runWithLoading(
    String message,
    Future<void> Function() action,
  ) async {
    if (!mounted) {
      await action();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1F252F),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );

    try {
      await action();
    } finally {
      if (mounted) {
        final navigator = Navigator.of(context, rootNavigator: true);
        if (navigator.canPop()) {
          navigator.pop();
        }
      }
    }
  }

  Future<void> _showInfoDialog({
    required String title,
    required Widget content,
    List<Widget>? actions,
  }) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1F252F),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: content,
        actions:
            actions ??
            [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
      ),
    );
  }

  String _formatResultValue(dynamic value) {
    if (value is num) {
      if (value is double) {
        if (value.isNaN || value.isInfinite) return value.toString();
        if ((value - value.round()).abs() < 1e-10) {
          return value.round().toString();
        }
        final formatted = value.toStringAsPrecision(10);
        return formatted.replaceFirst(RegExp(r'\.?0+$'), '');
      }
      return value.toString();
    }
    return value == null ? '' : value.toString();
  }

  void _showSnackMessage(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  void _resetSearchField() {
    if (!mounted) return;
    _searchController.clear();
    _filterApps('');
  }

  IconData _iconForSearchType(_SearchResultType type) {
    switch (type) {
      case _SearchResultType.directory:
        return Icons.folder;
      case _SearchResultType.application:
        return Icons.apps;
      case _SearchResultType.archive:
        return Icons.folder_zip;
      case _SearchResultType.image:
        return Icons.image;
      case _SearchResultType.video:
        return Icons.movie;
      case _SearchResultType.other:
        return Icons.insert_drive_file;
    }
  }

  Color _colorForSearchType(_SearchResultType type) {
    switch (type) {
      case _SearchResultType.directory:
        return Colors.amberAccent;
      case _SearchResultType.application:
        return Colors.lightBlueAccent;
      case _SearchResultType.archive:
        return Colors.deepOrangeAccent;
      case _SearchResultType.image:
        return Colors.pinkAccent;
      case _SearchResultType.video:
        return Colors.greenAccent;
      case _SearchResultType.other:
        return Colors.white70;
    }
  }

  String _labelForSearchType(_SearchResultType type) {
    switch (type) {
      case _SearchResultType.directory:
        return 'Folder';
      case _SearchResultType.application:
        return 'Application';
      case _SearchResultType.archive:
        return 'Archive';
      case _SearchResultType.image:
        return 'Image';
      case _SearchResultType.video:
        return 'Video';
      case _SearchResultType.other:
        return 'File';
    }
  }

  bool _commandRequiresSudo(String command) {
    final regex = RegExp(r'(^|\s)sudo(\s|$)');
    return regex.hasMatch(command);
  }

  String _injectSudoStdinFlag(String command) {
    if (command.contains('sudo -S')) {
      return command;
    }
    final regex = RegExp(r'\bsudo\b');
    return command.replaceFirstMapped(regex, (match) => 'sudo -S');
  }

  static final List<Color> _presetColors = [
    Colors.black,
    Colors.grey[900]!,
    Colors.grey[800]!,
    Colors.blue[900]!,
    Colors.purple[900]!,
    Colors.indigo[900]!,
    Colors.teal[900]!,
    Colors.green[900]!,
    Colors.orange[900]!,
    Colors.red[900]!,
    Colors.pink[900]!,
    Colors.amber[900]!,
    Colors.cyan[900]!,
    Colors.deepPurple[900]!,
    Colors.lime[900]!,
    Colors.brown[900]!,
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _dockService.dispose();
    _minimizeSub?.cancel();
    _restoreSub?.cancel();
    _dbusClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor.withOpacity(_opacity),
      body: Stack(
        children: [
          if (_backgroundImagePath != null)
            Positioned.fill(
              child: Image.file(
                File(_backgroundImagePath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          Positioned.fill(
            child: Container(color: _backgroundColor.withOpacity(_opacity)),
          ),
          Column(
            children: [
              Padding(
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
                        controller: _searchController,
                        onChanged: _filterApps,
                        onSubmitted: _handleSearchSubmit,
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
                          onPressed: _showSettingsDialog,
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
              ),
              // Workspace cards strip
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 200, // الارتفاع ثابت كما حددته
                      child: GlassmorphicContainer(
                        width: double.infinity,
                        height: 200,
                        borderRadius: 16,
                        linearGradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color.fromARGB(0, 0, 0, 0),
                            const Color.fromARGB(0, 0, 0, 0),
                          ],
                        ),
                        border: 1.2,
                        blur: 26,
                        borderGradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            // borderColor.withOpacity(0.1),
                            // borderColor.withOpacity(0.05),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _workspaces.isEmpty
                              ? const SizedBox.shrink()
                              : ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _workspaces.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 12),
                                  // --- (بداية التعديل) ---
                                  // تم إعادة كتابة الـ itemBuilder بالكامل
                                  itemBuilder: (context, idx) {
                                    final w = _workspaces[idx];
                                    final isHovered =
                                        _hoveredWorkspace == w.index;
                                    final isCurrent = w.isCurrent;

                                    // --- 1. تحديد الألوان بناءً على الحالة ---
                                    final Color baseColor;
                                    if (isCurrent) {
                                      // اللون النشط (أكثر سطوعاً)
                                      baseColor = Colors.white.withOpacity(
                                        0.16,
                                      );
                                    } else if (isHovered) {
                                      // اللون عند الحوم
                                      baseColor = Colors.white.withOpacity(
                                        0.12,
                                      );
                                    } else {
                                      // اللون الافتراضي (نفس بطاقات النظام)
                                      baseColor = Colors.white.withOpacity(
                                        0.08,
                                      );
                                    }

                                    // --- 2. تحديد لون الحدود ---
                                    final Color borderColor = isCurrent
                                        ? Colors.white.withOpacity(
                                            0.5,
                                          ) // إطار أبيض للنشط
                                        : Colors.transparent;

                                    return MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      onEnter: (_) => setState(
                                        () => _hoveredWorkspace = w.index,
                                      ),
                                      onExit: (_) => setState(
                                        () => _hoveredWorkspace = null,
                                      ),
                                      child: GestureDetector(
                                        onTap: () =>
                                            _switchToWorkspace(w.index),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          width:
                                              160, // <-- (مهم) عرض أصغر وأكثر أناقة
                                          decoration: BoxDecoration(
                                            color: baseColor,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ), // حواف دائرية
                                            border: Border.all(
                                              color: borderColor,
                                              width: 1.5,
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(14.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .desktop_windows_outlined, // أيقونة
                                                    color: Colors.white
                                                        .withOpacity(0.8),
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Workspace', // العنوان
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withOpacity(0.8),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              Text(
                                                w.name, // "Workspace 1" أو الاسم المخصص
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 20, // خط كبير وواضح
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  // --- (نهاية التعديل) ---
                                ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: SizedBox(
                      height: 200,
                      width: MediaQuery.of(context).size.width / 5,
                      child: BlocProvider<SystemStatsCubit>(
                        create: (_) =>
                            SystemStatsCubit(SystemStatsRepository()),
                        child: SystemStatsGrid(),
                      ),
                    ),
                  ),
                  // Control Center next to workspaces
                  SizedBox(height: 200, width: 800, child: ControlCenterPage()),
                ],
              ),

              // System stats grid below the search bar (provide its Cubit)
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : AppGrid(
                        apps: _filteredApps,
                        iconThemeDir: _iconThemePath,
                        runningAppNames: _runningAppNames,
                        onLaunch: _launchEntry,
                        onPin: (e) async {
                          try {
                            await _dockService.ensureClientConnection();
                            await _dockService.pinApp(e);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Pinned ${e.name} to dock'),
                              ),
                            );
                          } catch (err) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not pin ${e.name}: Make sure the VAXP Dock is running',
                                ),
                              ),
                            );
                          }
                        },
                        onInstall: _uninstallApp,
                        onCreateShortcut: _createDesktopShortcut,
                        onLaunchWithExternalGPU: _launchWithExternalGPU,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
