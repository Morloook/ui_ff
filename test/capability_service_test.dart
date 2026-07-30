import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_ui/models/binary_installation.dart';
import 'package:ffmpeg_ui/models/command_models.dart';
import 'package:ffmpeg_ui/models/capability.dart';
import 'package:ffmpeg_ui/services/binary_service.dart';
import 'package:ffmpeg_ui/services/capability_repository.dart';
import 'package:ffmpeg_ui/services/capability_service.dart';
import 'package:ffmpeg_ui/services/help_parser.dart';
import 'package:ffmpeg_ui/services/process_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('creates a complete snapshot and reuses it from cache', () async {
    if (!File('/usr/bin/printf').existsSync()) return;
    sqfliteFfiInit();
    final temporary = await Directory.systemTemp.createTemp('ffmpeg_ui_scan_');
    final repository = CapabilityRepository(
      supportDirectoryProvider: () async => temporary,
      databaseFactory: databaseFactoryFfiNoIsolate,
    );
    final processService = ProcessService();
    addTearDown(() async {
      await processService.shutdown();
      await repository.close();
      await temporary.delete(recursive: true);
    });
    await repository.initialize(
      openTimeout: const Duration(seconds: 2),
      useWorkerIsolate: false,
    );
    final service = CapabilityService(
      binaryService: BinaryService(),
      repository: repository,
      processService: processService,
      parser: const HelpParser(),
    );
    const ffmpeg = BinaryInstallation(
      kind: BinaryKind.ffmpeg,
      path: '/usr/bin/printf',
      available: true,
      version: 'test',
      configuration: 'test',
    );
    const ffprobe = BinaryInstallation(
      kind: BinaryKind.ffprobe,
      path: '/usr/bin/printf',
      available: true,
      version: 'test',
      configuration: 'test',
    );
    var callbackCount = 0;
    final first = await service
        .scan(
          ffmpeg: ffmpeg,
          ffprobe: ffprobe,
          onSnapshot: (_) => callbackCount++,
        )
        .toList();

    expect(first.last.completed, greaterThan(1));
    expect(callbackCount, 1);
    expect(await service.cachedSnapshot(ffmpeg, ffprobe), isNotNull);

    final cached = await service
        .scan(
          ffmpeg: ffmpeg,
          ffprobe: ffprobe,
          onSnapshot: (_) => callbackCount++,
        )
        .toList();
    expect(cached, hasLength(1));
    expect(cached.single.total, 1);
    expect(callbackCount, 2);
  });

  test('stores a section error and still completes the snapshot', () async {
    final fixture = await _fixture(_FailingProcessService());
    addTearDown(fixture.dispose);
    final snapshots = <CapabilitySnapshot>[];
    await fixture.service
        .scan(ffmpeg: _ffmpeg, ffprobe: _ffprobe, onSnapshot: snapshots.add)
        .toList();

    expect(
      await fixture.repository.rawScanError(
        snapshotId: snapshots.single.id,
        section: 'encoders',
      ),
      'Kod 9',
    );
    expect(await fixture.service.cachedSnapshot(_ffmpeg, _ffprobe), isNotNull);
  });

  test(
    'cancels a scan before an incomplete snapshot reaches the cache',
    () async {
      final runner = _SlowProcessService();
      final fixture = await _fixture(runner);
      addTearDown(fixture.dispose);
      final firstProgress = Completer<void>();
      final subscription = fixture.service
          .scan(ffmpeg: _ffmpeg, ffprobe: _ffprobe, onSnapshot: (_) {})
          .listen((_) => firstProgress.complete());
      await firstProgress.future;
      final cancellation = subscription.cancel();
      runner.release();
      await cancellation;

      expect(await fixture.service.cachedSnapshot(_ffmpeg, _ffprobe), isNull);
    },
  );
}

const _ffmpeg = BinaryInstallation(
  kind: BinaryKind.ffmpeg,
  path: 'ffmpeg',
  available: true,
  version: 'test',
  configuration: 'test',
);
const _ffprobe = BinaryInstallation(
  kind: BinaryKind.ffprobe,
  path: 'ffprobe',
  available: true,
  version: 'test',
  configuration: 'test',
);

class _FailingProcessService extends ProcessService {
  @override
  Future<ProcessSession> run(CommandDraft draft) async => ProcessSession(
    id: 'test',
    command: draft,
    state: ProcessState.failed,
    startedAt: DateTime.now(),
    finishedAt: DateTime.now(),
    exitCode: 9,
    stderr: 'failed',
  );
}

class _SlowProcessService extends ProcessService {
  final _release = Completer<void>();
  void release() => _release.complete();

  @override
  Future<ProcessSession> run(CommandDraft draft) async {
    await _release.future;
    return ProcessSession(
      id: 'slow',
      command: draft,
      state: ProcessState.completed,
      startedAt: DateTime.now(),
      finishedAt: DateTime.now(),
      exitCode: 0,
    );
  }
}

class _Fixture {
  _Fixture(this.repository, this.service, this.directory);
  final CapabilityRepository repository;
  final CapabilityService service;
  final Directory directory;
  Future<void> dispose() async {
    await repository.close();
    await directory.delete(recursive: true);
  }
}

Future<_Fixture> _fixture(ProcessService processService) async {
  sqfliteFfiInit();
  final directory = await Directory.systemTemp.createTemp(
    'ffmpeg_ui_capability_',
  );
  final repository = CapabilityRepository(
    supportDirectoryProvider: () async => directory,
    databaseFactory: databaseFactoryFfiNoIsolate,
  );
  await repository.initialize(
    openTimeout: const Duration(seconds: 2),
    useWorkerIsolate: false,
  );
  return _Fixture(
    repository,
    CapabilityService(
      binaryService: BinaryService(),
      repository: repository,
      processService: processService,
      parser: const HelpParser(),
    ),
    directory,
  );
}
