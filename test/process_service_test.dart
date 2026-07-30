import 'dart:io';

import 'package:ffmpeg_ui/models/command_models.dart';
import 'package:ffmpeg_ui/services/process_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('captures stdout, stderr and a failing exit code', () async {
    if (Platform.isWindows || !File('/bin/sh').existsSync()) return;
    final service = ProcessService();
    addTearDown(service.shutdown);

    final result = await service.run(
      const CommandDraft(
        executable: '/bin/sh',
        arguments: ['-c', 'printf output; printf error >&2; exit 7'],
      ),
    );

    expect(result.stdout, 'output');
    expect(result.stderr, 'error');
    expect(result.exitCode, 7);
    expect(result.state, ProcessState.failed);
  });

  test('streams stdout and stderr separately in arrival order', () async {
    if (Platform.isWindows || !File('/bin/sh').existsSync()) return;
    final service = ProcessService();
    addTearDown(service.shutdown);
    final running = await service.start(
      const CommandDraft(
        executable: '/bin/sh',
        arguments: ['-c', 'printf one; printf two >&2'],
      ),
    );
    final events = await running.output.toList();
    await running.completed;

    expect(events.map((event) => event.text).join(), contains('one'));
    expect(events.map((event) => event.text).join(), contains('two'));
    expect(events.any((event) => event.isStdErr), isTrue);
  });

  test('forwards stdin and reports an unavailable executable', () async {
    if (Platform.isWindows || !File('/bin/sh').existsSync()) return;
    final service = ProcessService();
    addTearDown(service.shutdown);
    final running = await service.start(
      const CommandDraft(
        executable: '/bin/sh',
        arguments: ['-c', r'read line; printf "$line"'],
      ),
    );
    await running.writeLine('zażółć');
    final result = await running.completed;
    expect(result.stdout, 'zażółć');

    await expectLater(
      service.start(
        const CommandDraft(
          executable: '/definitely/missing/ffmpeg',
          arguments: [],
        ),
      ),
      throwsA(isA<ProcessException>()),
    );
  });
}
