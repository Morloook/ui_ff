import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

import 'core/app_config.dart';
import 'core/app_controller.dart';
import 'core/app_logger.dart';
import 'l10n/app_localizations.dart';
import 'l10n/localized_text.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.info('Lifecycle', 'Start procesu aplikacji.');
  FlutterError.onError = (details) {
    AppLogger.error(
      'Flutter',
      'Nieobsłużony błąd warstwy Flutter',
      details.exception,
      details.stack,
    );
    FlutterError.presentError(details);
  };
  await windowManager.ensureInitialized();
  unawaited(
    windowManager.waitUntilReadyToShow(null, () async {
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
      AppLogger.info('Lifecycle', 'Natywne okno aplikacji jest gotowe.');
    }),
  );
  final controller = AppController();
  runApp(FfmpegUiApp(controller: controller));
  unawaited(controller.initialize());
}

class FfmpegUiApp extends StatefulWidget {
  const FfmpegUiApp({super.key, required this.controller});
  final AppController controller;

  @override
  State<FfmpegUiApp> createState() => _FfmpegUiAppState();
}

class _FfmpegUiAppState extends State<FfmpegUiApp>
    with WidgetsBindingObserver, WindowListener {
  AppController get controller => widget.controller;
  bool _windowClosing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    windowManager.addListener(this);
    AppLogger.info('Lifecycle', 'Utworzono główny widget aplikacji.');
  }

  @override
  void onWindowClose() {
    if (_windowClosing) return;
    _windowClosing = true;
    AppLogger.info('Lifecycle', 'Odebrano żądanie zamknięcia okna.');
    unawaited(_closeWindow());
  }

  Future<void> _closeWindow() async {
    try {
      await controller.shutdown();
      AppLogger.info(
        'Lifecycle',
        'Zamykanie usług zakończone; niszczę natywne okno.',
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Lifecycle',
        'Błąd podczas poprawnego zamykania',
        error,
        stackTrace,
      );
    } finally {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.info('Lifecycle', 'Zmiana stanu aplikacji: ${state.name}.');
    if (state == AppLifecycleState.detached) {
      unawaited(controller.shutdown());
    }
  }

  @override
  void dispose() {
    AppLogger.info('Lifecycle', 'Zamykanie głównego widgetu aplikacji.');
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    unawaited(controller.shutdown());
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final configuredTheme = switch (controller.options?.themeMode) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
        final localeName = controller.options?.locale;
        return MaterialApp(
          title: AppConfig.applicationName,
          debugShowCheckedModeBanner: false,
          locale: localeName == null ? null : Locale(localeName),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: configuredTheme,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          home: Builder(
            builder: (context) {
              if (controller.initializing) {
                return const _StartupScreen();
              }
              if (controller.initializationError != null) {
                return _FatalStartupScreen(
                  message: controller.initializationError!,
                );
              }
              return AppShell(
                key: ValueKey(controller.interfaceRevision),
                controller: controller,
              );
            },
          ),
        );
      },
    );
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff4cc2ff),
      brightness: brightness,
    );
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xff0f1115) : null,
      cardTheme: const CardThemeData(
        margin: EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: dark ? const Color(0xff15181e) : null,
        indicatorColor: scheme.primaryContainer,
      ),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_filter_rounded, size: 56),
            SizedBox(height: 20),
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Wykrywanie FFmpeg i przygotowanie listy możliwości…'),
          ],
        ),
      ),
    );
  }
}

class _FatalStartupScreen extends StatelessWidget {
  const _FatalStartupScreen({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  const Text('Nie można uruchomić aplikacji'),
                  const SizedBox(height: 8),
                  SelectableText(message),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
