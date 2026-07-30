import '../models/command_models.dart';

class FfmpegProgress {
  const FfmpegProgress({
    required this.values,
    this.outTime,
    this.frame,
    this.speed,
    this.isComplete = false,
  });

  final Map<String, String> values;
  final Duration? outTime;
  final int? frame;
  final String? speed;
  final bool isComplete;

  String get summary {
    final parts = <String>[];
    if (frame != null) parts.add('frame=$frame');
    if (outTime != null) parts.add('time=${_formatDuration(outTime!)}');
    if (speed?.isNotEmpty == true) parts.add('speed=$speed');
    return parts.isEmpty ? 'FFmpeg przesyła dane postępu.' : parts.join(' · ');
  }

  static String _formatDuration(Duration value) {
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    final centiseconds = ((value.inMilliseconds % 1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return '$hours:$minutes:$seconds.$centiseconds';
  }
}

class FfmpegProgressParser {
  final StringBuffer _pending = StringBuffer();
  final Map<String, String> _values = {};

  List<FfmpegProgress> addChunk(String chunk) {
    _pending.write(chunk);
    final complete = _pending.toString().split('\n');
    _pending
      ..clear()
      ..write(complete.removeLast());

    final updates = <FfmpegProgress>[];
    for (final line in complete) {
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      if (key.isEmpty) continue;
      _values[key] = value;
      if (key == 'progress') {
        updates.add(_snapshot(isComplete: value == 'end'));
      }
    }
    return updates;
  }

  FfmpegProgress _snapshot({required bool isComplete}) {
    final outTimeUs = int.tryParse(_values['out_time_us'] ?? '');
    final outTime = outTimeUs == null
        ? _parseClock(_values['out_time'])
        : Duration(microseconds: outTimeUs);
    return FfmpegProgress(
      values: Map.unmodifiable(_values),
      outTime: outTime,
      frame: int.tryParse(_values['frame'] ?? ''),
      speed: _values['speed'],
      isComplete: isComplete,
    );
  }

  Duration? _parseClock(String? value) {
    final match = RegExp(
      r'^(\d+):(\d{2}):(\d{2})(?:\.(\d+))?$',
    ).firstMatch(value ?? '');
    if (match == null) return null;
    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    final fraction = (match.group(4) ?? '').padRight(6, '0').substring(0, 6);
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      microseconds: int.tryParse(fraction) ?? 0,
    );
  }
}

class QueueFfmpegProgressCommand {
  const QueueFfmpegProgressCommand({
    required this.command,
    required this.usesStructuredProgress,
  });

  final CommandDraft command;
  final bool usesStructuredProgress;

  static QueueFfmpegProgressCommand prepare(CommandDraft command) {
    if (!_isFfmpeg(command.executable) ||
        _hasProgressArgument(command.arguments) ||
        command.arguments.contains('pipe:1')) {
      return QueueFfmpegProgressCommand(
        command: command,
        usesStructuredProgress: false,
      );
    }
    final arguments = <String>['-progress', 'pipe:1'];
    if (!command.arguments.contains('-stats') &&
        !command.arguments.contains('-nostats')) {
      arguments.add('-nostats');
    }
    arguments.addAll(command.arguments);
    return QueueFfmpegProgressCommand(
      command: CommandDraft(
        executable: command.executable,
        arguments: arguments,
        private: command.private,
      ),
      usesStructuredProgress: true,
    );
  }

  static bool _isFfmpeg(String executable) {
    final fileName = executable.replaceAll('\\', '/').split('/').last;
    return fileName.toLowerCase() == 'ffmpeg' ||
        fileName.toLowerCase() == 'ffmpeg.exe';
  }

  static bool _hasProgressArgument(List<String> arguments) {
    return arguments.any(
      (argument) =>
          argument == '-progress' || argument.startsWith('-progress='),
    );
  }
}
