import 'dart:io';

import 'package:ffmpeg_ui/models/binary_installation.dart';
import 'package:ffmpeg_ui/models/probe_result.dart';
import 'package:ffmpeg_ui/services/binary_service.dart';
import 'package:ffmpeg_ui/services/probe_service.dart';
import 'package:ffmpeg_ui/services/process_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'ProbeService reads a real local media file when FFmpeg is available',
    () async {
      if (Platform.isWindows ||
          !File('/usr/bin/ffmpeg').existsSync() ||
          !File('/usr/bin/ffprobe').existsSync()) {
        return;
      }
      final directory = await Directory.systemTemp.createTemp(
        'ffmpeg_ui_probe_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final mediaPath = '${directory.path}/próba pliku.mkv';
      final generated = await Process.run('/usr/bin/ffmpeg', [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'color=size=16x16:duration=0.1',
        '-c:v',
        'ffv1',
        mediaPath,
      ], runInShell: false);
      expect(generated.exitCode, 0, reason: '${generated.stderr}');

      final result = await ProbeService(ProcessService()).inspect(
        const BinaryInstallation(
          kind: BinaryKind.ffprobe,
          path: '/usr/bin/ffprobe',
          available: true,
        ),
        ProbeRequest(sourcePath: mediaPath),
      );

      expect(result.error, isNull);
      expect(result.streams, hasLength(1));
      expect(result.streams.single['codec_name'], 'ffv1');
      expect(result.format?['filename'], mediaPath);
      final exifToolPath = BinaryService().findOnPath('exiftool');
      if (exifToolPath == null) {
        expect(result.exifToolState, ExifToolState.unavailable);
      } else {
        expect(result.exifToolState, ExifToolState.completed);
        expect(result.exifToolMetadata, isNotEmpty);
        expect(result.exifToolMetadata['System:FileName'], 'próba pliku.mkv');
      }
    },
  );

  test('ProbeService writes metadata and preserves an original copy', () async {
    if (Platform.isWindows ||
        !File('/usr/bin/ffmpeg').existsSync() ||
        BinaryService().findOnPath('exiftool') == null) {
      return;
    }
    final directory = await Directory.systemTemp.createTemp(
      'ffmpeg_ui_metadata_write_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final imagePath = '${directory.path}/obraz próby.jpg';
    final generated = await Process.run('/usr/bin/ffmpeg', [
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      'color=size=16x16',
      '-frames:v',
      '1',
      imagePath,
    ], runInShell: false);
    expect(generated.exitCode, 0, reason: '${generated.stderr}');

    final service = ProbeService(ProcessService());
    final written = await service.writeMetadata(
      sourcePath: imagePath,
      tag: 'XMP:Title',
      value: 'Zażółć próbę',
    );

    expect(written.success, isTrue, reason: written.message);
    expect(written.backupPath, '${imagePath}_original');
    expect(File('${imagePath}_original').existsSync(), isTrue);

    final inspected = await service.inspect(
      const BinaryInstallation(
        kind: BinaryKind.ffprobe,
        path: '/usr/bin/ffprobe',
        available: true,
      ),
      ProbeRequest(sourcePath: imagePath),
    );
    expect(inspected.exifToolState, ExifToolState.completed);
    expect(inspected.exifToolMetadata['XMP-dc:Title'], 'Zażółć próbę');
  });
}
