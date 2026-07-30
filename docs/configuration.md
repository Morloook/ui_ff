# SSOT configuration

## Default values

`lib/core/app_config.dart` is the only source of default application options.
It is versioned and compiled with the application. Every option required at
startup belongs in `AppConfig.defaults`; `AppOptions` validates types, allowed
values, and completeness.

The same file contains the application name, displayed version, author, and
contact. Those metadata values are not user settings and are not written to
`options.json`.

FFmpeg and FFprobe options are not copied to the SSOT. They are read from local
binaries because availability depends on each installation's version and build
configuration.

`database` controls the SQLite open timeout and debug behavior. Debug uses a
SQLite factory without an extra isolate by default, so a debugger cannot pause a
worker during startup. Release builds use a worker isolate to keep large catalog
operations off the user interface thread.

`builder` stores the user's option sort order and media filter. The option list
is dynamic and comes from the detected FFmpeg help catalog.

`ui` stores theme and interface language. Valid languages are `en` and `pl`.
English is the default. Change the language in **Settings and information →
Interface language**; it takes effect immediately and is stored in
`options.json`.

`queue` keeps the queue paused by default. Adding a command never starts a
process automatically; the user starts it with **Start queue**. The section
also contains rendered-log limits. Full process output remains copyable even
when the view is limited.

Script-import forms exist only for the current session. Selected files,
metadata, quality values, filters, and manual corrections are not written to
`options.json`. The public project has no bundled personal workflows; users can
place compatible `.sh` files directly in `skrypty/` next to the running
executable. For AppImage, this is the `skrypty/` directory next to the
`.AppImage` file. In **Settings and information → Scripts directory**, the user
can select a different existing directory; its path is saved as a user override
in `options.json`. Restoring the default scripts directory clears the override
and returns to the adjacent `skrypty/` directory.

## User settings

User changes are stored in `options.json` in the operating system application
data directory. The exact path is displayed in settings.

The file contains only overrides, for example:

```json
{
  "ui": {
    "themeMode": "light",
    "locale": "pl"
  },
  "binaries": {
    "ffmpegPath": "/opt/ffmpeg/bin/ffmpeg"
  }
}
```

Terminal arguments are session-only and are not persisted. On startup the
application removes the legacy `terminal.defaultArguments` value if it remains
in an old user file. Default startup arguments still come from
`AppConfig.defaults`.

At startup the application:

1. loads and validates the SSOT;
2. loads `options.json` when it exists;
3. recursively overlays user settings;
4. keeps SSOT values for missing keys;
5. starts binary detection, the catalog, terminal, inspector, and queue with
   the resulting configuration.

If `options.json` is malformed, not a JSON object, or contains values that do
not match the model, the application saves it as
`options.invalid-<timestamp>.json`, writes an empty `{}`, and starts with SSOT
defaults. A bad built-in SSOT remains a startup error because it indicates an
application release problem rather than user data.

After confirmation, **Restore default settings** writes an empty object to
`options.json`. This removes all overrides, reloads SSOT values, redetects
binaries, and refreshes screens without deleting the capability catalog, jobs,
or user files.

---

## Wersja polska

## Wartości domyślne

Jedynym źródłem domyślnych opcji aplikacji jest:

`lib/core/app_config.dart`

Plik jest wersjonowany i kompilowany razem z aplikacją. Każda opcja wymagana
przy uruchomieniu musi znajdować się w mapie `AppConfig.defaults`. Model
`AppOptions` waliduje typy, dozwolone wartości i kompletność konfiguracji.
Ten sam plik przechowuje nazwę i aktualną wersję wyświetlaną przez program.
Metadane aplikacji nie są ustawieniami użytkownika i dlatego nie trafiają do
`options.json`.

Opcje udostępniane przez FFmpeg i FFprobe nie są kopiowane do SSOT. Program
odczytuje je z lokalnych binariów, ponieważ ich zestaw zależy od wersji i
konfiguracji konkretnej kompilacji.

Sekcja `database` określa limit czasu otwierania SQLite oraz zachowanie builda
debug. Domyślnie debug używa fabryki SQLite bez dodatkowego izolatu, aby
debugger nie mógł zatrzymać workera podczas startu. Build release zawsze
korzysta z izolatu roboczego, dzięki czemu większe operacje katalogu nie blokują
interfejsu.

Sekcja `builder` przechowuje wybrane przez użytkownika sortowanie oraz filtr
rodzaju mediów dla dynamicznej listy opcji kreatora. Sama lista nie jest
hardkodowana w SSOT — pochodzi z katalogu pomocy wykrytego lokalnego FFmpeg.

Sekcja `ui` przechowuje motyw oraz język interfejsu. Dostępne wartości języka
to `pl` i `en`. Zmiana w Ustawieniach jest stosowana natychmiast i zapisywana
w `options.json`; brak nadpisania oznacza użycie angielskiej wartości domyślnej z
`AppConfig.defaults`.

Sekcja `queue` domyślnie utrzymuje kolejkę w stanie oczekiwania. Dodanie
polecenia nigdy nie uruchamia procesu samo; użytkownik rozpoczyna wykonanie
przyciskiem **Uruchom kolejkę** na ekranie zadań. W tej sekcji znajdują się
również limity tekstu renderowanego jednocześnie dla aktywnego i zakończonego
logu. Pełne dane procesu pozostają dostępne do skopiowania niezależnie od
limitu widoku.

Formularze tworzone z plików `.sh` są stanem bieżącej sesji. Wybrane pliki,
tytuły, metadane, jakość, filtry oraz ręcznie poprawione propozycje nie są
zapisywane w `options.json`. Program przy starcie skanuje dołączony katalog
`skrypty/` obok programu albo katalog wybrany przez użytkownika na ekranie
**Ustawienia**.

## Ustawienia użytkownika

Zmiany użytkownika są zapisywane w `options.json` w systemowym katalogu danych
aplikacji. Dokładną ścieżkę pokazuje ekran **Ustawienia**.

Plik użytkownika zawiera tylko nadpisania, na przykład:

```json
{
  "ui": {
    "themeMode": "light"
  },
  "binaries": {
    "ffmpegPath": "/opt/ffmpeg/bin/ffmpeg"
  }
}
```

Treść argumentów terminala jest stanem bieżącej sesji i nie jest zapisywana w
`options.json`. Program usuwa również `terminal.defaultArguments`, jeśli taki
wpis pozostał w pliku utworzonym przez starszą wersję. Domyślne argumenty
startowe nadal pochodzą z `AppConfig.defaults`.

Podczas uruchomienia aplikacja:

1. wczytuje i waliduje SSOT;
2. wczytuje `options.json`, jeśli istnieje;
3. rekurencyjnie nakłada ustawienia użytkownika;
4. dla każdego brakującego klucza zachowuje wartość z SSOT;
5. uruchamia wykrywanie binariów, katalog, terminal, inspektor i kolejkę z
   wynikową konfiguracją.

Jeśli `options.json` ma uszkodzoną składnię, nie jest obiektem JSON albo zawiera
wartość niezgodną z modelem, program zachowuje jego kopię pod nazwą
`options.invalid-<czas>.json`, zapisuje czysty obiekt `{}` i uruchamia się z
wartościami z `AppConfig.defaults`. Po starcie interfejs pokazuje ostrzeżenie ze
ścieżką do zachowanej kopii. Błąd samego SSOT nadal zatrzymuje start, ponieważ
oznacza błąd wersji aplikacji, a nie ustawień użytkownika.

Przycisk **Przywróć ustawienia domyślne** na ekranie ustawień, po potwierdzeniu,
zapisuje w `options.json` pusty obiekt. Usuwa to wszystkie nadpisania
użytkownika, więc program ponownie pobiera cały wynikowy zestaw wartości z
`AppConfig.defaults`, wykrywa binaria i odświeża ekrany. Reset nie usuwa
katalogu możliwości, zadań ani plików użytkownika.
