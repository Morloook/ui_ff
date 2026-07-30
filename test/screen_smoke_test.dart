import 'package:ffmpeg_ui/core/app_config.dart';
import 'package:ffmpeg_ui/core/app_controller.dart';
import 'package:ffmpeg_ui/models/app_options.dart';
import 'package:ffmpeg_ui/ui/screens/catalog_screen.dart';
import 'package:ffmpeg_ui/ui/screens/environment_screen.dart';
import 'package:ffmpeg_ui/ui/screens/scripts_screen.dart';
import 'package:ffmpeg_ui/ui/screens/terminal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('core screens render without an initialized catalog', (
    tester,
  ) async {
    final controller = AppController()
      ..options = AppOptions.fromJson(
        Map<String, dynamic>.from(AppConfig.defaults),
      );
    addTearDown(controller.dispose);

    for (final screen in [
      EnvironmentScreen(controller: controller),
      CatalogScreen(controller: controller),
      TerminalScreen(controller: controller),
      ScriptsScreen(controller: controller),
    ]) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: screen)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
