import 'package:flutter/foundation.dart';

import 'app_config.dart';

/// Wspólny logger diagnostyczny aktywny wyłącznie w buildach debug.
abstract final class AppLogger {
  static void info(String area, String message) {
    _write('INFO', area, message);
  }

  static void warning(String area, String message) {
    _write('WARN', area, message);
  }

  static void error(
    String area,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final details = error == null ? message : '$message: $error';
    _write('ERROR', area, details);
    if (kDebugMode && stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static void _write(String level, String area, String message) {
    if (!kDebugMode) return;
    final timestamp = DateTime.now().toIso8601String();
    debugPrint(
      '[$timestamp][${AppConfig.applicationName}][$level][$area] $message',
    );
  }
}
