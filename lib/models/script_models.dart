import 'workflow_models.dart';

enum ScriptFieldKind { text, number, file, outputFile, toggle, arguments }

class ScriptFieldDefinition {
  const ScriptFieldDefinition({
    required this.variable,
    required this.label,
    required this.kind,
    this.initialValue = '',
    this.required = true,
    this.help = '',
    this.automatic = false,
    this.enabledValue,
  });

  final String variable;
  final String label;
  final ScriptFieldKind kind;
  final String initialValue;
  final bool required;
  final String help;
  final bool automatic;

  /// Oryginalny argument FFmpeg włączany przez pole typu [ScriptFieldKind.toggle].
  ///
  /// Brak wartości oznacza zwykłe pole logiczne, które używa `true`/`false`.
  final String? enabledValue;
}

class ScriptCommandTemplate {
  const ScriptCommandTemplate({
    required this.name,
    required this.executable,
    required this.arguments,
    required this.line,
  });

  final String name;
  final String executable;
  final List<String> arguments;
  final int line;
}

class ImportedScript {
  const ImportedScript({
    required this.path,
    required this.name,
    required this.description,
    required this.source,
    required this.fields,
    required this.commands,
    required this.warnings,
  });

  final String path;
  final String name;
  final String description;
  final String source;
  final List<ScriptFieldDefinition> fields;
  final List<ScriptCommandTemplate> commands;
  final List<String> warnings;

  bool get canPrepare => commands.isNotEmpty;
}

class ScriptPreparation {
  const ScriptPreparation({
    required this.workflow,
    required this.unresolvedVariables,
    required this.errors,
  });

  final WorkflowDraft? workflow;
  final Set<String> unresolvedVariables;
  final List<String> errors;

  bool get isComplete =>
      workflow != null && unresolvedVariables.isEmpty && errors.isEmpty;
}
