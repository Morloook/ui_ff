class AppOptions {
  const AppOptions({
    required this.schemaVersion,
    required this.locale,
    required this.themeMode,
    required this.ffmpegPath,
    required this.ffprobePath,
    required this.autoScanOnStart,
    required this.catalogSearchLimit,
    required this.databaseOpenTimeoutSeconds,
    required this.databaseUseWorkerIsolateInDebug,
    required this.builderOptionSort,
    required this.builderMediaFilter,
    required this.terminalDefaultBinary,
    required this.terminalDefaultArguments,
    required this.warnBeforeOverwrite,
    required this.maxHistoryEntries,
    required this.inspectorShowEntries,
    required this.inspectorStreamSelector,
    required this.inspectorReadIntervals,
    required this.inspectorShowPackets,
    required this.inspectorShowFrames,
    required this.inspectorUseExifTool,
    required this.scriptsDirectoryPath,
    required this.queuePausedOnStart,
    required this.queueLiveLogCharacterLimit,
    required this.queueCompletedLogCharacterLimit,
  });

  final int schemaVersion;
  final String locale;
  final String themeMode;
  final String ffmpegPath;
  final String ffprobePath;
  final bool autoScanOnStart;
  final int catalogSearchLimit;
  final int databaseOpenTimeoutSeconds;
  final bool databaseUseWorkerIsolateInDebug;
  final String builderOptionSort;
  final String builderMediaFilter;
  final String terminalDefaultBinary;
  final List<String> terminalDefaultArguments;
  final bool warnBeforeOverwrite;
  final int maxHistoryEntries;
  final String inspectorShowEntries;
  final String inspectorStreamSelector;
  final String inspectorReadIntervals;
  final bool inspectorShowPackets;
  final bool inspectorShowFrames;
  final bool inspectorUseExifTool;
  final String scriptsDirectoryPath;
  final bool queuePausedOnStart;
  final int queueLiveLogCharacterLimit;
  final int queueCompletedLogCharacterLimit;

  factory AppOptions.fromJson(Map<String, dynamic> json) {
    final ui = _map(json, 'ui');
    final binaries = _map(json, 'binaries');
    final catalog = _map(json, 'catalog');
    final database = _map(json, 'database');
    final builder = _map(json, 'builder');
    final terminal = _map(json, 'terminal');
    final inspector = _map(json, 'inspector');
    final scripts = _map(json, 'scripts');
    final queue = _map(json, 'queue');
    final arguments = _list(terminal, 'defaultArguments');

    return AppOptions(
      schemaVersion: _integer(json, 'schemaVersion'),
      locale: _enumString(ui, 'locale', const {'pl', 'en'}),
      themeMode: _enumString(ui, 'themeMode', const {
        'system',
        'light',
        'dark',
      }),
      ffmpegPath: _string(binaries, 'ffmpegPath'),
      ffprobePath: _string(binaries, 'ffprobePath'),
      autoScanOnStart: _boolean(catalog, 'autoScanOnStart'),
      catalogSearchLimit: _positiveInteger(catalog, 'searchLimit'),
      databaseOpenTimeoutSeconds: _positiveInteger(
        database,
        'openTimeoutSeconds',
      ),
      databaseUseWorkerIsolateInDebug: _boolean(
        database,
        'useWorkerIsolateInDebug',
      ),
      builderOptionSort: _enumString(builder, 'optionSort', const {
        'nameAsc',
        'nameDesc',
        'mediaThenName',
      }),
      builderMediaFilter: _enumString(builder, 'mediaFilter', const {
        'all',
        'audio',
        'video',
        'subtitle',
        'data',
        'attachment',
        'unknown',
      }),
      terminalDefaultBinary: _enumString(terminal, 'defaultBinary', const {
        'ffmpeg',
        'ffprobe',
      }),
      terminalDefaultArguments: arguments
          .map((value) {
            if (value is! String) {
              throw const FormatException(
                'terminal.defaultArguments musi zawierać wyłącznie tekst.',
              );
            }
            return value;
          })
          .toList(growable: false),
      warnBeforeOverwrite: _boolean(terminal, 'warnBeforeOverwrite'),
      maxHistoryEntries: _positiveInteger(terminal, 'maxHistoryEntries'),
      inspectorShowEntries: _string(inspector, 'showEntries'),
      inspectorStreamSelector: _string(inspector, 'streamSelector'),
      inspectorReadIntervals: _string(inspector, 'readIntervals'),
      inspectorShowPackets: _boolean(inspector, 'showPackets'),
      inspectorShowFrames: _boolean(inspector, 'showFrames'),
      inspectorUseExifTool: _boolean(inspector, 'useExifTool'),
      scriptsDirectoryPath: _string(scripts, 'directoryPath'),
      queuePausedOnStart: _boolean(queue, 'pausedOnStart'),
      queueLiveLogCharacterLimit: _positiveInteger(
        queue,
        'liveLogCharacterLimit',
      ),
      queueCompletedLogCharacterLimit: _positiveInteger(
        queue,
        'completedLogCharacterLimit',
      ),
    );
  }

  static Map<String, dynamic> _map(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is! Map) {
      throw FormatException('Brak wymaganej sekcji ustawień: $key.');
    }
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<dynamic> _list(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is! List) {
      throw FormatException('Opcja $key musi być listą.');
    }
    return value;
  }

  static String _string(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is! String) {
      throw FormatException('Opcja $key musi być tekstem.');
    }
    return value;
  }

  static String _enumString(
    Map<String, dynamic> source,
    String key,
    Set<String> allowed,
  ) {
    final value = _string(source, key);
    if (!allowed.contains(value)) {
      throw FormatException(
        'Nieprawidłowa wartość $key: $value. Dozwolone: ${allowed.join(', ')}.',
      );
    }
    return value;
  }

  static bool _boolean(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is! bool) {
      throw FormatException('Opcja $key musi mieć wartość true albo false.');
    }
    return value;
  }

  static int _integer(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is! int) {
      throw FormatException('Opcja $key musi być liczbą całkowitą.');
    }
    return value;
  }

  static int _positiveInteger(Map<String, dynamic> source, String key) {
    final value = _integer(source, key);
    if (value <= 0) {
      throw FormatException('Opcja $key musi być większa od zera.');
    }
    return value;
  }
}
