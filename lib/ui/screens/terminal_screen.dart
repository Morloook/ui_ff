import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../core/app_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/localized_text.dart';
import '../../models/binary_installation.dart';
import '../../models/command_models.dart';
import '../../services/process_service.dart';
import '../../widgets/page_header.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final TextEditingController _arguments;
  final _stdin = TextEditingController();
  final _stdout = StringBuffer();
  final _stderr = StringBuffer();
  final _history = <CommandDraft>[];
  late BinaryKind _kind;
  RunningCommand? _running;
  StreamSubscription<ProcessOutputEvent>? _outputSubscription;
  ProcessSession? _lastSession;
  bool _private = false;
  int _seenSeedVersion = 0;

  String get _combinedOutput {
    return [
      if (_stdout.isNotEmpty) '=== stdout ===\n$_stdout',
      if (_stderr.isNotEmpty) '=== stderr ===\n$_stderr',
    ].join('\n\n');
  }

  @override
  void initState() {
    super.initState();
    final options = widget.controller.options!;
    _arguments = TextEditingController(
      text: options.terminalDefaultArguments
          .map(CommandDraft.quoteArgument)
          .join(' '),
    );
    _kind = options.terminalDefaultBinary == BinaryKind.ffprobe.name
        ? BinaryKind.ffprobe
        : BinaryKind.ffmpeg;
    widget.controller.addListener(_controllerChanged);
  }

  void _controllerChanged() {
    if (_seenSeedVersion == widget.controller.terminalSeedVersion) return;
    _seenSeedVersion = widget.controller.terminalSeedVersion;
    _kind = widget.controller.terminalSeedKind;
    _arguments.text = widget.controller.terminalSeed;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerChanged);
    _outputSubscription?.cancel();
    _arguments.dispose();
    _stdin.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final installation = _kind == BinaryKind.ffmpeg
        ? widget.controller.ffmpeg
        : widget.controller.ffprobe;
    if (installation?.available != true) {
      _showMessage('${_kind.name} jest niedostępny.');
      return;
    }

    List<String> arguments;
    try {
      arguments = const ArgumentLexer().parse(_arguments.text);
    } on FormatException catch (error) {
      _showMessage(error.message);
      return;
    }
    if (widget.controller.options!.warnBeforeOverwrite &&
        await _requiresOverwriteConfirmation(arguments) &&
        mounted) {
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Możliwe nadpisanie pliku'),
              content: const Text(
                'Argumenty zawierają -y albo wskazują istniejący plik. '
                'FFmpeg może nadpisać dane. Kontynuować?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Anuluj'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Uruchom'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
    }

    final draft = CommandDraft(
      executable: installation!.path,
      arguments: arguments,
      private: _private,
    );
    _stdout.clear();
    _stderr.clear();
    _lastSession = null;
    setState(() {});
    try {
      final running = await widget.controller.processService.start(draft);
      if (!mounted) {
        running.cancel();
        return;
      }
      _running = running;
      _outputSubscription = running.output.listen((event) {
        (event.isStdErr ? _stderr : _stdout).write(event.text);
        if (mounted) setState(() {});
      });
      setState(() {});
      final session = await running.completed;
      await _outputSubscription?.cancel();
      if (!_private) {
        _history.insert(0, draft);
        final limit = widget.controller.options!.maxHistoryEntries;
        if (_history.length > limit) {
          _history.removeRange(limit, _history.length);
        }
      }
      if (!mounted) return;
      setState(() {
        _lastSession = session;
        _running = null;
      });
    } on Object catch (error) {
      _stderr.writeln('Nie można uruchomić procesu: $error');
      if (mounted) setState(() => _running = null);
    }
  }

  Future<bool> _requiresOverwriteConfirmation(List<String> arguments) async {
    if (arguments.contains('-y')) return true;
    if (arguments.isEmpty) return false;
    final candidate = arguments.last;
    if (candidate.startsWith('-')) return false;
    return File(candidate).existsSync();
  }

  void _showMessage(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final running = _running != null;
    return Column(
      children: [
        PageHeader(
          title: 'Terminal eksperta',
          subtitle:
              'Uruchamia wyłącznie lokalne ffmpeg lub ffprobe, bez powłoki systemowej.',
          actions: [
            if (running)
              FilledButton.tonalIcon(
                onPressed: () => _running?.cancel(),
                icon: const Icon(Icons.stop),
                label: const Text('Zatrzymaj'),
              )
            else
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Uruchom'),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<BinaryKind>(
                  initialValue: _kind,
                  decoration: InputDecoration(labelText: context.tr('Program')),
                  items: BinaryKind.values
                      .map(
                        (kind) => DropdownMenuItem(
                          value: kind,
                          child: Text(kind.name),
                        ),
                      )
                      .toList(),
                  onChanged: running
                      ? null
                      : (value) {
                          setState(() => _kind = value ?? _kind);
                          unawaited(
                            widget.controller.updateOption([
                              'terminal',
                              'defaultBinary',
                            ], _kind.name),
                          );
                        },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _arguments,
                  enabled: !running,
                  minLines: 2,
                  maxLines: 5,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: context.tr('Argumenty'),
                    hintText: '-hide_banner -i "plik ze spacją.mp4" …',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Checkbox(
                value: _private,
                onChanged: running
                    ? null
                    : (value) => setState(() => _private = value ?? false),
              ),
              const Text('Sesja prywatna — nie dodawaj do historii'),
              const Spacer(),
              if (_lastSession != null)
                Text(
                  'Kod: ${_lastSession!.exitCode ?? '—'} · '
                  '${_lastSession!.duration.inMilliseconds} ms',
                ),
              IconButton(
                onPressed: _stdout.isEmpty && _stderr.isEmpty
                    ? null
                    : () => Clipboard.setData(
                        ClipboardData(text: _combinedOutput),
                      ),
                tooltip: context.tr('Kopiuj log'),
                icon: const Icon(Icons.copy),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _stdout.clear();
                  _stderr.clear();
                }),
                tooltip: context.tr('Wyczyść log'),
                icon: const Icon(Icons.delete_sweep),
              ),
            ],
          ),
        ),
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xff111318),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: context.tr('Połączone')),
                      const Tab(text: 'stdout'),
                      const Tab(text: 'stderr'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _TerminalOutput(text: _combinedOutput),
                        _TerminalOutput(text: _stdout.toString()),
                        _TerminalOutput(text: _stderr.toString()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _stdin,
                  enabled: running,
                  onSubmitted: (_) => _sendStdin(),
                  decoration: InputDecoration(
                    labelText: 'stdin',
                    hintText: context.tr('Odpowiedź dla uruchomionego procesu'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: running ? _sendStdin : null,
                icon: const Icon(Icons.send),
                tooltip: context.tr('Wyślij'),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<CommandDraft>(
                enabled: _history.isNotEmpty && !running,
                tooltip: context.tr('Historia'),
                icon: const Icon(Icons.history),
                onSelected: (draft) {
                  _kind = draft.executable.contains('ffprobe')
                      ? BinaryKind.ffprobe
                      : BinaryKind.ffmpeg;
                  unawaited(
                    widget.controller.updateOption([
                      'terminal',
                      'defaultBinary',
                    ], _kind.name),
                  );
                  _arguments.text = draft.arguments
                      .map(CommandDraft.quoteArgument)
                      .join(' ');
                  setState(() {});
                },
                itemBuilder: (context) => _history
                    .take(20)
                    .map(
                      (draft) => PopupMenuItem(
                        value: draft,
                        child: SizedBox(
                          width: 500,
                          child: Text(
                            draft.displayCommand,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _sendStdin() {
    final value = _stdin.text;
    if (_running == null) return;
    _running!.writeLine(value);
    _stdin.clear();
  }
}

class _TerminalOutput extends StatelessWidget {
  const _TerminalOutput({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      reverse: true,
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        text.isEmpty ? 'Brak danych.' : text,
        style: const TextStyle(
          color: Color(0xffd7e2ef),
          fontFamily: 'monospace',
          height: 1.35,
        ),
      ),
    );
  }
}
