import 'package:ffmpeg_ui/core/app_config.dart';
import 'package:ffmpeg_ui/core/app_controller.dart';
import 'package:ffmpeg_ui/models/app_options.dart';
import 'package:ffmpeg_ui/models/binary_installation.dart';
import 'package:ffmpeg_ui/ui/screens/terminal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('terminal changes the selected FFmpeg binary without a shell', (
    tester,
  ) async {
    final controller = _TerminalTestController()
      ..options = AppOptions.fromJson(
        Map<String, dynamic>.from(AppConfig.defaults),
      )
      ..installations = const [
        BinaryInstallation(
          kind: BinaryKind.ffmpeg,
          path: '/usr/bin/ffmpeg',
          available: true,
        ),
        BinaryInstallation(
          kind: BinaryKind.ffprobe,
          path: '/usr/bin/ffprobe',
          available: true,
        ),
      ];
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TerminalScreen(controller: controller)),
      ),
    );

    expect(find.text('ffmpeg'), findsWidgets);
    await tester.tap(find.byType(DropdownButtonFormField<BinaryKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ffprobe').last);
    await tester.pump();
    expect(find.text('ffprobe'), findsWidgets);
  });
}

class _TerminalTestController extends AppController {
  @override
  Future<void> updateOption(List<String> path, Object? value) async {}
}
