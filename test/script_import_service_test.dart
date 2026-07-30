import 'dart:io';

import 'package:ffmpeg_ui/services/process_service.dart';
import 'package:ffmpeg_ui/services/script_import_service.dart';
import 'package:ffmpeg_ui/services/script_workflow_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const importer = ScriptImportService();

  test('discovers only the skrypty directory next to the executable', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'ffmpeg_ui_scripts_directory_',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final scriptsDirectory = Directory('${temporary.path}/skrypty');
    await scriptsDirectory.create();
    final scriptFile = File('${scriptsDirectory.path}/example.sh');
    await scriptFile.writeAsString('ffmpeg -version\n');
    final importer = ScriptImportService(
      executablePath: '${temporary.path}/ffmpeg_ui',
    );

    expect(importer.expectedScriptsDirectory(), scriptsDirectory.path);
    expect(importer.discoverDirectories(), [scriptsDirectory.path]);
    expect((await importer.scan()).single.path, scriptFile.absolute.path);
  });

  test(
    'uses a selected scripts directory instead of the adjacent default',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'ffmpeg_ui_selected_scripts_directory_',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final selectedDirectory = Directory('${temporary.path}/selected');
      await selectedDirectory.create();
      final scriptFile = File('${selectedDirectory.path}/custom.sh');
      await scriptFile.writeAsString('ffmpeg -version\n');
      final importer = ScriptImportService(
        executablePath: '${temporary.path}/ffmpeg_ui',
      );

      expect(
        importer.expectedScriptsDirectory(
          configuredDirectory: selectedDirectory.path,
        ),
        selectedDirectory.path,
      );
      expect(
        (await importer.scan(
          configuredDirectory: selectedDirectory.path,
        )).single.path,
        scriptFile.absolute.path,
      );
    },
  );

  test('imports a generic multi-step workflow without bundled scripts', () {
    const source = r'''
#!/usr/bin/env bash
QUALITY="21"
read -p "Input file: " INPUT_FILE
ffmpeg -i "$INPUT_FILE" -crf "$QUALITY" "$INTERMEDIATE_FILE"
ffmpeg -i "$INTERMEDIATE_FILE" "$OUTPUT_FILE"
''';

    final script = importer.parse('/tmp/example_workflow.sh', source);

    expect(script.commands, hasLength(2));
    expect(script.fields, isNotEmpty);
    expect(script.canPrepare, isTrue);
    expect(
      script.fields.map((field) => field.variable),
      containsAll([
        'INPUT_FILE',
        'INTERMEDIATE_FILE',
        'OUTPUT_FILE',
        'QUALITY',
      ]),
    );
  });

  test('uses a script heading and exposes log detail controls', () {
    const source = r'''
#!/usr/bin/env bash
printf '=== Example audio workflow ===\n'
LOG_LEVEL="error"
STATS_PERIOD="1"
read -p "Input file: " INPUT_FILE
ffmpeg -hide_banner -stats -loglevel "$LOG_LEVEL" -stats_period "$STATS_PERIOD" -i "$INPUT_FILE" -c:a copy "$OUTPUT_FILE"
''';
    final script = importer.parse('/tmp/example_audio.sh', source);
    final fields = {
      for (final field in script.fields) field.variable: field.initialValue,
    };

    expect(script.name, 'Example audio workflow');
    expect(fields['LOG_LEVEL'], 'error');
    expect(fields['STATS_PERIOD'], '1');
    expect(
      script.fields.any(
        (field) =>
            field.kind.name == 'toggle' &&
            field.enabledValue == '-hide_banner' &&
            field.initialValue == '-hide_banner',
      ),
      isTrue,
    );
    expect(
      script.fields.any((field) => field.enabledValue == '-stats'),
      isTrue,
    );
  });

  test(
    'disabled literal FFmpeg switch is removed from final arguments',
    () async {
      const source = r'''
#!/usr/bin/env bash
read -p "Input file: " INPUT_FILE
ffmpeg -hide_banner -stats -i "$INPUT_FILE" -c:a copy "$OUTPUT_FILE"
''';
      final temporary = await Directory.systemTemp.createTemp(
        'ffmpeg_ui_flags_',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final input = File('${temporary.path}/input.mp3');
      await input.writeAsBytes(const [1]);
      final script = importer.parse('${temporary.path}/flags.sh', source);
      final hideBanner = script.fields.singleWhere(
        (field) => field.enabledValue == '-hide_banner',
      );
      final values = {
        for (final field in script.fields) field.variable: field.initialValue,
        hideBanner.variable: '',
        'INPUT_FILE': input.path,
        'OUTPUT_FILE': '${temporary.path}/output.mp3',
      };
      final workflowService = ScriptWorkflowService(ProcessService());
      final preparation = workflowService.prepare(
        script: script,
        values: values,
        ffmpegPath: '/usr/bin/ffmpeg',
      );

      expect(preparation.errors, isEmpty);
      expect(
        preparation.workflow!.steps.single.command.arguments,
        isNot(contains('-hide_banner')),
      );
      expect(
        preparation.workflow!.steps.single.command.arguments,
        contains('-stats'),
      );
    },
  );

  test('discovers fields and editable quality in a new script', () {
    const source = r'''
#!/usr/bin/env bash
QUALITY="21"
read -p "Select video: " INPUT_FILE
ffmpeg -i "$INPUT_FILE" -c:v libx264 -preset medium -crf "$QUALITY" "$OUTPUT_FILE"
''';

    final script = importer.parse('/tmp/new_script.sh', source);
    final variables = script.fields.map((field) => field.variable).toSet();

    expect(script.commands, hasLength(1));
    expect(variables, containsAll(['INPUT_FILE', 'OUTPUT_FILE', 'QUALITY']));
    expect(variables, containsAll(['VIDEO_CODEC', 'ENCODING_PRESET']));
  });

  test('prepares a complete workflow without shell placeholders', () async {
    const source = r'''
#!/usr/bin/env bash
read -p "Input file: " INPUT_FILE
ffmpeg -i "$INPUT_FILE" -c:a copy "$OUTPUT_FILE"
''';
    final temporary = await Directory.systemTemp.createTemp(
      'ffmpeg_ui_script_',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final sourceFile = File('${temporary.path}/Zażółć utwór_v2.mp3');
    await sourceFile.writeAsBytes(const [1, 2, 3]);
    final script = importer.parse('${temporary.path}/audio.sh', source);
    final processService = ProcessService();
    addTearDown(processService.shutdown);
    final preparation = ScriptWorkflowService(processService).prepare(
      script: script,
      values: {
        for (final field in script.fields) field.variable: field.initialValue,
        'INPUT_FILE': sourceFile.path,
        'OUTPUT_FILE': '${temporary.path}/Zażółć_utwór_clean.mp3',
      },
      ffmpegPath: '/usr/bin/ffmpeg',
    );

    expect(preparation.errors, isEmpty);
    expect(preparation.unresolvedVariables, isEmpty);
    expect(preparation.workflow?.steps, hasLength(1));
    final arguments = preparation.workflow!.steps.single.command.arguments;
    expect(arguments.join(' '), isNot(contains(r'$')));
    expect(arguments.join(' '), isNot(contains('<')));
    expect(arguments, contains('${temporary.path}/Zażółć_utwór_clean.mp3'));
  });

  test('prepares generic clip and short workflows from form data', () async {
    const clipSource = r'''
#!/usr/bin/env bash
read -p "Audio file: " AUDIO_FILE
read -p "Image file: " IMAGE_FILE
ffmpeg -i "$AUDIO_FILE" -i "$IMAGE_FILE" "$CLIP_FILE"
ffmpeg -i "$CLIP_FILE" "$OUTPUT_FILE"
''';
    const shortSource = r'''
#!/usr/bin/env bash
read -p "Audio file: " AUDIO_FILE
read -p "Image file: " IMAGE_FILE
ffmpeg -i "$AUDIO_FILE" -i "$IMAGE_FILE" "$OUTPUT_FILE"
''';
    final temporary = await Directory.systemTemp.createTemp('ffmpeg_ui_media_');
    addTearDown(() => temporary.delete(recursive: true));
    final audio = File('${temporary.path}/audio.mp3');
    final image = File('${temporary.path}/cover.png');
    final clip = File('${temporary.path}/clip.mp4');
    await audio.writeAsBytes(const [1]);
    await image.writeAsBytes(const [2]);
    await clip.writeAsBytes(const [3]);
    final processService = ProcessService();
    addTearDown(processService.shutdown);
    final workflowService = ScriptWorkflowService(processService);

    for (final entry in {clipSource: 2, shortSource: 1}.entries) {
      final script = importer.parse('${temporary.path}/workflow.sh', entry.key);
      final preparation = workflowService.prepare(
        script: script,
        values: {
          for (final field in script.fields) field.variable: field.initialValue,
          'AUDIO_FILE': audio.path,
          'IMAGE_FILE': image.path,
          'CLIP_FILE': '${temporary.path}/clip.mp4',
          'OUTPUT_FILE': '${temporary.path}/output.mp4',
        },
        ffmpegPath: '/usr/bin/ffmpeg',
      );

      expect(preparation.errors, isEmpty);
      expect(preparation.unresolvedVariables, isEmpty);
      expect(preparation.workflow?.steps, hasLength(entry.value));
    }
  });
}
