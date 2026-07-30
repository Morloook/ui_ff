import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../core/app_logger.dart';
import '../models/binary_installation.dart';

class BinaryService {
  Future<List<BinaryInstallation>> detect({
    String? ffmpegOverride,
    String? ffprobeOverride,
  }) async {
    AppLogger.info('Binary', 'Rozpoczęcie wykrywania FFmpeg i FFprobe.');
    return Future.wait([
      inspect(BinaryKind.ffmpeg, overridePath: ffmpegOverride),
      inspect(BinaryKind.ffprobe, overridePath: ffprobeOverride),
    ]);
  }

  Future<BinaryInstallation> inspect(
    BinaryKind kind, {
    String? overridePath,
  }) async {
    final name = kind.name;
    AppLogger.info('Binary', 'Sprawdzanie binarium $name.');
    final path = overridePath?.trim().isNotEmpty == true
        ? overridePath!.trim()
        : findOnPath(name);
    if (path == null) {
      AppLogger.warning('Binary', 'Nie znaleziono binarium $name.');
      return BinaryInstallation(
        kind: kind,
        path: overridePath ?? name,
        available: false,
        error: 'Nie znaleziono $name w zmiennej PATH.',
      );
    }

    try {
      final result = await Process.run(path, const [
        '-version',
      ], runInShell: false).timeout(const Duration(seconds: 10));
      final output = '${result.stdout}\n${result.stderr}'.trim();
      if (result.exitCode != 0) {
        AppLogger.warning(
          'Binary',
          '$name zwrócił kod ${result.exitCode} podczas odczytu wersji.',
        );
        return BinaryInstallation(
          kind: kind,
          path: path,
          available: false,
          error: output,
        );
      }
      final lines = const LineSplitter().convert(output);
      AppLogger.info('Binary', 'Poprawnie wykryto $name.');
      return BinaryInstallation(
        kind: kind,
        path: path,
        available: true,
        version: lines.isEmpty ? '' : lines.first.trim(),
        configuration: lines
            .firstWhere(
              (line) => line.startsWith('configuration:'),
              orElse: () => '',
            )
            .trim(),
      );
    } on Object catch (error) {
      AppLogger.error('Binary', 'Błąd wykrywania $name', error);
      return BinaryInstallation(
        kind: kind,
        path: path,
        available: false,
        error: error.toString(),
      );
    }
  }

  String fingerprint(BinaryInstallation installation) {
    return fingerprintAll([installation]);
  }

  String fingerprintAll(Iterable<BinaryInstallation> installations) {
    final source = [
      for (final installation in installations) ...[
        installation.kind.name,
        installation.path,
        installation.version,
        installation.configuration,
      ],
    ].join('\u0000');
    return sha256.convert(utf8.encode(source)).toString();
  }

  String? findOnPath(String executable) {
    final pathValue = Platform.environment['PATH'];
    if (pathValue == null || pathValue.isEmpty) return null;
    final extensions = Platform.isWindows ? _windowsExtensions() : const [''];
    for (final directory in pathValue.split(Platform.isWindows ? ';' : ':')) {
      if (directory.trim().isEmpty) continue;
      for (final extension in extensions) {
        final separator = Platform.pathSeparator;
        final candidate =
            '${directory.endsWith(separator) ? directory : '$directory$separator'}'
            '$executable$extension';
        final type = FileSystemEntity.typeSync(candidate);
        if (type == FileSystemEntityType.file ||
            type == FileSystemEntityType.link) {
          return File(candidate).absolute.path;
        }
      }
    }
    return null;
  }

  List<String> _windowsExtensions() {
    final value = Platform.environment['PATHEXT'] ?? '.EXE;.BAT;.CMD;.COM';
    return [
      '',
      ...value.split(';').map((extension) => extension.toLowerCase()),
    ];
  }
}
