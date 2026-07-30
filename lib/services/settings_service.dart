import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/app_config.dart';
import '../core/app_logger.dart';
import '../models/app_options.dart';

class SettingsService {
  static const userFileName = 'options.json';

  SettingsService({
    Map<String, Object?> Function()? defaultsProvider,
    Future<Directory> Function()? supportDirectoryProvider,
  }) : _defaultsProvider = defaultsProvider ?? (() => AppConfig.defaults),
       _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory;

  final Map<String, Object?> Function() _defaultsProvider;
  final Future<Directory> Function() _supportDirectoryProvider;
  Map<String, dynamic> _defaults = const {};
  Map<String, dynamic> _overrides = {};
  Map<String, dynamic> _merged = const {};
  File? _userFile;
  String? recoveryNotice;

  AppOptions get options => AppOptions.fromJson(_merged);
  String get userFilePath => _userFile?.path ?? '';
  String get supportDirectoryPath => _userFile?.parent.path ?? '';
  Map<String, dynamic> get defaults => _deepCopy(_defaults);
  Map<String, dynamic> get userOverrides => _deepCopy(_overrides);

  Future<AppOptions> load() async {
    AppLogger.info('Settings', 'Wczytywanie domyślnej konfiguracji SSOT.');
    recoveryNotice = null;
    _defaults = _deepCopy(_defaultsProvider());
    AppOptions.fromJson(_defaults);

    final supportDirectory = await _supportDirectoryProvider();
    _userFile = File(p.join(supportDirectory.path, userFileName));
    if (await _userFile!.exists()) {
      AppLogger.info('Settings', 'Wczytywanie ustawień użytkownika.');
      var removedTransientValues = false;
      try {
        final userText = await _userFile!.readAsString();
        _overrides = userText.trim().isEmpty
            ? <String, dynamic>{}
            : _decodeObject(userText, _userFile!.path);
        removedTransientValues = _removeTransientOverrides();
        _rebuild();
      } on Object catch (error, stackTrace) {
        await _recoverInvalidUserFile(error, stackTrace);
        _overrides = <String, dynamic>{};
        _rebuild();
      }
      if (removedTransientValues && recoveryNotice == null) {
        try {
          await _writeOverrides();
        } on Object catch (error, stackTrace) {
          AppLogger.error(
            'Settings',
            'Nie można usunąć ustawienia sesyjnego z options.json',
            error,
            stackTrace,
          );
        }
      }
    } else {
      _overrides = <String, dynamic>{};
      AppLogger.info(
        'Settings',
        'Brak pliku użytkownika; używam wartości SSOT.',
      );
      _rebuild();
    }
    AppLogger.info('Settings', 'Konfiguracja wynikowa jest poprawna.');
    return options;
  }

  Future<AppOptions> setValue(List<String> path, Object? value) async {
    if (path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'Ścieżka nie może być pusta.');
    }
    _setOverride(_overrides, path, 0, value);
    _rebuild();
    await _writeOverrides();
    return options;
  }

  Future<AppOptions> replaceOverrides(Map<String, dynamic> overrides) async {
    _overrides = _deepCopy(overrides);
    _rebuild();
    await _writeOverrides();
    return options;
  }

  Future<AppOptions> restoreDefaults() {
    AppLogger.info(
      'Settings',
      'Przywracanie wszystkich ustawień domyślnych z SSOT.',
    );
    return replaceOverrides(const {});
  }

  Future<AppOptions> setSection(
    String section,
    Map<String, Object?> values,
  ) async {
    for (final entry in values.entries) {
      _setOverride(_overrides, [section, entry.key], 0, entry.value);
    }
    _rebuild();
    await _writeOverrides();
    return options;
  }

  void _rebuild() {
    _merged = mergeWithDefaults(_defaults, _overrides);
    AppOptions.fromJson(_merged);
  }

  Future<void> _writeOverrides() async {
    final file = _userFile;
    if (file == null) {
      throw StateError('Ustawienia nie zostały jeszcze wczytane.');
    }
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(_overrides)}\n', flush: true);
    AppLogger.info('Settings', 'Zapisano plik ustawień użytkownika.');
  }

  static Map<String, dynamic> mergeWithDefaults(
    Map<String, dynamic> defaults,
    Map<String, dynamic> overrides,
  ) {
    final result = _deepCopy(defaults);
    for (final entry in overrides.entries) {
      final defaultValue = result[entry.key];
      final overrideValue = entry.value;
      if (defaultValue is Map && overrideValue is Map) {
        result[entry.key] = mergeWithDefaults(
          defaultValue.map((key, value) => MapEntry(key.toString(), value)),
          overrideValue.map((key, value) => MapEntry(key.toString(), value)),
        );
      } else {
        result[entry.key] = overrideValue;
      }
    }
    return result;
  }

  static Map<String, dynamic> _decodeObject(String source, String label) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw FormatException('$label musi zawierać obiekt JSON.');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  static Map<String, dynamic> _deepCopy(Map source) {
    return source.map((key, value) {
      if (value is Map) {
        return MapEntry(key.toString(), _deepCopy(value));
      }
      if (value is List) {
        return MapEntry(
          key.toString(),
          value.map((item) => item is Map ? _deepCopy(item) : item).toList(),
        );
      }
      return MapEntry(key.toString(), value);
    });
  }

  static void _setOverride(
    Map<String, dynamic> target,
    List<String> path,
    int index,
    Object? value,
  ) {
    final key = path[index];
    if (index == path.length - 1) {
      target[key] = value;
      return;
    }
    final existing = target[key];
    final nested = existing is Map
        ? existing.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    target[key] = nested;
    _setOverride(nested, path, index + 1, value);
  }

  bool _removeTransientOverrides() {
    final terminalValue = _overrides['terminal'];
    if (terminalValue is! Map ||
        !terminalValue.containsKey('defaultArguments')) {
      return false;
    }
    final terminal = terminalValue.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    terminal.remove('defaultArguments');
    if (terminal.isEmpty) {
      _overrides.remove('terminal');
    } else {
      _overrides['terminal'] = terminal;
    }
    AppLogger.info(
      'Settings',
      'Usunięto zapamiętane argumenty terminala z options.json.',
    );
    return true;
  }

  Future<void> _recoverInvalidUserFile(
    Object error,
    StackTrace stackTrace,
  ) async {
    final file = _userFile!;
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final backupPath = p.join(
      file.parent.path,
      'options.invalid-$timestamp.json',
    );
    AppLogger.error(
      'Settings',
      'Plik options.json jest nieprawidłowy; używam SSOT',
      error,
      stackTrace,
    );
    try {
      await file.copy(backupPath);
      _overrides = <String, dynamic>{};
      await _writeOverrides();
      recoveryNotice =
          'Plik options.json był uszkodzony albo zawierał nieprawidłowe '
          'wartości. Program uruchomiono z ustawieniami domyślnymi. '
          'Kopia poprzedniego pliku: $backupPath';
      AppLogger.warning(
        'Settings',
        'Zachowano kopię nieprawidłowej konfiguracji i zapisano czysty JSON.',
      );
    } on Object catch (recoveryError, recoveryStackTrace) {
      recoveryNotice =
          'Nie można użyć ustawień z options.json. Program działa obecnie '
          'z ustawieniami domyślnymi, ale nie udało się zapisać kopii '
          'wadliwego pliku: $recoveryError';
      AppLogger.error(
        'Settings',
        'Nie udało się zachować wadliwej konfiguracji',
        recoveryError,
        recoveryStackTrace,
      );
    }
  }
}
