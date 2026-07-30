# Contributing to FFmpeg UI

Thank you for contributing. For a larger change, open an issue first and
describe the intended behavior.

## Development environment

Flutter, Git, FFmpeg, and FFprobe are required. See
[installation and distribution](docs/installation.md) for system requirements.

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
```

Also run `flutter build linux --release` for Linux changes. Validate Windows on
Windows; a Linux build does not validate Windows integration.

The user interface defaults to English. It can be changed to Polish in
**Settings and information → Interface language**.

## Change rules

- Keep branches and pull requests small and focused.
- Keep models, services, and user interface code separated.
- Do not start FFmpeg or FFprobe through a shell. Pass the executable and every
  argument separately.
- Parsers must retain unrecognized raw data instead of silently discarding it.
- Default settings belong in `lib/core/app_config.dart`; do not hard-code user
  preferences in screens.
- Add tests appropriate to the changed behavior.
- Format Dart code with `dart format`.

## Documentation

`docs/project_map.md` describes the public source tree and file ownership.
Update it when structure or responsibilities change. `docs/changelog.md` is a
versioned public history of released and prepared changes.

## Do not commit

- `options.json`, local SQLite databases, or logs;
- keys, tokens, passwords, and `.env` files;
- private audio, video, image files, or their metadata;
- personal workflow scripts in `skrypty/`;
- `build/`, `.dart_tool/`, and artifacts in `export/`;
- local paths containing a user name.

Check `git status` and the full diff before opening a pull request.
