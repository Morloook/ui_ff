# Changelog

This document describes the history of changes in the FFmpeg UI application.
The English version intended for GitHub is available in
[changelog.md](changelog.md).

## Maintenance rules

- Each application version has its own section in the `MAJOR.MINOR.PATCH` format.
- A new version section is added at the beginning of the file; entries within it are
  divided into short thematic subsections.
- Separate sections or daily dates are not used. Changes waiting for release
  are described under the highest version currently being prepared.
- After the next version is released, earlier sections remain closed; corrections
  should be described in a new version without changing the release history.
- The changelog describes the effects and behavior of the application. The detailed
  division of file responsibilities remains exclusively in the project map.

## 1.0.1

### Application version

- The interface reads version `1.0.1` from `app_config.dart`, while the Flutter package
  has the matching technical version `1.0.1+2`.
- The Windows executable metadata fallback has version `1.0.1`, so it
  remains correct even outside the standard Flutter build.
- The project map now identifies the versioned screenshots used for public
  documentation and release presentation.

### AppImage packaging

- Public AppImage builds now require `linuxdeploy`, which collects eligible
  application libraries. The explicit `--dev` mode retains `appimagetool` only
  for local package checks.
- The build embeds validated AppStream metadata and verifies the completed
  AppImage SquashFS payload before reporting success.
- The installation documentation now separates end-user AppImage requirements
  from source-build requirements, including the FUSE-free launch command.

### Script import scope

- The documentation and the Scripts help window clearly define the guaranteed
  import format: one `.sh` file containing one direct invocation of
  `ffmpeg`, simple assignments, and optional `read` prompts.
- Loops, conditions, functions, pipelines, redirections, shell substitutions, and
  other programs, including `ffprobe`, are neither interpreted nor executed.
  A complex script may be partially recognized, but it is not part of the supported
  import contract.

### Scripts directory

- In Settings, the scripts directory now has its own clear section directly
  below the button for restoring default settings.
- The same editable directory selector is also available on the Scripts tab.
  The text field, directory selection button, and default-value restoration in
  both locations save only `scripts.directoryPath` in `options.json`.

### Interface localization

- English translations of descriptions, hints, and messages were completed on
  the Inspector, Builder, Scripts, and Settings screens.
- The scripts directory path label and the supporting script-field description now use
  the current localization context, so they refresh immediately after
  changing the language.
- The “About” section contains a clickable external link to the author's GitHub
  profile: `https://github.com/Morloook`.

### Tool organization

- The `tool/` and `tools/` directories were merged into a single `tools/` directory. FFmpeg
  catalog diagnostics are now run with
  `dart run tools/catalog_diagnostics.dart`.

### Reliability tests

- Help parser tests were expanded to cover preservation of unrecognized lines, value
  ranges, and detection of audio and video types from FFmpeg filter direction.
- Temporary SQLite tests were added for the capability catalog: a snapshot is not
  used before it is marked complete, components and options are correctly
  saved and read, and an old fingerprint of the same installation is
  replaced.
- Dedicated process runner tests were added for separating `stdout` and
  `stderr`, process error codes, live event streams, data passed through
  `stdin`, and attempts to start a nonexistent program.
- The catalog repository received optional data-directory and SQLite factory
  injection, so tests do not use the user's real database or
  application data.
- A rendering smoke test was added for the environment, catalog, terminal, and
  scripts screens before capability catalog initialization.
- Tests were added for a full `CapabilityService` scan, snapshot saving, cache
  reuse, a single-section failure, and scan cancellation. This also fixed
  a deadlock that could occur when closing the progress stream after
  scan cancellation.
- The queue screen verifies activation of the manual start button after adding
  a task, while interaction tests cover manual binary paths, searching
  and opening catalog entries, refreshing scripts, and selecting FFmpeg/FFprobe
  in the terminal.
- The localization test covers English hints on the Inspector, Builder,
  Scripts, and Settings screens.
- An interaction test confirms saving a manually entered catalog path through
  the Scripts tab.
- Two saved profiles of real FFmpeg 8.1.2 package revisions with
  available NVENC were added. Tests verify encoder and filter lists and the
  `h264_nvenc` options, including ranges, default values, and enums.
- A tool was added for saving the full profile of any FFmpeg binary
  (`-h full` and capability lists), so future builds—especially a stock
  build or Windows build—can be included as regression fixtures without changing the test mechanism.
- A queue integration test confirms passing progress arguments to the
  process and updating visible progress after receiving FFmpeg records.
- A large catalog test verifies substring search and the 25-result limit.

#### Detailed scope of automated validation

- SSOT configuration and user settings: default-value validation,
  JSON saving, recovery from a corrupted file, settings reset, and language selection.
- FFmpeg parser and catalog: ranges, default values, enums, media flags,
  unknown lines, profiles of real NVENC builds, SQLite, fingerprints,
  section errors, scan cancellation, and large-catalog search.
- Process execution: arguments containing spaces and Unicode, no shell,
  separation of `stdout`/`stderr`, `stdin` input, startup failure,
  stopping an active process, and correct service shutdown.
- Queue: manual start, workflow stage ordering, cancellation, live log,
  structured FFmpeg progress, and starting the next task only
  after the previous one finishes.
- Interface: screen smoke tests, manual binary paths, catalog and debounce,
  FFmpeg/FFprobe terminal, scripts, option and path builder, `filter_complex`,
  workflow editing, and the queue start button.
- Inspector and scripts: valid, corrupted, and unavailable files,
  FFprobe/ExifTool integration, safe `.sh` import, default or user-selected
  directory, and the scripts help window.

#### Running tests

- `tools/run-tests.sh` was added. It automatically passes the entire current
  test suite to Flutter, displays live progress, and prints the number of detected
  files, result, and execution time. Adding a new `*_test.dart` file does not
  require modifying the script.
- Full Flutter validation currently includes 71 passing tests.

### FFmpeg parser regressions

- Filter type detection was fixed for multiple inputs of the same type, for
  example `AA->A`; such a filter is now correctly cataloged as audio.

### FFmpeg task progress

- The task queue automatically adds `-progress pipe:1` and
  `-nostats` to FFmpeg commands, then reads `key=value` records from standard
  output. The expert terminal is not changed by this.
- The active task view shows structured data such as frame count,
  output time, and speed, independently of the `stderr` message format.
- The queue preserves custom `-progress`, `pipe:1`, and all non-FFmpeg
  commands unchanged, so it does not break deliberately configured user output.

### `filter_complex` foundation

- The command builder received a separate editor for a raw `filter_complex` expression.
  The graph is passed to FFmpeg as a single argument, while mapping its
  outputs deliberately remains editable through normal `-map` options.
- Basic filter-chain validation was added: quotes, label brackets,
  input references, and display of detected labels. An invalid graph cannot
  be added to the queue.
- This is a compatible text fallback for a future node editor; it does not
  attempt to restrict valid advanced FFmpeg expressions.
- The project map points to both the graph model and service and the raw-expression
  editor on the Builder screen.

### Catalog performance

- An FTS5 index with a trigram tokenizer was added for component names,
  descriptions, and flags. Substring search, for example `x264` in `libx264`, no longer
  requires scanning the entire table with a regular `LIKE`.
- When local SQLite does not provide FTS5, the application safely falls back to
  the previous `LIKE` query; the catalog remains available.
- The catalog screen rejects late results from an older query, still uses
  debounce and a lazily built list, and shows the user the result count and
  information when the limit has been reached.

## 1.0.0

### Version 1.0 release

- The official application version was set to `1.0`. The value displayed by
  the interface comes from `app_config.dart`, while the technical Flutter package
  version was set to the matching `1.0.0+1`.

### Application foundation

- A Flutter Desktop project for Linux and Windows was created.
- Main navigation and a Polish interface prepared for later
  localization were added.
- Data models, service logic, application state, and the interface layer were separated.
- Startup diagnostics and a readable error screen were added for cases where
  the application configuration is invalid.

### FFmpeg and capability catalog

- Automatic detection of local FFmpeg and FFprobe programs was added, along with
  the option to manually specify their paths.
- The application reads the version and build configuration of both tools.
- Dynamic scanning of locally available options, codecs, encoders, decoders, filters,
  formats, devices, protocols, and acceleration methods was added.
- The catalog can be searched and filtered by category and media type.
- Detailed component help is retrieved only after opening a component.
- Complete unrecognized help fragments are preserved as raw data.

### Catalog storage

- A local SQLite cache tied to the fingerprint of the FFmpeg/FFprobe pair was added.
- Updating the path, version, or configuration of either tool creates
  a new catalog.
- An interrupted or failed scan is not considered ready and will not be used
  on the next launch.
- Versioned database migrations were added.

### FFprobe Inspector

- File selection and drag-and-drop analysis were added.
- Results are presented as a summary, streams, metadata, and raw JSON.
- JSON export and advanced options for selecting entries, streams,
  intervals, packets, and frames were added.
- Inspector settings are remembered between launches.
- Optional integration with ExifTool detected through `PATH` was added.
  The inspector requests duplicate and unknown tags, embedded data, and additional
  `RequestAll` tags, then merges the result with FFprobe format, stream, and
  chapter metadata.
- ExifTool and FFprobe metadata are presented in separate grouped
  sections loaded only after expanding a group, which reduces the cost of
  rendering large results.
- The raw JSON tab and export now contain the merged FFprobe result,
  ExifTool status, any error, and all read tags.
- Missing ExifTool does not block FFprobe analysis; the metadata tab then shows
  installation instructions for the `perl-image-exiftool` package.
- A form for adding and overwriting a single metadata tag and
  edit buttons for supported groups were added. Before saving, the application informs
  the user that the file will be modified, passes the name and value as separate arguments
  without a shell, and reanalyzes the data after success.
- On the first change, ExifTool preserves the original file with the
  `_original` suffix. Later changes do not replace this first safety copy.

### Expert terminal

- A terminal was added that runs only FFmpeg or FFprobe without using the
  system shell.
- Support for paths with spaces, quotation marks, and Unicode characters was added.
- Separate stdout and stderr views and a combined view were added.
- stdin, process stopping, exit code, runtime, and
  log copying were added.
- A warning about possible file overwriting was added.
- Current-session history and a private mode that does not save
  the command to history were added.
- Terminal argument content is not saved between launches.
  An existing `terminal.defaultArguments` entry from an older `options.json` is
  automatically removed, while the FFmpeg or FFprobe selection remains
  a user setting.

### Builder, scripts, and queue

- A builder for multiple inputs and outputs was added while preserving the argument order
  required by FFmpeg.
- Options can be assigned to global, input, output, or
  stream scope.
- The generated command can be copied, transferred to the terminal, or added to
  the queue.
- A sequential queue with pause, stop, retry, and logs was added.
- Adding a command to the queue no longer starts the process. The Tasks screen received
  a separate `Start queue` button that runs pending tasks in order.
- Pausing an active queue allows the current task to finish but does not
  start the next one. Stopping the process also stops further
  queue execution.
- The Tasks screen permanently displays the current process console with the command,
  standard output, error output, and a stop button. Each
  task also has an unambiguous Polish description of its current state.
- The completed task view shows a report for every stage: the exact command,
  exit code, execution time, and separate `stdout` and
  `stderr/FFmpeg progress` sections. The full log can be copied with one button.
- The console preserves the order of messages received live. After completion,
  the report uses the complete process session result, even when a very
  short process printed data before the preview appeared. Carriage-return
  characters used by FFmpeg progress are converted into readable lines.
- For commands using `-loglevel error`, the report explains that missing information
  about input, mapping, and codecs results from the logging level selected in
  the script, not from a console error.
- Simplified preset cards that passed incomplete arguments with
  placeholders to the terminal were removed.
- A separate `Scripts` screen was added. On startup and after manual
  refresh, the application directly analyzes `.sh` files without additional manifests.
- The importer recognizes assignments, initial values, `read` prompts,
  variables, argument arrays, and one or more FFmpeg invocations. Detected
  prompts and unresolved values become form fields.
- The application automatically proposes titles, safe names, output paths,
  audio copy or encoding variants, and Shorts filters. Every proposal,
  as well as detected quality parameters, codecs, bitrate, and preset, remains
  editable and can be restored to its automatic value.
- The importer also exposes `LOG_LEVEL` and `STATS_PERIOD` as editable fields,
  allowing the user to keep the concise `error` log or choose
  a more detailed level, for example `info`.
- The importer also creates editable fields for other literal FFmpeg options.
  Valueless switches, including `-hide_banner`, `-stats`,
  and `-shortest`, can be disabled independently without leaving an empty argument.
- Before confirming that a workflow should be added to the queue, a separate window opens
  for manual final editing of each stage's argument list. The editor reparses
  arguments while respecting quotation marks, allows restoration of the result
  generated from the form, and does not allow changing the executable program.
- The imported task name comes from the script's main heading, not from
  a supporting heading placed inside a function.
- The form blocks adding to the queue until required files and variables are
  complete. Before adding, it shows the full arguments of all stages and asks
  for confirmation.
- Script form data is session-only and is never saved in
  `options.json`.
- The sole default script source is the `skrypty/` directory next to
  the running executable. The application no longer searches the
  working directory, application data directory, or private scripts included in
  the package.
- For AppImage, the `skrypty/` directory is located next to the `.AppImage` file, not
  inside its mounted read-only contents. Private scripts are not
  copied into the AppImage package; the Windows build creates an empty `skrypty/`
  directory next to the EXE file.
- Settings now allow selection of a different existing scripts directory. The selected
  path is saved as a user override, scanned immediately, and can
  be restored with one button to the default directory next to the application.
- Unrecognized or unsafe system commands are reported and are not
  executed. The queue receives only complete FFmpeg commands without
  launching Bash.
- The queue was extended with workflows containing multiple stages. All stages
  of one script form a single task, run sequentially, and share one
  log with an indication of the current step.
- The `Scripts` tab received a separate help window divided into an operation overview,
  supported constructs, importer limitations, and a complete `.sh` example.
  The example can be copied directly from the window.
- The argument-adding form was extended with a drop-down selector containing all
  options from the active local FFmpeg catalog. The list supports search by
  name, description, flags, and media type, sorting A–Z, Z–A, or by
  type, and filtering for audio, video, subtitles, data, and attachments.
- The selected item fills the editable option field and shows the original FFmpeg
  description, flags, value type, default value, range, and allowed values
  if recognized by the parser. A custom name and value can still be entered.
- Builder sorting and filtering are saved in `options.json`, while the list itself
  remains dynamic and depends on the detected FFmpeg build.
- Input and output path fields received a button that clears their entire
  entered content with one click.
- The visible screen name `Catalog` was changed to `Capabilities`, and its heading to
  `FFmpeg and FFprobe Capabilities`, making it clear that the screen shows
  options and components read from local programs.

### SSOT configuration

- A single source of default application options was introduced under the constant,
  easy-to-remember name `app_config.dart`.
- The application name and displayed version, currently set to
  `0.1`, were added to SSOT; the interface reads them directly from configuration instead of duplicating
  the version number.
- User changes are saved separately in `options.json`.
- The user file stores only values changed from the defaults.
- At startup, missing user settings are recursively filled with
  values from SSOT.
- Type, required-key, and allowed-value validation was added.
- Configuration covers theme, binary paths, automatic scanning, catalog, terminal,
  inspector, scripts directory, and initial queue state. An empty default
  `scripts.directoryPath` means the `skrypty/` directory next to the application.
- The Settings screen received a Polish and English language switch.
  The selected locale is saved as `ui.locale` in `options.json`, applied
  immediately without restart, and restored on the next launch.
- The default language for new installations and configurations after restoring defaults
  was changed from Polish to English. An existing user override still
  takes precedence.
- A central PL/EN localization layer was added for navigation, headings,
  buttons, forms, dialogs, importer help, queue, and
  basic messages. Original FFmpeg descriptions, arguments, file names, and
  process logs are not translated automatically.
- The version is visible in the main navigation, information screen, and
  license window.
- The default theme was set to follow the system theme; a selection previously saved
  by the user still takes precedence.
- A button for restoring all default settings with a confirmation
  dialog was added. Reset removes overrides from `options.json`, reapplies
  values from `app_config.dart`, refreshes binary detection, and rebuilds
  screens without deleting the capability catalog, tasks, or user files.
- A syntactically corrupted or model-incompatible `options.json` no longer blocks
  startup. The application copies it to `options.invalid-<time>.json`,
  replaces overrides with an empty object, starts with full SSOT values, and
  shows a warning with the path to the preserved copy. An invalid embedded
  SSOT is still treated as an application error and stops startup.

### Building and running

- A Linux release build and native Linux and Windows scaffolding were added.
- The AppImage build script automatically uses `linuxdeploy`, and when it is
  unavailable, uses the available `appimagetool`. Before packaging, it checks required
  files, clearly identifies the stage of any error, and always places the result in
  the `export` directory.
- The next run of the script removes earlier AppImage files from the
  export directory. A successful build leaves exactly one standalone file named
  `FFmpeg_UI-<architecture>.AppImage`, regardless of the application version number.
- A Windows script that builds the EXE and copies the complete bundle required
  to run it was added.
- An application icon and metadata for the Linux package were added.
- VS Code “Run and Debug” panel configurations for Linux and Windows were added,
  separately for debug and release modes.

### GitHub repository

- Automatic Linux validation was added for changes reaching the `main` branch
  and pull requests. The check includes formatting, analysis, and a release build.
- Bug report and feature request forms, a pull request template,
  contribution guidelines, a code of conduct, and instructions for
  privately reporting vulnerabilities were added.
- Ignored files were expanded to cover local user settings, SQLite databases,
  secrets, `.env` environments, coverage reports, and local packaging tools.
- Line-ending enforcement was added so Bash scripts retain LF format
  and BAT scripts retain CRLF format on all systems.
- Instructions were added for the first publication, branch protection, configuration
  of private security reports, and placing AppImage files in GitHub Releases
  without committing the artifact to history.
- The displayed application version was restored to the agreed value `0.1`, matching
  the technical package version `0.1.0`.
- The “About” information now lists the author `Morl / Morloook` and contact
  `git@vms.net.pl`.
- The MIT license, author and contact details in README, and an invitation to
  voluntarily report code usage by email were added. The contact email is
  also a fallback channel for privately reporting vulnerabilities and community
  issues.

### Documentation

- Public documentation file names were changed to English:
  `installation.md`, `configuration.md`, `project_map.md`,
  `project_plan.md`, and `github_publication.md`. Links in both
  README versions, contribution guidelines, and the project map were corrected.
- Public documentation keeps English text as the default version for
  GitHub, while every file in `docs/` received a parallel Polish section. A
  separate Polish `README.pl.md` file was also added; both README files link to
  the other language version. The private changelog remains Polish-only.
- Installation and distribution instructions for Linux and Windows were created.
- SSOT configuration and user settings file rules were described.
- A project map describing the structure, application operation, and
  responsibilities of all source files was created.
- The original work plan was preserved as a separate project document.

### Fixes

- The parser, which initially rejected valid encoder entries
  beginning with an audio or video flag, was fixed.
- Handling of global options without AVOption flags was fixed.
- Saving a large catalog was accelerated by batching SQLite operations.
- Cache invalidation was expanded to include both FFmpeg and
  FFprobe.
- File ignores were corrected so application assets can be versioned,
  while local media and artifacts remain outside the repository.

### Diagnostics and shutdown

- A common debug log format with time, level, and module name was added.
- Diagnostic messages were added for startup, configuration, binary detection,
  SQLite, catalog scanning, FFprobe, processes, and the queue.
- Command logging does not reveal the full argument list or the path of the
  analyzed file.
- Observation of the main window lifecycle, interception of native
  closing on Linux and Windows, and application detachment detection were added.
- During proper shutdown, scanning is canceled, active processes are stopped,
  and the SQLite database is closed.
- After shutdown begins, the runner does not accept new processes.
- A startup hang when launched through the VS Code debugger was diagnosed.
  The `quick_check` check confirmed a valid database and schema, while launching
  without the adapter opened the same file correctly. The cause was an additional
  `sqflite_common_ffi` isolate paused by `--start-paused`.
- The debug build now opens SQLite without an additional isolate, while the release
  build still performs database operations in a worker isolate. A configurable
  opening timeout was also added; when exceeded, the startup screen
  shows an error instead of remaining indefinitely on the loading animation.

### Verification

- Flutter static analysis completed without issues.
- Automatic Linux validation for the `main` branch and pull requests includes
  formatting, analysis, the full test suite, and a release build.
- The SSOT test verifies only the presence of a version, so manually changing
  the number in `app_config.dart` does not require modifying the test.
- The tests section in the project map was expanded with a file tree and short descriptions,
  the number of tests in each file, and the current total number of tests.
- Tests were added for the parser, arguments, process safety, command ordering,
  SSOT configuration, and settings fallback.
- An integration test using real FFprobe was added for a path containing a space and a Polish
  character.
- Linux debug and release versions were built and run.
- A full scan of local FFmpeg 8.1.2 and correct SQLite migrations were verified.
- Project validation currently includes 35 passing tests.
- A test for stopping an active process and blocking new starts after
  runner shutdown was added.
- A test confirming that reset saves an empty JSON object and restores
  SSOT values was added.
- A migration test removing remembered terminal arguments and a test
  of real metadata writing while preserving the `_original` copy were added.
- A test for recovering a corrupted `options.json`, preserving its
  original content in a copy, and launching with default SSOT values was added.
- A test for the builder selector widget, option description, and automatic
  filling of the argument field was added.
- A test for clearing the entire input path without affecting the output
  path was added.
- A test confirming that merely adding a task does not start the process
  and execution begins only after consciously starting the queue was added.
- Tests were added for importing general `.sh` files without a manifest, completeness of
  generated commands, and sequential execution of a multi-stage workflow.
- A test for the help window, its limitations, and a compliant script example was added.
- A test preserving `stdout` and `stderr` ordering in the console and a test
  selecting the script's main heading and editable log-detail settings were added.
- A test disabling a literal FFmpeg switch and a test for manual
  final-argument editing without the ability to change the executable were added.
- An English interface test and a test for saving and rereading
  the user's language from `options.json` were added.
- A test for detecting the `skrypty/` directory next to the executable, a test
  replacing it with a user-selected directory, and a test for saving and
  rereading that path from `options.json` were added.
