import 'dart:io';

import 'package:ffmpeg_ui/models/command_models.dart';
import 'package:ffmpeg_ui/services/job_queue_service.dart';
import 'package:ffmpeg_ui/services/process_service.dart';
import 'package:ffmpeg_ui/models/workflow_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adding a job waits for an explicit queue start', () async {
    if (Platform.isWindows || !File('/usr/bin/printf').existsSync()) return;

    final processService = ProcessService();
    final queue = JobQueueService(processService, paused: false);
    addTearDown(() async {
      queue.dispose();
      await processService.shutdown();
    });
    queue.add(
      'Test ręcznego startu',
      const CommandDraft(
        executable: '/usr/bin/printf',
        arguments: ['wynik kolejki'],
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(queue.jobs.single.state, QueueJobState.waiting);
    expect(queue.jobs.single.session, isNull);

    queue.start();
    await _waitUntil(() => queue.jobs.single.state == QueueJobState.completed);

    expect(queue.jobs.single.stdout, contains('wynik kolejki'));
    expect(queue.started, isFalse);
  });

  test('a workflow runs all steps sequentially as one queue job', () async {
    if (Platform.isWindows || !File('/usr/bin/printf').existsSync()) return;

    final processService = ProcessService();
    final queue = JobQueueService(processService, paused: true);
    addTearDown(() async {
      queue.dispose();
      await processService.shutdown();
    });
    queue.addWorkflow(
      const WorkflowDraft(
        name: 'Dwa etapy',
        steps: [
          WorkflowStep(
            name: 'Pierwszy',
            command: CommandDraft(
              executable: '/usr/bin/printf',
              arguments: ['jeden'],
            ),
          ),
          WorkflowStep(
            name: 'Drugi',
            command: CommandDraft(
              executable: '/usr/bin/printf',
              arguments: ['dwa'],
            ),
          ),
        ],
      ),
    );

    queue.start();
    await _waitUntil(() => queue.jobs.single.state == QueueJobState.completed);

    final job = queue.jobs.single;
    expect(job.sessions, hasLength(2));
    expect(job.stdout, contains('jeden'));
    expect(job.stdout, contains('dwa'));
    expect(job.currentStepIndex, 1);
  });

  test('live console preserves stdout and stderr event order', () {
    final job = QueueJob(
      id: 'test-log',
      name: 'Test logu',
      workflow: const WorkflowDraft(
        name: 'Test logu',
        steps: [
          WorkflowStep(
            name: 'Etap',
            command: CommandDraft(executable: 'ffmpeg', arguments: []),
          ),
        ],
      ),
    );

    job.appendOutput(const ProcessOutputEvent(false, 'pierwszy\n'));
    job.appendOutput(const ProcessOutputEvent(true, 'drugi\n'));
    job.appendOutput(const ProcessOutputEvent(false, 'trzeci\n'));

    expect(job.console, 'pierwszy\ndrugi\ntrzeci\n');
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Kolejka nie zakończyła zadania w wyznaczonym czasie.');
}
