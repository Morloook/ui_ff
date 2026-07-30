import 'dart:io';

import 'package:ffmpeg_ui/core/app_config.dart';
import 'package:ffmpeg_ui/l10n/app_localizations.dart';
import 'package:ffmpeg_ui/l10n/localized_text.dart';
import 'package:ffmpeg_ui/services/settings_service.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('English locale translates shared interface text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Column(
            children: [
              Text('Ustawienia'),
              Text('Kreator polecenia'),
              Text('Wybierz skrypt z listy.'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Command builder'), findsOneWidget);
    expect(find.text('Select a script from the list.'), findsOneWidget);
    expect(find.text('Ustawienia'), findsNothing);
  });

  test('selected locale is stored as a user JSON override', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ffmpeg_ui_locale_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final service = SettingsService(
      defaultsProvider: () => AppConfig.defaults,
      supportDirectoryProvider: () async => directory,
    );
    await service.load();

    final changed = await service.setValue(['ui', 'locale'], 'en');
    final restarted = SettingsService(
      defaultsProvider: () => AppConfig.defaults,
      supportDirectoryProvider: () async => directory,
    );
    final loaded = await restarted.load();

    expect(changed.locale, 'en');
    expect(loaded.locale, 'en');
    expect(
      await File('${directory.path}/options.json').readAsString(),
      contains('"locale": "en"'),
    );
  });
}
