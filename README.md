# FFmpeg UI

A Flutter desktop interface for locally installed `ffmpeg` and `ffprobe`.
It detects the capabilities of the exact local build and presents them in a
searchable catalog instead of assuming that every computer has the same codecs,
filters, formats, protocols, or hardware acceleration.

> Official project release: `1.0.1`.

Polish documentation is available in [README.pl.md](README.pl.md), and the
Polish changelog is [docs/changelog.pl.md](docs/changelog.pl.md). The
application interface can also be switched to Polish in Settings.

## Features

- FFmpeg and FFprobe path, version, and build-configuration diagnostics;
- local SQLite catalog of options, codecs, filters, formats, devices,
  protocols, and hardware acceleration;
- lazy loading of detailed component help;
- FFprobe media inspector with streams, metadata, and raw JSON;
- expert terminal that runs only FFmpeg or FFprobe without a system shell;
- command builder that preserves FFmpeg global, input, and output option order;
- import of user-provided `.sh` workflows into editable forms and a preview;
- manually started job queue with multi-step workflows;
- SSOT defaults with separate JSON user overrides.

## Requirements

### Running the distributed application

- 64-bit Linux (`x86_64`) with a graphical desktop session;
- FUSE support for normal AppImage mounting; if it is unavailable, run the
  package with `APPIMAGE_EXTRACT_AND_RUN=1 ./FFmpeg_UI-x86_64.AppImage`;
- FFmpeg and FFprobe in `PATH`, or paths selected manually in the application.

FFmpeg binaries are not included. ExifTool is optional and enables extended
metadata reading and editing. Personal workflow scripts are optional.

### Building from source

- Flutter 3.44 or newer;
- FFmpeg and FFprobe in `PATH`, or paths selected manually in the application;
- Linux or Windows.

## Interface language

The interface starts in English. Open **Settings and information**, choose
**Interface language**, and select **Polish** to switch to Polish. The choice
is applied immediately and remembered in the user settings file.

## Run from source

```bash
flutter pub get
flutter run -d linux
```

VS Code provides Linux and Windows debug and release launch configurations.
Run Windows configurations on Windows.

```bash
flutter build linux
```

```powershell
flutter build windows
```

## Distribution builds

```bash
tools/build-appimage.sh
```

The public AppImage build requires `linuxdeploy`, which collects eligible
application libraries, and `squashfs-tools` for final package verification.
It creates one file in `export/`:
`FFmpeg_UI-<architecture>.AppImage`, validates its SquashFS payload, and
includes AppStream metadata. Use `tools/build-appimage.sh --dev` only for a
local `appimagetool` package; that mode does not collect additional system
libraries. When installed, `appstreamcli` validates the metadata before the
build; its absence only skips that additional check.

```bat
tools\build-windows-exe.bat
```

The Windows script creates a complete release bundle in
`export/FFmpeg_UI-Windows`; the executable needs the adjacent DLLs and `data`
directory.

Personal workflow scripts are intentionally not part of this repository.
The application works without bundled scripts. Create a `skrypty` directory
next to `ffmpeg_ui`, `ffmpeg_ui.exe`, or `FFmpeg_UI-x86_64.AppImage` and place
your direct `.sh` workflow files there. The Scripts screen reads them at startup
and when **Refresh scripts** is selected. A different existing directory can be
selected in **Settings and information → Scripts directory**; restoring the
default returns to the adjacent `skrypty` directory.

The supported import contract is intentionally narrow: one script must contain
one direct `ffmpeg` invocation, with simple assignments and optional `read`
prompts. Bash loops, conditionals, functions, pipes, redirections, shell
substitutions, or calls to other programs (including `ffprobe`) are not
interpreted or executed. A more complex file can be reported as partially
recognized, but it is outside the guaranteed import format.

## Verify changes

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
dart run tools/catalog_diagnostics.dart
```

See [installation and distribution](docs/installation.md), the
[project map](docs/project_map.md), [configuration](docs/configuration.md),
and the [GitHub publication checklist](docs/github_publication.md).

## Contributing and reporting

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Use the
GitHub issue forms for repeatable bugs and feature proposals. Report security
issues privately according to [SECURITY.md](SECURITY.md), not in a public
issue. Community expectations are described in
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Author and contact

Author: **Morl / Morloook** — [https://github.com/Morloook](https://github.com/Morloook)

Contact: [git@vms.net.pl](mailto:git@vms.net.pl)

If you use this project's code, a voluntary message to the address above is
appreciated. It is not an additional license condition.

## License

This project is licensed under [MIT](LICENSE). Preserve the copyright and
license notice in copies or substantial portions of the code.

## Security design

Processes are started as an executable and an argument list with
`runInShell: false`. Text entered in the terminal is never passed to bash,
PowerShell, or `cmd.exe`. Private terminal sessions are not persisted.
