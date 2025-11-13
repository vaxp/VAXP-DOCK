import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vaxp_launcher/features/search/domain/models/search_result.dart';

class _ConsoleEntry {
  _ConsoleEntry(this.text, {this.isError = false});

  final String text;
  final bool isError;
}

class CommandConsoleDialog extends StatefulWidget {
  const CommandConsoleDialog({
    super.key,
    required this.command,
    required this.process,
  });

  final String command;
  final Process process;

  @override
  State<CommandConsoleDialog> createState() => _CommandConsoleDialogState();
}

class _CommandConsoleDialogState extends State<CommandConsoleDialog> {
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
    if (!_isDone) {
      widget.process.kill(ProcessSignal.sigterm);
      _appendOutput('\n[process terminated]\n', true);
    }
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
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
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

Future<void> showFileResultsDialog(
  BuildContext context,
  String term,
  List<SearchResult> results,
) async {
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
                        await _openPath(context, result.path);
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

Future<void> showMathResultDialog(
  BuildContext context,
  String expression,
  String result,
) async {
  await showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1F252F),
      title: const Text(
        'Calculation Result',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 360,
        child: SelectableText(
          '$expression\n= $result',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.6,
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

Future<void> _openPath(BuildContext context, String targetPath) async {
  try {
    final file = File(targetPath);
    final directory = Directory(targetPath);
    if (!file.existsSync() && !directory.existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File not found: $targetPath'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }
    final result = await Process.run('xdg-open', [targetPath]);
    if (result.exitCode != 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open file (exit code ${result.exitCode}).'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  } catch (e, st) {
    debugPrint('Failed to open path $targetPath: $e\n$st');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open file: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

IconData _iconForSearchType(SearchResultType type) {
  switch (type) {
    case SearchResultType.directory:
      return Icons.folder;
    case SearchResultType.application:
      return Icons.apps;
    case SearchResultType.archive:
      return Icons.folder_zip;
    case SearchResultType.image:
      return Icons.image;
    case SearchResultType.video:
      return Icons.movie;
    case SearchResultType.other:
      return Icons.insert_drive_file;
  }
}

Color _colorForSearchType(SearchResultType type) {
  switch (type) {
    case SearchResultType.directory:
      return Colors.blueAccent;
    case SearchResultType.application:
      return Colors.greenAccent;
    case SearchResultType.archive:
      return Colors.orangeAccent;
    case SearchResultType.image:
      return Colors.purpleAccent;
    case SearchResultType.video:
      return Colors.redAccent;
    case SearchResultType.other:
      return Colors.white70;
  }
}

String _labelForSearchType(SearchResultType type) {
  switch (type) {
    case SearchResultType.directory:
      return 'Folder';
    case SearchResultType.application:
      return 'Application';
    case SearchResultType.archive:
      return 'Archive';
    case SearchResultType.image:
      return 'Image';
    case SearchResultType.video:
      return 'Video';
    case SearchResultType.other:
      return 'File';
  }
}

bool commandRequiresSudo(String command) {
  final regex = RegExp(r'(^|\s)sudo(\s|$)');
  return regex.hasMatch(command);
}

String injectSudoStdinFlag(String command) {
  if (command.contains('sudo -S')) {
    return command;
  }
  final regex = RegExp(r'\bsudo\b');
  return command.replaceFirstMapped(regex, (match) => 'sudo -S');
}

