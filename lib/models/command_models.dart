enum ProcessState { idle, starting, running, completed, failed, cancelled }

class CommandDraft {
  const CommandDraft({
    required this.executable,
    required this.arguments,
    this.private = false,
  });

  final String executable;
  final List<String> arguments;
  final bool private;

  String get displayCommand {
    return ([executable, ...arguments]).map(quoteArgument).join(' ');
  }

  static String quoteArgument(String value) {
    if (value.isEmpty) return '""';
    if (!RegExp(r'''[\s"'\\]''').hasMatch(value)) return value;
    return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  }
}

class ProcessSession {
  const ProcessSession({
    required this.id,
    required this.command,
    required this.state,
    required this.startedAt,
    this.finishedAt,
    this.exitCode,
    this.stdout = '',
    this.stderr = '',
    this.error,
  });

  final String id;
  final CommandDraft command;
  final ProcessState state;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int? exitCode;
  final String stdout;
  final String stderr;
  final String? error;

  Duration get duration => (finishedAt ?? DateTime.now()).difference(startedAt);
}

enum ArgumentScope {
  global('Globalna'),
  input('Wejście'),
  output('Wyjście'),
  stream('Strumień');

  const ArgumentScope(this.label);
  final String label;
}

class ScopedArgument {
  const ScopedArgument({
    required this.scope,
    required this.option,
    this.value = '',
  });

  final ArgumentScope scope;
  final String option;
  final String value;
}
