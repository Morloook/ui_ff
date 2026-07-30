import 'package:ffmpeg_ui/models/command_models.dart';
import 'package:ffmpeg_ui/services/ffmpeg_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses fragmented structured FFmpeg progress records', () {
    final parser = FfmpegProgressParser();

    expect(parser.addChunk('frame=42\nout_time_us=125'), isEmpty);
    final updates = parser.addChunk('0000\nspeed=2.5x\nprogress=continue\n');

    final progress = updates.single;
    expect(progress.frame, 42);
    expect(progress.outTime, const Duration(milliseconds: 1250));
    expect(progress.speed, '2.5x');
    expect(progress.isComplete, isFalse);
  });

  test('falls back to the clock value and recognizes final progress', () {
    final parser = FfmpegProgressParser();

    final progress = parser
        .addChunk('out_time=01:02:03.45\nprogress=end\n')
        .single;

    expect(
      progress.outTime,
      const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 450),
    );
    expect(progress.isComplete, isTrue);
  });

  test('adds structured progress only to queued FFmpeg commands', () {
    final prepared = QueueFfmpegProgressCommand.prepare(
      const CommandDraft(
        executable: r'C:\Tools\ffmpeg.exe',
        arguments: ['-i', 'input.mp4', 'output.mp4'],
      ),
    );

    expect(prepared.usesStructuredProgress, isTrue);
    expect(prepared.command.arguments, [
      '-progress',
      'pipe:1',
      '-nostats',
      '-i',
      'input.mp4',
      'output.mp4',
    ]);
  });

  test('preserves commands with their own progress or stdout pipe', () {
    const ffprobe = CommandDraft(
      executable: 'ffprobe',
      arguments: ['file.mp4'],
    );
    const customProgress = CommandDraft(
      executable: 'ffmpeg',
      arguments: ['-progress', 'report.txt', '-i', 'input.mp4', 'output.mp4'],
    );
    const stdoutPipe = CommandDraft(
      executable: 'ffmpeg',
      arguments: ['-i', 'input.mp4', 'pipe:1'],
    );

    for (final command in [ffprobe, customProgress, stdoutPipe]) {
      final prepared = QueueFfmpegProgressCommand.prepare(command);
      expect(prepared.usesStructuredProgress, isFalse);
      expect(prepared.command, same(command));
    }
  });
}
