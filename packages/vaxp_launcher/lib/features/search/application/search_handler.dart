import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/models/search_result.dart';
import '../presentation/widgets/search_dialogs.dart';
import '../application/search_cubit.dart';
import '../../../widgets/password_dialog.dart';

/// Service to handle special search commands and operations
class SearchHandler {
  final BuildContext context;
  final VoidCallback onResetSearch;

  SearchHandler({
    required this.context,
    required this.onResetSearch,
  });

  /// Main entry point for handling search submissions
  /// Returns true if the query was handled as a special command
  bool handleSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    return _handleSpecialSearch(trimmed);
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
        onResetSearch();
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
        onResetSearch();
      }
      return true;
    }
    return false;
  }

  Future<void> _executeShellCommand(String command) async {
    String? password;
    String commandToRun = command;

    if (_commandRequiresSudo(command)) {
      password = await showPasswordDialog(context);
      if (!context.mounted) return;
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
    onResetSearch();
  }

  bool _commandRequiresSudo(String command) {
    return command.trim().startsWith('sudo ') ||
        command.contains('sudo ') ||
        command.contains(' pkexec ') ||
        command.contains(' gksudo ');
  }

  String _injectSudoStdinFlag(String command) {
    if (command.contains('sudo -S')) return command;
    return command.replaceFirst(RegExp(r'\bsudo\b'), 'sudo -S');
  }

  Future<void> _showCommandConsole(String command, Process process) async {
    if (!context.mounted) return;
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

      if (!context.mounted) return;

      final formatted = _formatResultValue(value);
      await showMathResultDialog(context, expression, formatted);
      onResetSearch();
    } catch (e, st) {
      debugPrint('Failed to evaluate expression "$expression": $e\n$st');
      _showSnackMessage(
        'Could not evaluate expression.',
        backgroundColor: Colors.redAccent,
      );
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

  Future<void> _performFileSearch(String term) async {
    final searchCubit = context.read<SearchCubit>();
    List<SearchResult> results = [];
    try {
      await _runWithLoading('Searching files...', () async {
        results = await searchCubit.performFileSearch(term);
      });
    } catch (e, st) {
      debugPrint('File search failed for "$term": $e\n$st');
      _showSnackMessage(
        'File search failed: $e',
        backgroundColor: Colors.redAccent,
      );
      return;
    }

    if (!context.mounted) return;

    await showFileResultsDialog(context, term, results);
    onResetSearch();
  }

  Future<void> _runWithLoading(
    String message,
    Future<void> Function() action,
  ) async {
    if (!context.mounted) {
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
      if (context.mounted) {
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
      if (result.exitCode != 0 && context.mounted) {
        _showSnackMessage(
          'Failed to open $description search (exit code ${result.exitCode}).',
          backgroundColor: Colors.redAccent,
        );
      }
    } catch (e, st) {
      debugPrint('Failed to launch $description search ($url): $e\n$st');
      if (context.mounted) {
        _showSnackMessage(
          'Failed to open $description search: $e',
          backgroundColor: Colors.redAccent,
        );
      }
    }
  }

  void _showSnackMessage(String message, {Color? backgroundColor}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }
}

