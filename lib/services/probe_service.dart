import 'dart:convert';
import 'dart:io';

import '../core/app_logger.dart';
import '../models/binary_installation.dart';
import '../models/command_models.dart';
import '../models/probe_result.dart';
import 'binary_service.dart';
import 'process_service.dart';

class ProbeRequest {
  const ProbeRequest({
    required this.sourcePath,
    this.showEntries = '',
    this.streamSelector = '',
    this.readIntervals = '',
    this.showPackets = false,
    this.showFrames = false,
    this.useExifTool = true,
  });

  final String sourcePath;
  final String showEntries;
  final String streamSelector;
  final String readIntervals;
  final bool showPackets;
  final bool showFrames;
  final bool useExifTool;
}

class ProbeService {
  ProbeService(
    this.processService, {
    String? Function(String executable)? executableFinder,
  }) : _executableFinder = executableFinder ?? BinaryService().findOnPath;

  final ProcessService processService;
  final String? Function(String executable) _executableFinder;

  Future<ProbeResult> inspect(
    BinaryInstallation ffprobe,
    ProbeRequest request,
  ) async {
    final startedAt = DateTime.now();
    AppLogger.info(
      'FFprobe',
      'Rozpoczęcie analizy pliku; '
          'ramki=${request.showFrames}, pakiety=${request.showPackets}.',
    );
    final arguments = <String>[
      '-v',
      'error',
      '-of',
      'json',
      '-show_format',
      '-show_streams',
      '-show_chapters',
      '-show_programs',
    ];
    if (request.showEntries.trim().isNotEmpty) {
      arguments.addAll(['-show_entries', request.showEntries.trim()]);
    }
    if (request.streamSelector.trim().isNotEmpty) {
      arguments.addAll(['-select_streams', request.streamSelector.trim()]);
    }
    if (request.readIntervals.trim().isNotEmpty) {
      arguments.addAll(['-read_intervals', request.readIntervals.trim()]);
    }
    if (request.showPackets) arguments.add('-show_packets');
    if (request.showFrames) arguments.add('-show_frames');
    arguments.add(request.sourcePath);

    final session = await processService.run(
      CommandDraft(executable: ffprobe.path, arguments: arguments),
    );
    if (session.exitCode != 0) {
      AppLogger.warning(
        'FFprobe',
        'Analiza zakończona kodem ${session.exitCode}.',
      );
      return ProbeResult(
        sourcePath: request.sourcePath,
        json: const {},
        startedAt: startedAt,
        duration: DateTime.now().difference(startedAt),
        error: session.stderr.isEmpty ? session.error : session.stderr,
      );
    }
    try {
      final decoded = jsonDecode(session.stdout);
      if (decoded is! Map) {
        throw const FormatException('FFprobe nie zwrócił obiektu JSON.');
      }
      AppLogger.info(
        'FFprobe',
        'Podstawowa analiza FFprobe zakończona poprawnie.',
      );
      final exifTool = request.useExifTool
          ? await _readExifTool(request.sourcePath)
          : const _ExifToolResult(state: ExifToolState.disabled);
      final duration = DateTime.now().difference(startedAt);
      AppLogger.info(
        'Inspector',
        'Pełna analiza zakończona w ${duration.inMilliseconds} ms; '
            'ExifTool=${exifTool.state.name}.',
      );
      return ProbeResult(
        sourcePath: request.sourcePath,
        json: decoded.map((key, value) => MapEntry(key.toString(), value)),
        startedAt: startedAt,
        duration: duration,
        exifToolState: exifTool.state,
        exifToolMetadata: exifTool.metadata,
        exifToolError: exifTool.error,
      );
    } on Object catch (error) {
      AppLogger.error('FFprobe', 'Nie można zdekodować odpowiedzi JSON', error);
      return ProbeResult(
        sourcePath: request.sourcePath,
        json: const {},
        startedAt: startedAt,
        duration: DateTime.now().difference(startedAt),
        error: 'Nie można odczytać JSON: $error\n${session.stdout}',
      );
    }
  }

  Future<_ExifToolResult> _readExifTool(String sourcePath) async {
    final executable = _executableFinder('exiftool');
    if (executable == null) {
      AppLogger.info('ExifTool', 'ExifTool nie jest dostępny w PATH.');
      return const _ExifToolResult(
        state: ExifToolState.unavailable,
        error: 'Nie znaleziono programu exiftool w PATH.',
      );
    }
    AppLogger.info('ExifTool', 'Odczytywanie rozszerzonych metadanych.');
    try {
      final session = await processService.run(
        CommandDraft(
          executable: executable,
          arguments: [
            '-j',
            '-a',
            '-U',
            '-s',
            '-G3:1',
            '-ee3',
            '-api',
            'RequestAll=3',
            '-api',
            'LargeFileSupport=1',
            sourcePath,
          ],
          private: true,
        ),
      );
      if (session.exitCode != 0) {
        final error = session.stderr.trim().isEmpty
            ? 'ExifTool zakończył działanie kodem ${session.exitCode}.'
            : session.stderr.trim();
        AppLogger.warning('ExifTool', error);
        return _ExifToolResult(state: ExifToolState.failed, error: error);
      }
      final decoded = jsonDecode(session.stdout);
      if (decoded is! List || decoded.isEmpty || decoded.first is! Map) {
        throw const FormatException(
          'ExifTool nie zwrócił oczekiwanej tablicy JSON.',
        );
      }
      final metadata = (decoded.first as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      );
      AppLogger.info(
        'ExifTool',
        'Odczytano ${metadata.length} rozszerzonych tagów.',
      );
      return _ExifToolResult(
        state: ExifToolState.completed,
        metadata: metadata,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'ExifTool',
        'Nie można odczytać metadanych',
        error,
        stackTrace,
      );
      return _ExifToolResult(
        state: ExifToolState.failed,
        error: error.toString(),
      );
    }
  }

  Future<MetadataWriteResult> writeMetadata({
    required String sourcePath,
    required String tag,
    required String value,
  }) async {
    final normalizedTag = tag.trim();
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_:-]*$').hasMatch(normalizedTag)) {
      return const MetadataWriteResult(
        success: false,
        message: 'Nazwa tagu może zawierać tylko litery, cyfry, _, - oraz :.',
      );
    }
    if (value.isEmpty) {
      return const MetadataWriteResult(
        success: false,
        message: 'Wartość tagu nie może być pusta.',
      );
    }
    final executable = _executableFinder('exiftool');
    if (executable == null) {
      return const MetadataWriteResult(
        success: false,
        message: 'Nie znaleziono programu exiftool w PATH.',
      );
    }
    final backupPath = '${sourcePath}_original';
    final backupAlreadyExists = File(backupPath).existsSync();
    AppLogger.info(
      'ExifTool',
      'Zapisywanie tagu $normalizedTag; '
          'kopiaIstnieje=$backupAlreadyExists.',
    );
    try {
      final session = await processService.run(
        CommandDraft(
          executable: executable,
          arguments: [
            '-P',
            if (backupAlreadyExists) '-overwrite_original',
            '-$normalizedTag=$value',
            sourcePath,
          ],
          private: true,
        ),
      );
      if (session.exitCode != 0) {
        final error = session.stderr.trim().isNotEmpty
            ? session.stderr.trim()
            : session.stdout.trim();
        return MetadataWriteResult(
          success: false,
          message: error.isEmpty
              ? 'ExifTool zakończył działanie kodem ${session.exitCode}.'
              : error,
          backupPath: backupAlreadyExists ? backupPath : null,
        );
      }
      final backupCreated =
          backupAlreadyExists || File(backupPath).existsSync();
      AppLogger.info(
        'ExifTool',
        'Tag $normalizedTag został zapisany; kopia=$backupCreated.',
      );
      return MetadataWriteResult(
        success: true,
        message: session.stdout.trim(),
        backupPath: backupCreated ? backupPath : null,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'ExifTool',
        'Nie można zapisać tagu $normalizedTag',
        error,
        stackTrace,
      );
      return MetadataWriteResult(success: false, message: error.toString());
    }
  }
}

class MetadataWriteResult {
  const MetadataWriteResult({
    required this.success,
    required this.message,
    this.backupPath,
  });

  final bool success;
  final String message;
  final String? backupPath;
}

class _ExifToolResult {
  const _ExifToolResult({
    required this.state,
    this.metadata = const {},
    this.error,
  });

  final ExifToolState state;
  final Map<String, dynamic> metadata;
  final String? error;
}
