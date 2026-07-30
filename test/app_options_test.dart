import 'dart:io';

import 'dart:convert';

import 'package:ffmpeg_ui/core/app_config.dart';
import 'package:ffmpeg_ui/models/app_options.dart';
import 'package:ffmpeg_ui/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app_config.dart contains a complete and valid SSOT', () {
    final options = AppOptions.fromJson(
      Map<String, dynamic>.from(AppConfig.defaults),
    );

    expect(AppConfig.applicationName, 'FFmpeg UI');
    expect(AppConfig.applicationVersion, isNotEmpty);
    expect(AppConfig.applicationAuthor, isNotEmpty);
    expect(AppConfig.applicationContactEmail, contains('@'));
    expect(AppConfig.applicationGithubUrl, 'https://github.com/Morloook');
    expect(options.schemaVersion, greaterThan(0));
    expect(options.terminalDefaultArguments, isNotEmpty);
    expect(options.catalogSearchLimit, greaterThan(0));
    expect(options.databaseOpenTimeoutSeconds, greaterThan(0));
    expect(options.databaseUseWorkerIsolateInDebug, isFalse);
    expect(options.builderOptionSort, 'nameAsc');
    expect(options.builderMediaFilter, 'all');
    expect(options.queueLiveLogCharacterLimit, greaterThan(0));
    expect(options.queueCompletedLogCharacterLimit, greaterThan(0));
  });

  test('missing user values fall back recursively to SSOT defaults', () {
    final defaults = <String, dynamic>{
      'ui': {'themeMode': 'dark', 'locale': 'pl'},
      'catalog': {'autoScanOnStart': true, 'searchLimit': 500},
    };
    final user = <String, dynamic>{
      'ui': {'themeMode': 'light'},
    };

    final merged = SettingsService.mergeWithDefaults(defaults, user);

    expect(merged['ui']['themeMode'], 'light');
    expect(merged['ui']['locale'], 'pl');
    expect(merged['catalog']['searchLimit'], 500);
  });

  test('merge does not mutate the SSOT map', () {
    final defaults = <String, dynamic>{
      'ui': {'themeMode': 'dark'},
    };
    SettingsService.mergeWithDefaults(defaults, {
      'ui': {'themeMode': 'light'},
    });
    expect(defaults['ui']['themeMode'], 'dark');
  });

  test('writes only user overrides and restores them on next start', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ffmpeg_ui_options_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final first = SettingsService(
      defaultsProvider: () => AppConfig.defaults,
      supportDirectoryProvider: () async => directory,
    );
    await first.load();
    await first.setValue(['ui', 'themeMode'], 'light');
    await first.setValue(['scripts', 'directoryPath'], '/tmp/my-scripts');

    final userJson =
        jsonDecode(
              await File(
                '${directory.path}/${SettingsService.userFileName}',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    expect(userJson, {
      'ui': {'themeMode': 'light'},
      'scripts': {'directoryPath': '/tmp/my-scripts'},
    });

    final nextStart = SettingsService(
      defaultsProvider: () => AppConfig.defaults,
      supportDirectoryProvider: () async => directory,
    );
    final options = await nextStart.load();
    expect(options.themeMode, 'light');
    expect(options.locale, 'en');
    expect(options.scriptsDirectoryPath, '/tmp/my-scripts');
    expect(options.catalogSearchLimit, greaterThan(0));
  });

  test(
    'restore defaults clears JSON overrides and returns SSOT values',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ffmpeg_ui_reset_options_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final service = SettingsService(
        defaultsProvider: () => AppConfig.defaults,
        supportDirectoryProvider: () async => directory,
      );
      await service.load();
      await service.setValue(['ui', 'themeMode'], 'light');

      final options = await service.restoreDefaults();
      final userJson =
          jsonDecode(
                await File(
                  '${directory.path}/${SettingsService.userFileName}',
                ).readAsString(),
              )
              as Map<String, dynamic>;

      expect(userJson, isEmpty);
      expect(options.themeMode, 'system');
      expect(service.userOverrides, isEmpty);
    },
  );

  test(
    'terminal arguments from an older JSON are removed on startup',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ffmpeg_ui_terminal_options_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/${SettingsService.userFileName}');
      await file.writeAsString('''
{
  "terminal": {
    "defaultBinary": "ffprobe",
    "defaultArguments": ["-show_format", "prywatny plik.mp4"]
  }
}
''');
      final service = SettingsService(
        defaultsProvider: () => AppConfig.defaults,
        supportDirectoryProvider: () async => directory,
      );

      final options = await service.load();
      final saved =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final terminalDefaults = AppConfig.defaults['terminal']! as Map;

      expect(options.terminalDefaultBinary, 'ffprobe');
      expect(
        options.terminalDefaultArguments,
        terminalDefaults['defaultArguments'],
      );
      expect(saved, {
        'terminal': {'defaultBinary': 'ffprobe'},
      });
    },
  );

  test(
    'invalid user JSON is backed up and replaced with SSOT defaults',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ffmpeg_ui_invalid_options_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/${SettingsService.userFileName}');
      const invalidContent = '{"ui": {"themeMode": "uszkodzony",}';
      await file.writeAsString(invalidContent);
      final service = SettingsService(
        defaultsProvider: () => AppConfig.defaults,
        supportDirectoryProvider: () async => directory,
      );

      final options = await service.load();
      final backups = directory
          .listSync()
          .whereType<File>()
          .where(
            (entry) => entry.path
                .split(Platform.pathSeparator)
                .last
                .startsWith('options.invalid-'),
          )
          .toList();

      expect(options.themeMode, 'system');
      expect(service.userOverrides, isEmpty);
      expect(service.recoveryNotice, isNotNull);
      expect(jsonDecode(await file.readAsString()), isEmpty);
      expect(backups, hasLength(1));
      expect(await backups.single.readAsString(), invalidContent);
    },
  );
}
