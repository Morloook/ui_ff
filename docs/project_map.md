# Project map

## Overview

FFmpeg UI is a Flutter desktop application for Linux and Windows. It discovers
local `ffmpeg` and `ffprobe` capabilities, builds a searchable catalog, inspects
media files, builds commands, imports user workflows, and runs queued jobs.

`lib/core/app_config.dart` is the single source of truth for built-in defaults,
application metadata, and the default English interface language. Users can
switch the interface to Polish from **Settings and information → Interface
language**; the choice is stored in their local `options.json` file.

The developer's local `skrypty/` directory is private, ignored, and absent from
the public repository. Each user can create their own external `skrypty/`
directory next to the distributed application executable. The public
`docs/changelog.md` records versioned change history.

## Public source tree

```text
ui_ff/
├── .github/                # CI workflow, issue forms, and PR template.
├── .vscode/                # Shared VS Code launch configurations.
├── assets/icons/           # Application icons.
├── docs/                   # English public documentation.
├── export/                 # Ignored generated distribution artifacts.
├── img/                    # Versioned image assets.
├── lib/                    # Dart and Flutter source code.
│   ├── core/               # SSOT, controller, and logging.
│   ├── l10n/               # English and Polish localization support.
│   ├── models/             # UI-independent data models.
│   ├── services/           # Processes, parsing, SQLite, settings, and jobs.
│   ├── ui/                 # Application shell, dialogs, screens, and UI widgets.
│   └── widgets/            # Shared UI widgets.
├── linux/                  # Native Linux runner and CMake setup.
├── packaging/              # AppImage desktop metadata and entry point.
├── sfx/                    # Versioned audio assets.
├── test/                   # Automated service and widget tests.
├── tool/                   # Developer diagnostics.
├── tools/                  # Build and Git utility scripts.
└── windows/                # Native Windows runner and CMake setup.
```

Generated `build/`, `.dart_tool/`, `.idea/`, platform `ephemeral/` folders and
private `skrypty/` are not public source files.

## Runtime flow

1. `main.dart` starts the native window and `AppController`.
2. `SettingsService` loads defaults from `AppConfig.defaults`, overlays local
   `options.json`, and validates the resulting `AppOptions`.
3. `BinaryService` discovers FFmpeg and FFprobe, records version and build
   configuration, and creates a capability fingerprint.
4. `CapabilityService` uses SQLite through `CapabilityRepository`; a missing or
   invalid snapshot triggers a new scan of help and component lists.
5. UI screens use the dynamic catalog, safely run FFprobe/FFmpeg, and show jobs
   through `ProcessService` and `JobQueueService`.
6. All processes receive an executable and an argument list with
   `runInShell: false`.

## Automatic script discovery

The Scripts screen reads only direct `.sh` files from a `skrypty/` directory
next to the running application. It scans the directory on application startup;
the **Refresh scripts** button scans it again without restarting.

In **Settings and information → Scripts directory**, a user may select a
different existing directory. This choice is stored as a user override in
`options.json` and replaces the default discovery location. The restore button
clears that override and immediately returns discovery to `skrypty/` next to
the executable.

- In a Linux or Windows Flutter bundle, the directory is next to
  `ffmpeg_ui` or `ffmpeg_ui.exe`.
- In an AppImage installation, create `skrypty/` next to
  `FFmpeg_UI-x86_64.AppImage`. `AppRun` passes this external directory to the
  application, so scripts are never read from the AppImage's read-only mount.
- The guaranteed import format is one direct `ffmpeg` invocation with supported
  variable assignments and `read` prompts. It does not execute the shell script
  or interpret loops, conditionals, functions, pipes, redirections, shell
  substitutions, or other programs, including `ffprobe`. The resulting form and
  final FFmpeg arguments stay editable before they are queued.

For example, save the following as `skrypty/example_h264.sh` beside the
application:

```bash
#!/usr/bin/env bash
QUALITY="21"
read -p "Input video: " INPUT_FILE
read -p "Output file: " OUTPUT_FILE
ffmpeg -hide_banner -i "$INPUT_FILE" -c:v libx264 -crf "$QUALITY" "$OUTPUT_FILE"
```

At the next startup or after refresh, the application exposes `QUALITY`,
`INPUT_FILE`, `OUTPUT_FILE`, and `-hide_banner` as editable controls. The
example is parsed into a safe FFmpeg argument list; Bash itself is not started.

## File responsibilities

### Repository and GitHub files

- `.gitattributes` — normalizes line endings and identifies binary assets.
- `.gitignore` — ignores generated outputs, local settings, databases, secrets,
  private media, and personal scripts.
- `.vscode/launch.json` — Linux and Windows debug/release launch entries.
- `.github/workflows/linux-ci.yml` — formats, analyzes, tests, and builds Linux
  on pushes, pull requests, and manual runs.
- `.github/ISSUE_TEMPLATE/bug_report.yml` — structured bug report form.
- `.github/ISSUE_TEMPLATE/feature_request.yml` — structured feature proposal
  form.
- `.github/ISSUE_TEMPLATE/config.yml` — disables blank issues.
- `.github/pull_request_template.md` — PR verification and documentation
  checklist.
- `README.md` — public project overview, language switching instructions,
  build commands, contribution links, author, contact, and license.
- `README.pl.md` — Polish public overview and Polish quick-start guidance.
- `CONTRIBUTING.md` — development, testing, documentation, and privacy rules.
- `SECURITY.md` — private vulnerability reporting procedure.
- `CODE_OF_CONDUCT.md` — collaboration and enforcement expectations.
- `LICENSE` — MIT license and copyright notice.
- `analysis_options.yaml` — Dart analyzer configuration.
- `pubspec.yaml` — package name, version, SDK constraints, dependencies, and
  Flutter configuration.
- `pubspec.lock` — locked dependency versions.
- `ui_ff.code-workspace` — portable VS Code workspace definition.

### Assets and public documentation

- `assets/icons/ffmpeg_ui.svg` — AppImage and desktop icon.
- `docs/installation.md` — Linux and Windows installation and distribution guide.
- `docs/configuration.md` — SSOT and user-settings behavior.
- `docs/changelog.md` — versioned public change history.
- `docs/project_map.md` — this public source map.
- `docs/project_plan.md` — product scope, architecture, and acceptance criteria.
- `docs/github_publication.md` — first-push and GitHub release checklist.
- `export/.gitkeep`, `img/.gitkeep`, and `sfx/.gitkeep` — preserve otherwise
  empty versioned directories.

### Application entry point and core

- `lib/main.dart` — Flutter entry point, native window setup, themes,
  localization, startup state, error state, and graceful shutdown.
- `lib/core/app_config.dart` — application name, version, author, contact, and
  all built-in default options.
- `lib/core/app_controller.dart` — service construction and application startup,
  settings, binary discovery, scanning, search, scripts, and command handoff.
- `lib/core/app_logger.dart` — structured debug logging; inactive in release.

### Localization and models

- `lib/l10n/app_localizations.dart` — Polish source text, English translations,
  supported locales, and dynamic text translation.
- `lib/l10n/localized_text.dart` — shared localized `Text` widget that leaves
  technical data and FFmpeg output unchanged.
- `lib/models/app_options.dart` — typed, validated effective configuration.
- `lib/models/binary_installation.dart` — binary kind and detected installation
  details.
- `lib/models/capability.dart` — capability categories, media types, option
  definitions, snapshots, and scan progress.
- `lib/models/command_models.dart` — command drafts, process state/results, and
  command-builder option scopes.
- `lib/models/filter_complex.dart` — editable filter-graph draft and validation
  result model.
- `lib/models/probe_result.dart` — merged FFprobe and optional ExifTool result.
- `lib/models/script_models.dart` — parsed user workflow, fields, commands, and
  warnings.
- `lib/models/workflow_models.dart` — ordered multi-step queue workflow.

### Services

- `lib/services/binary_service.dart` — PATH lookup, `-version` checks, and
  installation fingerprints.
- `lib/services/capability_repository.dart` — SQLite schema, FTS5 search with
  fallback, snapshots, raw scans, and debug/release database opening.
- `lib/services/capability_service.dart` — capability scan commands, persistence,
  and lazy detailed help.
- `lib/services/command_builder_service.dart` — ordered FFmpeg inputs, outputs,
  and arguments.
- `lib/services/filter_complex_service.dart` — raw `filter_complex` chain and
  stream-label validation.
- `lib/services/ffmpeg_progress_service.dart` — structured `-progress pipe:1`
  argument preparation and incremental FFmpeg progress parsing.
- `lib/services/help_parser.dart` — FFmpeg help, AVOption, enum, and component
  parsing with raw fallback.
- `lib/services/job_queue_service.dart` — manually started sequential queue,
  pause, cancel, retry, steps, structured FFmpeg progress from stdout, and live
  logs.
- `lib/services/probe_service.dart` — safe FFprobe arguments, optional ExifTool,
  JSON decoding, and metadata writes with a backup.
- `lib/services/process_service.dart` — shell-free process execution, stream
  separation, stdin, cancellation, shutdown, and argument lexing.
- `lib/services/script_import_service.dart` — discovers only `.sh` files in
  `skrypty/` next to the executable and parses supported assignments, prompts,
  variables, and FFmpeg calls.
- `lib/services/script_workflow_service.dart` — workflow autofill, editable
  values, and shell-variable-free command preparation.
- `lib/services/settings_service.dart` — SSOT overlay, user override storage,
  invalid JSON backup, and defaults recovery.

### User interface

- `lib/ui/app_shell.dart` — navigation rail, version, startup-recovery notice,
  screen selection, and builder-to-terminal handoff.
- `lib/ui/dialogs/scripts_help_dialog.dart` — script-import help, supported
  constructs, limitations, and a copyable example.
- `lib/ui/dialogs/workflow_command_editor_dialog.dart` — final editable workflow
  arguments with quote validation and executable protection.
- `lib/ui/screens/environment_screen.dart` — binary diagnostics and capability
  scan controls.
- `lib/ui/screens/catalog_screen.dart` — capability search, filters, details,
  and raw help.
- `lib/ui/screens/inspector_screen.dart` — file selection, FFprobe/ExifTool
  options, metadata view/editing, and JSON export.
- `lib/ui/screens/terminal_screen.dart` — expert arguments, process streams,
  stdin, stop control, overwrite warning, and session-only history.
- `lib/ui/screens/builder_screen.dart` — global/input/output forms, dynamic
  option picker, editable raw `filter_complex` graph with validation, path
  clearing, preview, and queue insertion.
- `lib/ui/screens/scripts_screen.dart` — shared scripts-directory setting,
  adjacent-directory workflow discovery, editable forms, source preview,
  validation, and queue insertion.
- `lib/ui/screens/jobs_screen.dart` — queue controls, active console, completed
  reports, and full-log copy.
- `lib/ui/screens/settings_screen.dart` — theme, language selection, user JSON,
  defaults reset, shared scripts-directory setting, catalog details, version,
  author, contact, and licenses.
- `lib/ui/widgets/scripts_directory_editor.dart` — shared editable scripts
  directory field, directory picker, validation, save, and default reset.
- `lib/widgets/page_header.dart` — shared page title, subtitle, and actions.

### Tests

```text
test/
├── app_options_test.dart                   # SSOT and user-settings tests (7).
├── builder_screen_test.dart                # Builder UI and filter graph tests (3).
├── capability_repository_test.dart         # SQLite snapshot, search, and large catalog tests (4).
├── capability_service_test.dart            # Scan, cache, errors, and cancellation tests (3).
├── command_models_test.dart                # Arguments, filter graph, and process safety (6).
├── filter_complex_service_test.dart         # Filter graph validation tests (4).
├── ffmpeg_progress_service_test.dart        # Structured FFmpeg progress tests (4).
├── help_parser_test.dart                   # FFmpeg help parser tests (6).
├── help_parser_regression_fixture_test.dart # Captured-build parser regressions (3).
├── job_queue_service_test.dart             # Queue, logs, and FFmpeg progress tests (4).
├── jobs_screen_test.dart                   # Empty and runnable queue screen tests (2).
├── localization_test.dart                  # Translation and locale tests (2).
├── probe_service_integration_test.dart     # FFprobe/ExifTool integration (2).
├── process_service_test.dart                # Process streams, stdin, and failure handling (3).
├── screen_smoke_test.dart                   # Core screen render smoke test (1).
├── screen_interaction_test.dart             # Environment, catalog, and scripts interactions (5).
├── script_import_service_test.dart         # Default/selected-directory and generic script import (8).
├── scripts_help_dialog_test.dart           # Script help dialog (1).
├── terminal_screen_test.dart                # FFmpeg/FFprobe program selector (1).
└── workflow_command_editor_dialog_test.dart # Workflow editing (1).
```

Captured parser profiles are stored in `test/fixtures/help_parser/`. Each
profile contains source information and real excerpts of encoder, filter, and
AVOption help; additional complete captures are created by
`tools/capture-ffmpeg-help-fixture.sh`.

Total tests: **70**.

### Tools and packaging

- `tool/catalog_diagnostics.dart` — local FFmpeg parser diagnostic utility.
- `tools/build-appimage.sh` — validates, builds, and packages one AppImage;
  writes its ignored Linux build-version marker under `build/`; personal
  scripts are never embedded in the package.
- `tools/build-windows-exe.bat` — validates and builds the Windows release
  bundle, creates an empty adjacent `skrypty/` directory for user workflows,
  and writes its ignored build-version marker under `build/`.
- `tools/publish-final-main-release.sh` — validates clean committed sources,
  remote `main`, exactly one local commit beyond it, SSOT/build versions, and
  available export artifacts; rewrites the remote state plus that commit to one
  `main` commit, uses a force-with-lease push, then creates or updates the
  matching GitHub Release with Linux and/or Windows assets.
- `tools/capture-ffmpeg-help-fixture.sh` — captures full help and capability
  listings from a chosen FFmpeg binary for parser-regression fixtures.
- `tools/run-tests.sh` — runs every Flutter test discovered in `test/`, streams
  progress, and prints a final result, test-file count, and duration.
- `tools/git-polacz_comminty-root` — Bash Git-history squash helper.
- `tools/git-polacz_comminty-root.bat` — Windows Git-history squash helper.
- `packaging/AppRun` — AppImage entry point that starts `ffmpeg_ui` and directs
  script discovery to `skrypty/` next to the AppImage file.
- `packaging/ffmpeg-ui.desktop` — Linux desktop metadata for the application.

### Native runners

- `linux/.gitignore` — ignores generated Linux Flutter files.
- `linux/CMakeLists.txt` — Linux CMake project configuration.
- `linux/flutter/CMakeLists.txt` — Flutter library and plugin integration.
- `linux/flutter/generated_plugin_registrant.h` and `.cc` — Linux plugin
  registration declaration and implementation.
- `linux/flutter/generated_plugins.cmake` — Linux plugin build list.
- `linux/runner/CMakeLists.txt` — GTK runner target configuration.
- `linux/runner/main.cc` — Linux native process entry point.
- `linux/runner/my_application.h` and `.cc` — GTK application declaration and
  implementation hosting Flutter.
- `windows/.gitignore` — ignores generated Windows Flutter files.
- `windows/CMakeLists.txt` — Windows CMake project configuration.
- `windows/flutter/CMakeLists.txt` — Flutter Windows library and plugin setup.
- `windows/flutter/generated_plugin_registrant.h` and `.cc` — Windows plugin
  registration declaration and implementation.
- `windows/flutter/generated_plugins.cmake` — Windows plugin build list.
- `windows/runner/CMakeLists.txt` — Win32 runner, resource, and library setup.
- `windows/runner/Runner.rc` — executable version, product, description, and
  icon resources.
- `windows/runner/main.cpp` — Windows native entry point and COM/window setup.
- `windows/runner/flutter_window.h` and `.cpp` — Flutter view hosted by Win32.
- `windows/runner/resource.h` — resource identifiers for `Runner.rc`.
- `windows/runner/resources/app_icon.ico` — Windows executable icon.
- `windows/runner/runner.exe.manifest` — compatibility, DPI, and process
  permissions manifest.
- `windows/runner/utils.h` and `.cpp` — console and UTF-16/UTF-8 helpers.
- `windows/runner/win32_window.h` and `.cpp` — Win32 window, messages, DPI, and
  lifecycle implementation.

---

## Wersja polska

### Opis

FFmpeg UI to desktopowa aplikacja Flutter dla Linuxa i Windowsa. Wykrywa lokalne
programy `ffmpeg` i `ffprobe`, buduje katalog ich możliwości, analizuje pliki
multimedialne, tworzy polecenia oraz wykonuje zadania w kolejce.

Domyślne ustawienia pochodzą z `lib/core/app_config.dart`. Zmiany użytkownika
są zapisywane oddzielnie w systemowym pliku `options.json`.

### Działanie

1. Program łączy SSOT z `options.json`, waliduje ustawienia i wykrywa FFmpeg
   oraz FFprobe.
2. Katalog możliwości jest przechowywany lokalnie w SQLite i odnawiany po
   zmianie wykrytej instalacji.
3. Procesy otrzymują program wykonywalny i listę argumentów bez uruchamiania
   powłoki systemowej.
4. Skrypty `.sh` są czytane wyłącznie z `skrypty/` obok programu albo z
   katalogu wybranego przez użytkownika w Ustawieniach. AppImage korzysta z
   katalogu obok pliku `.AppImage`, a nie z jego wnętrza.
5. Importer nie wykonuje Basha: gwarantuje import jednego bezpośredniego
   wywołania `ffmpeg`, z obsługiwanymi zmiennymi i pytaniami `read`. Pętle,
   warunki, funkcje, potoki, przekierowania, podstawienia powłoki i inne
   programy, w tym `ffprobe`, są poza jego zakresem.

### Główne części projektu

- `lib/core/` — SSOT, kontroler aplikacji i logowanie.
- `lib/l10n/` — interfejs polski i angielski.
- `lib/models/` — modele niezależne od widoków.
- `lib/services/` — wykrywanie binariów, parsery, SQLite, ustawienia,
  procesy, inspektor, importer skryptów i kolejka.
- `lib/ui/` oraz `lib/widgets/` — ekrany, okna dialogowe i widgety.
- `test/` — 70 testów usług i interfejsu.
- `tools/` oraz `packaging/` — budowanie AppImage/Windows, publikacja Release
  oraz uruchamianie paczek.

Pełny, aktualny wykaz odpowiedzialności każdego pliku znajduje się w angielskiej
części tego dokumentu powyżej.
