import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/app_logger.dart';
import '../models/script_models.dart';
import 'process_service.dart';

class ScriptImportService {
  const ScriptImportService({this.executablePath, this.scriptsDirectoryPath});

  static const scriptsDirectoryEnvironment = 'FFUI_SCRIPTS_DIR';

  /// Test-only override for the executable whose adjacent scripts are scanned.
  final String? executablePath;

  /// Test-only override for the exact scripts directory.
  final String? scriptsDirectoryPath;

  /// The only directory from which workflow scripts are loaded.
  ///
  /// A normal desktop build uses `<executable parent>/skrypty`. AppRun sets
  /// [scriptsDirectoryEnvironment] for AppImage so that the directory is next
  /// to the AppImage file rather than inside its read-only mount.
  String expectedScriptsDirectory({String? configuredDirectory}) {
    final environmentDirectory = Platform
        .environment[scriptsDirectoryEnvironment]
        ?.trim();
    final configured = configuredDirectory?.trim();
    final path =
        scriptsDirectoryPath ??
        (configured?.isNotEmpty == true
            ? configured!
            : environmentDirectory?.isNotEmpty == true
            ? environmentDirectory!
            : p.join(
                File(executablePath ?? Platform.resolvedExecutable).parent.path,
                'skrypty',
              ));
    return p.normalize(path);
  }

  List<String> discoverDirectories({String? configuredDirectory}) {
    final directory = expectedScriptsDirectory(
      configuredDirectory: configuredDirectory,
    );
    return Directory(directory).existsSync() ? [directory] : const [];
  }

  Future<List<ImportedScript>> scan({String? configuredDirectory}) async {
    final scripts = <ImportedScript>[];
    final seen = <String>{};
    for (final directory in discoverDirectories(
      configuredDirectory: configuredDirectory,
    )) {
      await for (final entity in Directory(directory).list()) {
        if (entity is! File || !entity.path.toLowerCase().endsWith('.sh')) {
          continue;
        }
        final canonical = p.normalize(entity.absolute.path);
        if (!seen.add(canonical)) continue;
        try {
          scripts.add(parse(canonical, await entity.readAsString()));
        } on Object catch (error) {
          AppLogger.error('Scripts', 'Nie można odczytać $canonical', error);
          scripts.add(
            ImportedScript(
              path: canonical,
              name: p.basenameWithoutExtension(canonical),
              description: 'Nie udało się przeanalizować pliku.',
              source: '',
              fields: const [],
              commands: const [],
              warnings: ['Błąd odczytu lub analizy: $error'],
            ),
          );
        }
      }
    }
    scripts.sort((left, right) => left.name.compareTo(right.name));
    AppLogger.info('Scripts', 'Wykryto skryptów: ${scripts.length}.');
    return scripts;
  }

  ImportedScript parse(String path, String source) {
    final lines = source.split('\n');
    final defaults = _readDefaults(lines);
    final prompts = _readPrompts(lines);
    final parsedCommands = _readFfmpegCommands(lines);
    final generatedOptions = <String, _GeneratedOptionField>{};
    final commands = _parameterizeOptions(
      parsedCommands,
      defaults,
      generatedOptions,
    );
    final usedVariables = <String>{};
    for (final command in commands) {
      for (final argument in command.arguments) {
        usedVariables.addAll(_variablesIn(argument));
      }
    }
    final variables = <String>{
      ...usedVariables,
      ...prompts.keys.where((variable) => !_isConfirmation(variable)),
    }.toList()..sort();
    final fields = [
      for (final variable in variables)
        _fieldFor(
          variable,
          prompt: prompts[variable],
          initialValue: defaults[variable] ?? '',
          automatic: !prompts.containsKey(variable),
          required: usedVariables.contains(variable),
          generatedOption: generatedOptions[variable],
        ),
    ];
    final warnings = <String>[];
    if (commands.isEmpty) {
      warnings.add('Nie znaleziono żadnego wywołania ffmpeg.');
    }
    final unsafe = RegExp(
      r'(^|\s)(eval|curl|wget|rm|mv|cp|sudo|powershell|python[0-9]*)(\s|$)',
      multiLine: true,
    ).allMatches(source).map((match) => match.group(2)!).toSet();
    if (unsafe.isNotEmpty) {
      warnings.add(
        'Skrypt zawiera polecenia, których aplikacja nie wykona: '
        '${unsafe.join(', ')}.',
      );
    }
    if (source.contains(r'$(`') || source.contains('eval ')) {
      warnings.add('Wykryto dynamiczne tworzenie kodu powłoki.');
    }

    final titleMatch = RegExp(
      r'''^printf\s+['"]===\s*([^='"]+?)\s*===\\n''',
      multiLine: true,
    ).firstMatch(source);
    final name = titleMatch?.group(1)?.trim().isNotEmpty == true
        ? titleMatch!.group(1)!.trim()
        : _humanize(p.basenameWithoutExtension(path));
    return ImportedScript(
      path: path,
      name: name,
      description:
          '${commands.length} ${commands.length == 1 ? 'polecenie' : 'polecenia'} '
          'FFmpeg · ${fields.length} pól formularza',
      source: source,
      fields: fields,
      commands: commands,
      warnings: warnings,
    );
  }

  Map<String, String> _readDefaults(List<String> lines) {
    final result = <String, String>{};
    final assignment = RegExp(r'^([A-Z][A-Z0-9_]*)=(.+)$');
    for (final line in lines) {
      final match = assignment.firstMatch(line.trim());
      if (match == null) continue;
      final variable = match.group(1)!;
      var value = match.group(2)!.trim();
      if (value.startsWith('(') && value.endsWith(')')) {
        value = value.substring(1, value.length - 1);
      } else if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      if (value.contains(r'$') ||
          value.contains(r'`') ||
          value.contains(r'\')) {
        continue;
      }
      result.putIfAbsent(variable, () => value);
    }
    return result;
  }

  Map<String, String> _readPrompts(List<String> lines) {
    final result = <String, String>{};
    final promptPattern = RegExp(r'''-p\s+["']([^"']*)["']''');
    final variablePattern = RegExp(r'([A-Z][A-Z0-9_]*)\s*$');
    for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('read ')) continue;
      final variable = variablePattern.firstMatch(trimmed)?.group(1);
      if (variable == null) continue;
      result[variable] =
          promptPattern.firstMatch(trimmed)?.group(1)?.trim() ??
          _humanize(variable);
    }
    return result;
  }

  List<ScriptCommandTemplate> _readFfmpegCommands(List<String> lines) {
    final result = <ScriptCommandTemplate>[];
    for (var index = 0; index < lines.length; index++) {
      final trimmed = lines[index].trimLeft();
      if (!trimmed.startsWith('ffmpeg ')) continue;
      final startLine = index + 1;
      final buffer = StringBuffer();
      var current = lines[index].trim();
      while (true) {
        final continued = current.endsWith(r'\');
        buffer.write(
          continued ? current.substring(0, current.length - 1) : current,
        );
        buffer.write(' ');
        if (!continued || index + 1 >= lines.length) break;
        current = lines[++index].trim();
      }
      try {
        final tokens = const ArgumentLexer().parse(buffer.toString());
        if (tokens.isEmpty) continue;
        result.add(
          ScriptCommandTemplate(
            name: 'Etap ${result.length + 1}',
            executable: tokens.first,
            arguments: tokens.sublist(1),
            line: startLine,
          ),
        );
      } on FormatException catch (error) {
        AppLogger.warning(
          'Scripts',
          'Nie rozpoznano polecenia w linii $startLine: $error',
        );
      }
    }
    return result;
  }

  List<ScriptCommandTemplate> _parameterizeOptions(
    List<ScriptCommandTemplate> commands,
    Map<String, String> defaults,
    Map<String, _GeneratedOptionField> generatedOptions,
  ) {
    const variables = {
      '-crf': 'CRF',
      '-preset': 'ENCODING_PRESET',
      '-b:a': 'AUDIO_BITRATE',
      '-c:v': 'VIDEO_CODEC',
      '-c:a': 'AUDIO_CODEC',
      '-id3v2_version': 'ID3V2_VERSION',
      '-write_id3v1': 'WRITE_ID3V1',
      '-loglevel': 'LOG_LEVEL',
      '-stats_period': 'STATS_PERIOD',
    };
    final occurrences = <String, int>{};
    return [
      for (var commandIndex = 0; commandIndex < commands.length; commandIndex++)
        ScriptCommandTemplate(
          name: commands[commandIndex].name,
          executable: commands[commandIndex].executable,
          line: commands[commandIndex].line,
          arguments: () {
            final arguments = List<String>.from(
              commands[commandIndex].arguments,
            );
            for (var index = 0; index < arguments.length; index++) {
              final option = arguments[index];
              if (!_looksLikeOption(option)) continue;
              final mappedVariable = variables[option];
              final hasValue = _hasOptionValue(arguments, index);
              if (mappedVariable != null &&
                  hasValue &&
                  !arguments[index + 1].contains(r'$')) {
                defaults.putIfAbsent(
                  mappedVariable,
                  () => arguments[index + 1],
                );
                arguments[index + 1] = '\$$mappedVariable';
                index++;
                continue;
              }

              if (hasValue) {
                final value = arguments[index + 1];
                if (value.contains(r'$')) {
                  index++;
                  continue;
                }
                final variable = _generatedVariable(
                  commandIndex: commandIndex,
                  option: option,
                  occurrences: occurrences,
                  flag: false,
                );
                defaults[variable] = value;
                generatedOptions[variable] = _GeneratedOptionField(
                  label: 'Etap ${commandIndex + 1} · $option',
                );
                arguments[index + 1] = '\$$variable';
                index++;
                continue;
              }

              final variable = _generatedVariable(
                commandIndex: commandIndex,
                option: option,
                occurrences: occurrences,
                flag: true,
              );
              defaults[variable] = option;
              generatedOptions[variable] = _GeneratedOptionField(
                label: 'Etap ${commandIndex + 1} · $option',
                enabledValue: option,
              );
              arguments[index] = '\$$variable';
            }
            return arguments;
          }(),
        ),
    ];
  }

  Set<String> _variablesIn(String value) {
    final result = <String>{};
    final pattern = RegExp(
      r'\$(?:\{([A-Z][A-Z0-9_]*)(?:\[@\])?\}|([A-Z][A-Z0-9_]*))',
    );
    for (final match in pattern.allMatches(value)) {
      result.add(match.group(1) ?? match.group(2)!);
    }
    return result;
  }

  ScriptFieldDefinition _fieldFor(
    String variable, {
    required String? prompt,
    required String initialValue,
    required bool automatic,
    required bool required,
    _GeneratedOptionField? generatedOption,
  }) {
    final upperPrompt = (prompt ?? '').toUpperCase();
    final kind = switch (variable) {
      _ when generatedOption?.enabledValue != null => ScriptFieldKind.toggle,
      _ when variable.endsWith('_ARGS') => ScriptFieldKind.arguments,
      _ when variable.contains('OUTPUT') || variable == 'CLEAN_MP3' =>
        ScriptFieldKind.outputFile,
      _ when variable.endsWith('_FILE') => ScriptFieldKind.file,
      _
          when variable.endsWith('_ANSWER') ||
              variable.endsWith('_ENABLED') ||
              variable.contains('OVERWRITE') ||
              upperPrompt.contains('[T/N]') =>
        ScriptFieldKind.toggle,
      _
          when variable.contains('DURATION') ||
              variable.contains('PERCENT') ||
              variable == 'FPS' ||
              variable == 'CRF' =>
        ScriptFieldKind.number,
      _ => ScriptFieldKind.text,
    };
    return ScriptFieldDefinition(
      variable: variable,
      label:
          generatedOption?.label ??
          prompt?.replaceAll(RegExp(r'\s*\[[^]]+\]:?\s*$'), '') ??
          _humanize(variable),
      kind: kind,
      initialValue: initialValue,
      required:
          generatedOption?.enabledValue == null &&
          required &&
          !usedAsOptional(variable),
      help: generatedOption != null
          ? generatedOption.enabledValue != null
                ? 'Przełącznik odczytany bezpośrednio z polecenia FFmpeg.'
                : 'Wartość opcji odczytana bezpośrednio z polecenia FFmpeg.'
          : automatic
          ? 'Wartość wykrywana lub wyliczana automatycznie; można ją zmienić.'
          : 'Wartość wymagana przez pytanie w skrypcie.',
      automatic: automatic,
      enabledValue: generatedOption?.enabledValue,
    );
  }

  bool usedAsOptional(String variable) =>
      variable.endsWith('_ANSWER') || variable.endsWith('_ENABLED');

  bool _isConfirmation(String variable) =>
      variable == 'CONFIRM' ||
      variable == 'ANSWER' ||
      variable == 'OVERWRITE_ANSWER';

  bool _looksLikeOption(String value) =>
      value.length > 1 &&
      value.startsWith('-') &&
      !RegExp(r'^-\d+(?:[.,]\d+)?$').hasMatch(value);

  bool _hasOptionValue(List<String> arguments, int index) {
    if (index + 1 >= arguments.length) return false;
    final next = arguments[index + 1];
    if (!_looksLikeOption(next)) return true;
    return RegExp(r'^-\d+(?:[.,]\d+)?$').hasMatch(next);
  }

  String _generatedVariable({
    required int commandIndex,
    required String option,
    required Map<String, int> occurrences,
    required bool flag,
  }) {
    final normalized = option
        .replaceFirst(RegExp(r'^-+'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .toUpperCase();
    final key = '${commandIndex + 1}_$normalized';
    final occurrence = (occurrences[key] ?? 0) + 1;
    occurrences[key] = occurrence;
    return '${flag ? 'FFFLAG' : 'FFOPT'}_S${commandIndex + 1}_'
        '${normalized.isEmpty ? 'OPTION' : normalized}_$occurrence';
  }

  static String _humanize(String value) {
    final words = value.replaceAll('_', ' ').toLowerCase();
    return words.isEmpty
        ? value
        : '${words[0].toUpperCase()}${words.substring(1)}';
  }
}

class _GeneratedOptionField {
  const _GeneratedOptionField({required this.label, this.enabledValue});

  final String label;
  final String? enabledValue;
}
