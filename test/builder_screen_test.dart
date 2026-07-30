import 'package:ffmpeg_ui/core/app_config.dart';
import 'package:ffmpeg_ui/core/app_controller.dart';
import 'package:ffmpeg_ui/models/app_options.dart';
import 'package:ffmpeg_ui/models/capability.dart';
import 'package:ffmpeg_ui/ui/screens/builder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('builder offers a searchable described option picker', (
    tester,
  ) async {
    final controller = _BuilderTestController();
    controller.options = AppOptions.fromJson(
      Map<String, dynamic>.from(AppConfig.defaults),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuilderScreen(controller: controller, onOpenTerminal: () {}),
        ),
      ),
    );
    await tester.tap(find.text('Dodaj opcję').first);
    await tester.pumpAndSettle();

    expect(find.text('Lista lokalnych opcji FFmpeg · 1/1'), findsOneWidget);
    expect(find.text('Sortowanie'), findsOneWidget);
    expect(find.text('Rodzaj'), findsOneWidget);
    expect(find.text('-crf'), findsOneWidget);
    expect(find.textContaining('Constant Rate Factor'), findsOneWidget);

    await tester.tap(find.text('-crf'));
    await tester.pumpAndSettle();

    final optionField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Opcja',
      ),
    );
    expect(optionField.controller?.text, '-crf');
    expect(find.textContaining('Typ wartości: int'), findsOneWidget);
    expect(find.textContaining('Zakres: 0 – 63'), findsOneWidget);
  });

  testWidgets('input and output paths can be cleared with one action', (
    tester,
  ) async {
    final controller = _BuilderTestController();
    controller.options = AppOptions.fromJson(
      Map<String, dynamic>.from(AppConfig.defaults),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuilderScreen(controller: controller, onOpenTerminal: () {}),
        ),
      ),
    );

    final pathFields = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Ścieżka',
    );
    await tester.enterText(pathFields.first, '/tmp/wejście.mp4');
    await tester.enterText(pathFields.last, '/tmp/wyjście.mkv');
    await tester.pump();

    expect(find.byTooltip('Wyczyść całą ścieżkę'), findsNWidgets(2));
    final inputClearButton = find.descendant(
      of: pathFields.first,
      matching: find.byIcon(Icons.close),
    );
    await tester.ensureVisible(inputClearButton);
    await tester.tap(inputClearButton);
    await tester.pump();

    final input = tester.widget<TextField>(pathFields.first);
    final output = tester.widget<TextField>(pathFields.last);
    expect(input.controller?.text, isEmpty);
    expect(output.controller?.text, '/tmp/wyjście.mkv');
  });
}

class _BuilderTestController extends AppController {
  final component = const FfmpegComponent(
    id: 1,
    kind: ComponentKind.globalOption,
    name: 'crf',
    description: 'Constant Rate Factor quality control.',
    flags: 'E..V.......',
    mediaType: MediaType.video,
    helpTarget: '',
    rawLine: '-crf <int>',
    detailsLoaded: true,
  );

  @override
  Future<List<FfmpegComponent>> commandOptions() async => [component];

  @override
  Future<FfmpegComponent> loadComponentDetails(
    FfmpegComponent component,
  ) async {
    return component.copyWith(
      options: const [
        OptionDefinition(
          name: 'crf',
          valueType: 'int',
          flags: 'E..V.......',
          description: 'Constant Rate Factor quality control.',
          rawLine: '-crf <int>',
          defaultValue: '23',
          minimum: '0',
          maximum: '63',
        ),
      ],
    );
  }
}
