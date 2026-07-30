import 'dart:async';

import '../core/app_logger.dart';
import '../models/binary_installation.dart';
import '../models/capability.dart';
import '../models/command_models.dart';
import 'binary_service.dart';
import 'capability_repository.dart';
import 'help_parser.dart';
import 'process_service.dart';

class CapabilityService {
  CapabilityService({
    required this.binaryService,
    required this.repository,
    required this.processService,
    required this.parser,
  });

  final BinaryService binaryService;
  final CapabilityRepository repository;
  final ProcessService processService;
  final HelpParser parser;

  static const _sections = <_ScanSection>[
    _ScanSection('ffmpeg-help', ComponentKind.globalOption, [
      '-hide_banner',
      '-h',
      'full',
    ], options: true),
    _ScanSection(
      'ffprobe-help',
      ComponentKind.probeOption,
      ['-hide_banner', '-h', 'full'],
      options: true,
      probe: true,
    ),
    _ScanSection('encoders', ComponentKind.encoder, [
      '-hide_banner',
      '-encoders',
    ]),
    _ScanSection('decoders', ComponentKind.decoder, [
      '-hide_banner',
      '-decoders',
    ]),
    _ScanSection('filters', ComponentKind.filter, ['-hide_banner', '-filters']),
    _ScanSection('formats', ComponentKind.format, ['-hide_banner', '-formats']),
    _ScanSection('devices', ComponentKind.device, ['-hide_banner', '-devices']),
    _ScanSection('protocols', ComponentKind.protocol, [
      '-hide_banner',
      '-protocols',
    ]),
    _ScanSection('bsfs', ComponentKind.bitstreamFilter, [
      '-hide_banner',
      '-bsfs',
    ]),
    _ScanSection('hwaccels', ComponentKind.hardwareAcceleration, [
      '-hide_banner',
      '-hwaccels',
    ]),
    _ScanSection('pix_fmts', ComponentKind.pixelFormat, [
      '-hide_banner',
      '-pix_fmts',
    ]),
    _ScanSection('sample_fmts', ComponentKind.sampleFormat, [
      '-hide_banner',
      '-sample_fmts',
    ]),
    _ScanSection('layouts', ComponentKind.channelLayout, [
      '-hide_banner',
      '-layouts',
    ]),
    _ScanSection('codecs', ComponentKind.codec, ['-hide_banner', '-codecs']),
    _ScanSection('dispositions', ComponentKind.disposition, [
      '-hide_banner',
      '-dispositions',
    ]),
    _ScanSection('colors', ComponentKind.color, ['-hide_banner', '-colors']),
  ];

  Future<CapabilitySnapshot?> cachedSnapshot(
    BinaryInstallation ffmpeg,
    BinaryInstallation ffprobe,
  ) async {
    return repository.findSnapshot(
      binaryService.fingerprintAll([ffmpeg, ffprobe]),
    );
  }

  Stream<ScanProgress> scan({
    required BinaryInstallation ffmpeg,
    required BinaryInstallation ffprobe,
    required void Function(CapabilitySnapshot snapshot) onSnapshot,
  }) {
    final controller = StreamController<ScanProgress>();
    final workerDone = Completer<void>();
    var cancelled = false;
    controller.onCancel = () async {
      cancelled = true;
      AppLogger.info('Catalog', 'Anulowanie aktywnego skanu.');
      await workerDone.future;
    };
    () async {
      CapabilitySnapshot? snapshot;
      try {
        if (cancelled) return;
        final fingerprint = binaryService.fingerprintAll([ffmpeg, ffprobe]);
        AppLogger.info('Catalog', 'Sprawdzanie cache możliwości.');
        snapshot = await repository.findSnapshot(fingerprint);
        if (snapshot != null) {
          AppLogger.info(
            'Catalog',
            'Znaleziono gotowy snapshot ${snapshot.id}.',
          );
          onSnapshot(snapshot);
          controller.add(
            const ScanProgress(
              completed: 1,
              total: 1,
              label: 'Wczytano aktualny katalog z pamięci.',
            ),
          );
          return;
        }
        snapshot = await repository.createSnapshot(
          fingerprint: fingerprint,
          ffmpeg: ffmpeg,
          ffprobe: ffprobe,
        );
        onSnapshot(snapshot);
        AppLogger.info(
          'Catalog',
          'Utworzono snapshot ${snapshot.id}; rozpoczynam pełny skan.',
        );

        for (var index = 0; index < _sections.length; index++) {
          if (cancelled) return;
          final section = _sections[index];
          AppLogger.info(
            'Catalog',
            'Skan sekcji ${index + 1}/${_sections.length}: ${section.key}.',
          );
          controller.add(
            ScanProgress(
              completed: index,
              total: _sections.length,
              label: 'Skanowanie: ${section.kind.label}',
            ),
          );
          final installation = section.probe ? ffprobe : ffmpeg;
          if (!installation.available) {
            await repository.storeRawScan(
              snapshotId: snapshot.id,
              section: section.key,
              content: '',
              error: '${installation.executableName} jest niedostępny.',
            );
            continue;
          }
          final session = await processService.run(
            CommandDraft(
              executable: installation.path,
              arguments: section.arguments,
            ),
          );
          if (cancelled) return;
          final raw = '${session.stdout}\n${session.stderr}'.trim();
          await repository.storeRawScan(
            snapshotId: snapshot.id,
            section: section.key,
            content: raw,
            error: session.exitCode == 0 ? null : 'Kod ${session.exitCode}',
          );
          final components = section.options
              ? parser.parseGlobalOptions(raw, section.kind)
              : parser.parseListing(raw, section.kind);
          await repository.addComponents(snapshot.id, components);
          if (cancelled) return;
          AppLogger.info(
            'Catalog',
            'Sekcja ${section.key}: zapisano ${components.length} elementów.',
          );
        }
        if (cancelled) return;
        await repository.markSnapshotComplete(snapshot.id);
        AppLogger.info(
          'Catalog',
          'Snapshot ${snapshot.id} oznaczony jako kompletny.',
        );
        controller.add(
          ScanProgress(
            completed: _sections.length,
            total: _sections.length,
            label: 'Katalog jest gotowy.',
          ),
        );
      } on Object catch (error, stackTrace) {
        if (!cancelled) {
          AppLogger.error(
            'Catalog',
            'Pełny skan zakończony błędem',
            error,
            stackTrace,
          );
          controller.addError(error, stackTrace);
        }
      } finally {
        await controller.close();
        if (!workerDone.isCompleted) workerDone.complete();
      }
    }();
    return controller.stream;
  }

  Future<FfmpegComponent> loadDetails({
    required FfmpegComponent component,
    required BinaryInstallation ffmpeg,
  }) async {
    final id = component.id;
    if (id == null) return component;
    final stored = await repository.loadComponent(id);
    if (stored.detailsLoaded || stored.helpTarget.isEmpty) return stored;
    AppLogger.info(
      'Catalog',
      'Pobieranie szczegółów ${stored.kind.storageKey}:${stored.name}.',
    );
    final session = await processService.run(
      CommandDraft(
        executable: ffmpeg.path,
        arguments: ['-hide_banner', '-h', stored.helpTarget],
      ),
    );
    final raw = '${session.stdout}\n${session.stderr}'.trim();
    final parsed = parser.parseOptions(raw);
    await repository.saveDetails(
      id,
      HelpParseResultData(rawHelp: raw, options: parsed.options),
    );
    AppLogger.info(
      'Catalog',
      'Zapisano ${parsed.options.length} opcji szczegółowych.',
    );
    return repository.loadComponent(id);
  }
}

class _ScanSection {
  const _ScanSection(
    this.key,
    this.kind,
    this.arguments, {
    this.options = false,
    this.probe = false,
  });

  final String key;
  final ComponentKind kind;
  final List<String> arguments;
  final bool options;
  final bool probe;
}
