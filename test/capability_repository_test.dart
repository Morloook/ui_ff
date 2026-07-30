import 'dart:io';

import 'package:ffmpeg_ui/models/binary_installation.dart';
import 'package:ffmpeg_ui/models/capability.dart';
import 'package:ffmpeg_ui/services/capability_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporary;
  late CapabilityRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    temporary = await Directory.systemTemp.createTemp('ffmpeg_ui_catalog_');
    repository = CapabilityRepository(
      supportDirectoryProvider: () async => temporary,
      databaseFactory: databaseFactoryFfiNoIsolate,
    );
    await repository.initialize(
      openTimeout: const Duration(seconds: 2),
      useWorkerIsolate: false,
    );
  });

  tearDown(() async {
    await repository.close();
    await temporary.delete(recursive: true);
  });

  test('does not return an incomplete snapshot', () async {
    final snapshot = await _createSnapshot(repository, 'fingerprint-a');

    expect(await repository.findSnapshot(snapshot.fingerprint), isNull);
    await repository.markSnapshotComplete(snapshot.id);
    expect(
      (await repository.findSnapshot(snapshot.fingerprint))?.id,
      snapshot.id,
    );
  });

  test('stores, searches and reloads component option details', () async {
    final snapshot = await _createSnapshot(repository, 'fingerprint-a');
    final component = FfmpegComponent(
      id: null,
      kind: ComponentKind.encoder,
      name: 'libx264',
      description: 'H.264 encoder',
      flags: 'V',
      mediaType: MediaType.video,
      helpTarget: 'encoder=libx264',
      rawLine: ' V libx264 H.264 encoder',
      options: const [
        OptionDefinition(
          name: 'crf',
          valueType: 'float',
          flags: 'E..V',
          description: 'Quality',
          rawLine: '-crf <float>',
          defaultValue: '23',
        ),
      ],
    );

    await repository.addComponents(snapshot.id, [component]);
    final found = await repository.search(
      snapshotId: snapshot.id,
      query: 'x264',
      limit: 10,
    );
    expect(found.single.name, 'libx264');
    final loaded = await repository.loadComponent(found.single.id!);
    expect(loaded.options.single.name, 'crf');
    expect(loaded.options.single.defaultValue, '23');
  });

  test('replaces a stale snapshot for the same FFmpeg binary', () async {
    final first = await _createSnapshot(repository, 'fingerprint-old');
    await repository.markSnapshotComplete(first.id);
    final second = await _createSnapshot(repository, 'fingerprint-new');
    await repository.markSnapshotComplete(second.id);

    expect(await repository.findSnapshot('fingerprint-old'), isNull);
    expect(await repository.findSnapshot('fingerprint-new'), isNotNull);
  });

  test(
    'searches a large catalog by substring and applies the result limit',
    () async {
      final snapshot = await _createSnapshot(repository, 'fingerprint-large');
      final components = List.generate(2000, (index) {
        final target = index.isEven
            ? 'libx264_profile_$index'
            : 'component_$index';
        return FfmpegComponent(
          id: null,
          kind: ComponentKind.encoder,
          name: target,
          description: 'Synthetic catalog entry $index',
          flags: 'V',
          mediaType: MediaType.video,
          helpTarget: 'encoder=$target',
          rawLine: target,
        );
      });
      await repository.addComponents(snapshot.id, components);

      final stopwatch = Stopwatch()..start();
      final found = await repository.search(
        snapshotId: snapshot.id,
        query: 'x264',
        limit: 25,
      );
      stopwatch.stop();

      expect(found, hasLength(25));
      expect(
        found.every((component) => component.name.contains('x264')),
        isTrue,
      );
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    },
  );
}

Future<CapabilitySnapshot> _createSnapshot(
  CapabilityRepository repository,
  String fingerprint, {
  String ffmpegPath = '/usr/bin/ffmpeg',
}) {
  return repository.createSnapshot(
    fingerprint: fingerprint,
    ffmpeg: BinaryInstallation(
      kind: BinaryKind.ffmpeg,
      path: ffmpegPath,
      available: true,
      version: '8.1.2',
      configuration: '--enable-test',
    ),
    ffprobe: const BinaryInstallation(
      kind: BinaryKind.ffprobe,
      path: '/usr/bin/ffprobe',
      available: true,
      version: '8.1.2',
      configuration: '--enable-test',
    ),
  );
}
