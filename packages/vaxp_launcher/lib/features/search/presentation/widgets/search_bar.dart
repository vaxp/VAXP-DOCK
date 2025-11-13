import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:vaxp_launcher/features/search/application/search_cubit.dart';
import 'package:vaxp_launcher/features/search/application/search_state.dart';
import 'package:vaxp_launcher/features/search/presentation/widgets/search_dialogs.dart';
import 'package:vaxp_core/models/desktop_entry.dart';

import '../../../../widgets/password_dialog.dart';
import '../../domain/models/search_result.dart';

class SearchBar extends StatefulWidget {
  const SearchBar({
    super.key,
    required this.onFilterApps,
    required this.allAppsFuture,
    this.onSettingsPressed,
  });

  final void Function(String query) onFilterApps;
  final Future<List<DesktopEntry>> allAppsFuture;
  final VoidCallback? onSettingsPressed;

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchSubmit(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      widget.onFilterApps('');
      context.read<SearchCubit>().clearQuery();
      return;
    }
    if (_handleSpecialSearch(query)) {
      return;
    }
    widget.onFilterApps(query);
    context.read<SearchCubit>().updateQuery(query);
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

  Future<void> _executeShellCommand(String command) async {
    String? password;
    String commandToRun = command;

    if (commandRequiresSudo(command)) {
      password = await showPasswordDialog(context);
      if (!mounted) return;
      if (password == null || password.trim().isEmpty) {
        _showSnackMessage('Command cancelled.');
        return;
      }
      commandToRun = injectSudoStdinFlag(command);
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
      builder: (dialogContext) => CommandConsoleDialog(
        command: command,
        process: process,
      ),
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
      await showMathResultDialog(context, expression, formatted);
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
    final cubit = context.read<SearchCubit>();
    List<SearchResult> results = [];
    try {
      await _runWithLoading('Searching files...', () async {
        results = await cubit.performFileSearch(term);
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

    await showFileResultsDialog(context, term, results);
    _resetSearchField();
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

  Future<void> _launchWebSearch(
    String url, {
    required String description,
  }) async {
    try {
      final result = await Process.run('xdg-open', [url]);
      if (result.exitCode != 0 && mounted) {
        _showSnackMessage(
          'Failed to open $description search (exit code ${result.exitCode}).',
          backgroundColor: Colors.redAccent,
        );
      }
    } catch (e, st) {
      debugPrint('Failed to launch $description search ($url): $e\n$st');
      if (mounted) {
        _showSnackMessage(
          'Failed to open $description search: $e',
          backgroundColor: Colors.redAccent,
        );
      }
    }
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
    widget.onFilterApps('');
    context.read<SearchCubit>().clearQuery();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SearchCubit, SearchState>(
      listener: (context, state) {
        // Update search field when query changes externally
        if (state.query != _searchController.text) {
          _searchController.text = state.query;
        }
      },
      child: Row(
        children: [
          Expanded(
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
                    blurRadius: 10,
                    spreadRadius: -8,
                    offset: const Offset(-6, -6),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  widget.onFilterApps(value);
                  context.read<SearchCubit>().updateQuery(value);
                },
                onSubmitted: _handleSearchSubmit,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search applications...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                ),
                style: const TextStyle(color: Colors.white),
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
                onPressed: widget.onSettingsPressed,
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

