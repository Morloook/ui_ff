import 'dart:io';

import 'package:ffmpeg_ui/models/command_models.dart';
import 'package:ffmpeg_ui/models/filter_complex.dart';
import 'package:ffmpeg_ui/services/command_builder_service.dart';
import 'package:ffmpeg_ui/services/process_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArgumentLexer', () {
    test('preserves spaces, Unicode and empty quoted arguments', () {
      final arguments = const ArgumentLexer().parse(
        '-i "zażółć gęślą.mp4" -metadata \'title=Próba\' ""',
      );
      expect(arguments, [
        '-i',
        'zażółć gęślą.mp4',
        '-metadata',
        'title=Próba',
        '',
      ]);
    });

    test('rejects unterminated quotes', () {
      expect(
        () => const ArgumentLexer().parse('-i "brak końca'),
        throwsFormatException,
      );
    });
  });

  test('builder preserves global, input and output argument order', () {
    final draft = CommandBuilderDraft(
      globalArguments: const [
        ScopedArgument(scope: ArgumentScope.global, option: '-hide_banner'),
      ],
      inputs: [
        MediaInputDraft(
          path: 'wejście.mp4',
          arguments: const [
            ScopedArgument(
              scope: ArgumentScope.input,
              option: '-ss',
              value: '10',
            ),
          ],
        ),
      ],
      outputs: [
        MediaOutputDraft(
          path: 'wynik.mkv',
          arguments: const [
            ScopedArgument(
              scope: ArgumentScope.output,
              option: '-c:v',
              value: 'copy',
            ),
          ],
        ),
      ],
    );

    final result = const CommandBuilderService().build('ffmpeg', draft);

    expect(result.arguments, [
      '-hide_banner',
      '-ss',
      '10',
      '-i',
      'wejście.mp4',
      '-c:v',
      'copy',
      'wynik.mkv',
    ]);
  });

  test('process runner does not interpret shell substitutions', () async {
    if (Platform.isWindows || !File('/usr/bin/printf').existsSync()) return;
    final marker = File(
      '${Directory.systemTemp.path}/ffmpeg_ui_shell_marker_$pid',
    );
    if (marker.existsSync()) marker.deleteSync();
    final literal =
        r'$(touch '
        '${marker.path})';
    final result = await ProcessService().run(
      CommandDraft(executable: '/usr/bin/printf', arguments: [literal]),
    );

    expect(result.stdout, literal);
    expect(marker.existsSync(), isFalse);
  });

  test('process runner stops active processes during shutdown', () async {
    if (Platform.isWindows || !File('/usr/bin/sleep').existsSync()) return;
    final service = ProcessService();
    final running = await service.start(
      const CommandDraft(executable: '/usr/bin/sleep', arguments: ['30']),
    );

    await service.shutdown();
    final session = await running.completed.timeout(const Duration(seconds: 5));

    expect(session.exitCode, isNot(0));
    expect(
      () => service.start(
        const CommandDraft(executable: '/usr/bin/printf', arguments: ['test']),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('builder keeps filter_complex as one ordered argument', () {
    final draft = CommandBuilderDraft(
      filterComplex: FilterComplexDraft(
        expression: '[0:v]scale=1280:-2[video];[0:a]anull[audio]',
      ),
      inputs: [MediaInputDraft(path: 'input.mp4')],
      outputs: [
        MediaOutputDraft(
          path: 'output.mp4',
          arguments: const [
            ScopedArgument(
              scope: ArgumentScope.output,
              option: '-map',
              value: '[video]',
            ),
          ],
        ),
      ],
    );

    final command = const CommandBuilderService().build('ffmpeg', draft);

    expect(command.arguments, [
      '-filter_complex',
      '[0:v]scale=1280:-2[video];[0:a]anull[audio]',
      '-i',
      'input.mp4',
      '-map',
      '[video]',
      'output.mp4',
    ]);
  });
}
