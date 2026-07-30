import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/app_logger.dart';
import '../models/command_models.dart';

class ProcessOutputEvent {
  const ProcessOutputEvent(this.isStdErr, this.text);
  final bool isStdErr;
  final String text;
}

class RunningCommand {
  RunningCommand({
    required this.id,
    required this.draft,
    required this.process,
    required this.startedAt,
    required this.output,
    required this.completed,
  });

  final String id;
  final CommandDraft draft;
  final Process process;
  final DateTime startedAt;
  final Stream<ProcessOutputEvent> output;
  final Future<ProcessSession> completed;

  void write(String value) => process.stdin.write(value);
  Future<void> writeLine(String value) async {
    process.stdin.writeln(value);
    await process.stdin.flush();
  }

  bool cancel() {
    AppLogger.info('Process', 'Żądanie zatrzymania procesu $id.');
    return process.kill();
  }
}

class ProcessService {
  int _sequence = 0;
  final Map<String, Process> _activeProcesses = {};
  bool _shuttingDown = false;

  Future<RunningCommand> start(CommandDraft draft) async {
    if (_shuttingDown) {
      throw StateError('Runner procesów jest już zamykany.');
    }
    final startedAt = DateTime.now();
    final id = '${startedAt.microsecondsSinceEpoch}-${_sequence++}';
    AppLogger.info(
      'Process',
      'Uruchamianie procesu $id: ${draft.executable}, '
          'argumentów=${draft.arguments.length}, prywatny=${draft.private}.',
    );
    late final Process process;
    try {
      process = await Process.start(
        draft.executable,
        draft.arguments,
        runInShell: false,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Process',
        'Nie można uruchomić procesu $id',
        error,
        stackTrace,
      );
      rethrow;
    }
    _activeProcesses[id] = process;
    final controller = StreamController<ProcessOutputEvent>.broadcast();
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    final stdoutDone = process.stdout.transform(utf8.decoder).listen((text) {
      stdoutBuffer.write(text);
      controller.add(ProcessOutputEvent(false, text));
    }).asFuture<void>();
    final stderrDone = process.stderr.transform(utf8.decoder).listen((text) {
      stderrBuffer.write(text);
      controller.add(ProcessOutputEvent(true, text));
    }).asFuture<void>();

    final completed = () async {
      try {
        final exitCode = await process.exitCode;
        await Future.wait([stdoutDone, stderrDone]);
        await controller.close();
        AppLogger.info(
          'Process',
          'Proces $id zakończony: kod=$exitCode, '
              'czas=${DateTime.now().difference(startedAt).inMilliseconds} ms.',
        );
        return ProcessSession(
          id: id,
          command: draft,
          state: exitCode == 0 ? ProcessState.completed : ProcessState.failed,
          startedAt: startedAt,
          finishedAt: DateTime.now(),
          exitCode: exitCode,
          stdout: stdoutBuffer.toString(),
          stderr: stderrBuffer.toString(),
        );
      } on Object catch (error) {
        await controller.close();
        AppLogger.error('Process', 'Błąd obsługi procesu $id', error);
        return ProcessSession(
          id: id,
          command: draft,
          state: ProcessState.failed,
          startedAt: startedAt,
          finishedAt: DateTime.now(),
          stdout: stdoutBuffer.toString(),
          stderr: stderrBuffer.toString(),
          error: error.toString(),
        );
      } finally {
        _activeProcesses.remove(id);
      }
    }();

    return RunningCommand(
      id: id,
      draft: draft,
      process: process,
      startedAt: startedAt,
      output: controller.stream,
      completed: completed,
    );
  }

  Future<ProcessSession> run(CommandDraft draft) async {
    final running = await start(draft);
    return running.completed;
  }

  Future<void> shutdown() async {
    if (_shuttingDown) return;
    _shuttingDown = true;
    final active = Map<String, Process>.from(_activeProcesses);
    AppLogger.info(
      'Process',
      'Zamykanie runnera procesów; aktywne=${active.length}.',
    );
    for (final entry in active.entries) {
      AppLogger.info('Process', 'Zatrzymywanie procesu ${entry.key}.');
      entry.value.kill();
    }
    await Future.wait(
      active.values.map(
        (process) => process.exitCode.timeout(
          const Duration(seconds: 3),
          onTimeout: () => -1,
        ),
      ),
    );
    _activeProcesses.clear();
    AppLogger.info('Process', 'Runner procesów został zamknięty.');
  }
}

class ArgumentLexer {
  const ArgumentLexer();

  List<String> parse(String source) {
    final arguments = <String>[];
    final buffer = StringBuffer();
    String? quote;
    var escaping = false;
    var tokenStarted = false;

    for (var index = 0; index < source.length; index++) {
      final character = source[index];
      if (escaping) {
        buffer.write(character);
        escaping = false;
        tokenStarted = true;
        continue;
      }
      if (character == r'\' && quote != "'") {
        escaping = true;
        tokenStarted = true;
        continue;
      }
      if (quote != null) {
        if (character == quote) {
          quote = null;
        } else {
          buffer.write(character);
        }
        tokenStarted = true;
        continue;
      }
      if (character == '"' || character == "'") {
        quote = character;
        tokenStarted = true;
        continue;
      }
      if (RegExp(r'\s').hasMatch(character)) {
        if (tokenStarted) {
          arguments.add(buffer.toString());
          buffer.clear();
          tokenStarted = false;
        }
        continue;
      }
      buffer.write(character);
      tokenStarted = true;
    }

    if (escaping) buffer.write(r'\');
    if (quote != null) {
      throw const FormatException('Niedomknięty cudzysłów w argumentach.');
    }
    if (tokenStarted) arguments.add(buffer.toString());
    return arguments;
  }
}
