/// Jedyne źródło domyślnych opcji uruchomieniowych aplikacji.
///
/// Ustawienia użytkownika z `options.json` są rekurencyjnie nakładane na tę
/// mapę. Każdy brakujący klucz użytkownika zachowuje wartość z tego pliku.
abstract final class AppConfig {
  /// Nazwa wyświetlana przez interfejs aplikacji.
  static const applicationName = 'FFmpeg UI';

  /// Aktualna wersja aplikacji wyświetlana użytkownikowi.
  ///
  /// Przy wydaniu nowej wersji wystarczy zmienić tę wartość. Numer techniczny
  /// paczki w `pubspec.yaml` powinien odpowiadać tej wersji.
  static const applicationVersion = '1.0';

  /// Autor projektu wyświetlany w informacjach o aplikacji.
  static const applicationAuthor = 'Morl / Morloook';

  /// Kontakt dotyczący projektu wyświetlany w informacjach o aplikacji.
  static const applicationContactEmail = 'git@vms.net.pl';

  /// Limity tekstu renderowanego jednocześnie w konsoli kolejki.
  ///
  /// Pełny log pozostaje dostępny do skopiowania. Limity chronią interfejs
  /// przed kosztownym budowaniem bardzo dużych widżetów tekstowych.
  static const queueLiveLogCharacterLimit = 24000;
  static const queueCompletedLogCharacterLimit = 120000;

  /// Pełny zestaw domyślnych ustawień zapisywalnych przez użytkownika.
  ///
  /// Opcje FFmpeg i FFprobe nie należą do tej mapy, ponieważ są wykrywane
  /// dynamicznie z lokalnie zainstalowanych binariów.
  static const defaults = <String, Object?>{
    // Wersja struktury pliku options.json, używana przy przyszłych migracjach.
    'schemaVersion': 1,

    // Ustawienia wyglądu i języka interfejsu.
    'ui': <String, Object?>{'locale': 'en', 'themeMode': 'system'},

    // Puste ścieżki oznaczają automatyczne wyszukiwanie w PATH.
    'binaries': <String, Object?>{'ffmpegPath': '', 'ffprobePath': ''},

    // Zachowanie lokalnego katalogu możliwości FFmpeg i FFprobe.
    'catalog': <String, Object?>{'autoScanOnStart': true, 'searchLimit': 500},

    // Sposób otwierania SQLite i zabezpieczenie przed nieskończonym startem.
    'database': <String, Object?>{
      'openTimeoutSeconds': 10,
      'useWorkerIsolateInDebug': false,
    },

    // Preferowany porządek i filtr dynamicznej listy opcji kreatora.
    'builder': <String, Object?>{'optionSort': 'nameAsc', 'mediaFilter': 'all'},

    // Stan początkowy i bezpieczeństwo terminala eksperta.
    'terminal': <String, Object?>{
      'defaultBinary': 'ffmpeg',
      'defaultArguments': <String>['-hide_banner', '-version'],
      'warnBeforeOverwrite': true,
      'maxHistoryEntries': 20,
    },

    // Stan początkowy zaawansowanych parametrów inspektora FFprobe.
    'inspector': <String, Object?>{
      'showEntries': '',
      'streamSelector': '',
      'readIntervals': '',
      'showPackets': false,
      'showFrames': false,
      'useExifTool': true,
    },

    // Pusta ścieżka oznacza katalog skrypty obok uruchomionego programu.
    'scripts': <String, Object?>{'directoryPath': ''},

    // Kolejka oczekuje na świadome uruchomienie przez użytkownika.
    'queue': <String, Object?>{
      'pausedOnStart': true,
      'liveLogCharacterLimit': queueLiveLogCharacterLimit,
      'completedLogCharacterLimit': queueCompletedLogCharacterLimit,
    },
  };
}
