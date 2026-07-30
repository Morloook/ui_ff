import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/binary_installation.dart';
import '../models/capability.dart';
import '../models/command_models.dart';
import '../models/app_options.dart';
import '../models/script_models.dart';
import 'app_logger.dart';
import '../services/binary_service.dart';
import '../services/capability_repository.dart';
import '../services/capability_service.dart';
import '../services/command_builder_service.dart';
import '../services/help_parser.dart';
import '../services/job_queue_service.dart';
import '../services/probe_service.dart';
import '../services/process_service.dart';
import '../services/script_import_service.dart';
import '../services/script_workflow_service.dart';
import '../services/settings_service.dart';

class AppController extends ChangeNotifier {
  AppController()
    : binaryService = BinaryService(),
      repository = CapabilityRepository(),
      processService = ProcessService(),
      settingsService = SettingsService(),
      parser = HelpParser(),
      scriptImportService = const ScriptImportService(),
      commandBuilderService = const CommandBuilderService() {
    capabilityService = CapabilityService(
      binaryService: binaryService,
      repository: repository,
      processService: processService,
      parser: parser,
    );
    probeService = ProbeService(processService);
    scriptWorkflowService = ScriptWorkflowService(processService);
  }

  final BinaryService binaryService;
  final CapabilityRepository repository;
  final ProcessService processService;
  final SettingsService settingsService;
  final HelpParser parser;
  final ScriptImportService scriptImportService;
  final CommandBuilderService commandBuilderService;
  late final CapabilityService capabilityService;
  late final ProbeService probeService;
  late final ScriptWorkflowService scriptWorkflowService;
  late final JobQueueService jobQueue;
  bool _jobQueueInitialized = false;

  bool initializing = true;
  String? initializationError;
  String? startupNotice;
  List<ImportedScript> scripts = const [];
  bool scriptsScanning = false;
  String? scriptsError;
  List<String> scriptDirectories = const [];
  List<BinaryInstallation> installations = const [];
  CapabilitySnapshot? snapshot;
  ScanProgress? scanProgress;
  String? scanError;
  StreamSubscription<ScanProgress>? _scanSubscription;
  Completer<void>? _scanDone;
  String terminalSeed = '';
  BinaryKind terminalSeedKind = BinaryKind.ffmpeg;
  int terminalSeedVersion = 0;
  int interfaceRevision = 0;
  AppOptions? options;
  Future<void>? _shutdownFuture;
  bool _shutdownRequested = false;
  bool _disposed = false;

  BinaryInstallation? get ffmpeg => _installation(BinaryKind.ffmpeg);
  BinaryInstallation? get ffprobe => _installation(BinaryKind.ffprobe);
  bool get scanning => _scanSubscription != null;

  Future<void> initialize() async {
    AppLogger.info('AppController', 'Rozpoczęcie inicjalizacji.');
    initializing = true;
    initializationError = null;
    _notifyListeners();
    try {
      options = await settingsService.load();
      startupNotice = settingsService.recoveryNotice;
      if (_shutdownRequested) return;
      AppLogger.info('AppController', 'Wczytano i zwalidowano ustawienia.');
      _updateScriptDirectories();
      await refreshScripts();
      if (_shutdownRequested) return;
      jobQueue = JobQueueService(
        processService,
        paused: options!.queuePausedOnStart,
      );
      _jobQueueInitialized = true;
      await repository.initialize(
        openTimeout: Duration(seconds: options!.databaseOpenTimeoutSeconds),
        useWorkerIsolate:
            !kDebugMode || options!.databaseUseWorkerIsolateInDebug,
      );
      if (_shutdownRequested) return;
      AppLogger.info('AppController', 'Repozytorium katalogu jest gotowe.');
      installations = await binaryService.detect(
        ffmpegOverride: options!.ffmpegPath,
        ffprobeOverride: options!.ffprobePath,
      );
      if (_shutdownRequested) return;
      final installedFfmpeg = ffmpeg;
      final installedFfprobe = ffprobe;
      AppLogger.info(
        'AppController',
        'Wykrywanie binariów zakończone: '
            'ffmpeg=${installedFfmpeg?.available == true}, '
            'ffprobe=${installedFfprobe?.available == true}.',
      );
      if (installedFfmpeg?.available == true &&
          installedFfprobe?.available == true) {
        snapshot = await capabilityService.cachedSnapshot(
          installedFfmpeg!,
          installedFfprobe!,
        );
        if (snapshot == null && options!.autoScanOnStart) {
          AppLogger.info(
            'AppController',
            'Brak aktualnego cache. Uruchamiam automatyczny skan.',
          );
          await scanCapabilities();
        } else if (snapshot != null) {
          AppLogger.info(
            'AppController',
            'Wczytano snapshot katalogu ${snapshot!.id}.',
          );
        }
      }
    } on Object catch (error, stackTrace) {
      initializationError = error.toString();
      AppLogger.error(
        'AppController',
        'Inicjalizacja nie powiodła się',
        error,
        stackTrace,
      );
    } finally {
      initializing = false;
      _notifyListeners();
      AppLogger.info(
        'AppController',
        initializationError == null
            ? 'Inicjalizacja zakończona poprawnie.'
            : 'Inicjalizacja zakończona błędem.',
      );
    }
  }

  Future<void> detectBinaries({
    String? ffmpegPath,
    String? ffprobePath,
    bool save = true,
  }) async {
    AppLogger.info('AppController', 'Ponowne wykrywanie binariów.');
    if (save) {
      await updateOption(['binaries', 'ffmpegPath'], ffmpegPath ?? '');
      await updateOption(['binaries', 'ffprobePath'], ffprobePath ?? '');
    }
    installations = await binaryService.detect(
      ffmpegOverride: ffmpegPath,
      ffprobeOverride: ffprobePath,
    );
    snapshot = null;
    scanProgress = null;
    scanError = null;
    final installedFfmpeg = ffmpeg;
    final installedFfprobe = ffprobe;
    if (installedFfmpeg?.available == true &&
        installedFfprobe?.available == true) {
      snapshot = await capabilityService.cachedSnapshot(
        installedFfmpeg!,
        installedFfprobe!,
      );
    }
    _notifyListeners();
  }

  Future<void> refreshScripts() async {
    _updateScriptDirectories();
    scriptsScanning = true;
    scriptsError = null;
    _notifyListeners();
    try {
      scripts = await scriptImportService.scan(
        configuredDirectory: options?.scriptsDirectoryPath,
      );
    } on Object catch (error, stackTrace) {
      scriptsError = error.toString();
      AppLogger.error(
        'Scripts',
        'Skanowanie katalogu skryptów nie powiodło się',
        error,
        stackTrace,
      );
    } finally {
      scriptsScanning = false;
      _notifyListeners();
    }
  }

  Future<void> scanCapabilities() async {
    if (scanning) {
      AppLogger.warning('Catalog', 'Pominięto równoległe żądanie skanu.');
      return;
    }
    final installedFfmpeg = ffmpeg;
    final installedFfprobe = ffprobe;
    if (installedFfmpeg?.available != true ||
        installedFfprobe?.available != true) {
      scanError = 'FFmpeg i FFprobe muszą być dostępne.';
      AppLogger.warning('Catalog', scanError!);
      _notifyListeners();
      return;
    }
    scanError = null;
    AppLogger.info('Catalog', 'Rozpoczęcie skanowania możliwości.');
    scanProgress = const ScanProgress(
      completed: 0,
      total: 1,
      label: 'Przygotowanie skanowania…',
    );
    _notifyListeners();
    final stream = capabilityService.scan(
      ffmpeg: installedFfmpeg!,
      ffprobe: installedFfprobe!,
      onSnapshot: (value) {
        snapshot = value;
        _notifyListeners();
      },
    );
    final done = Completer<void>();
    _scanDone = done;
    void finishScanWait() {
      if (!done.isCompleted) done.complete();
      if (identical(_scanDone, done)) _scanDone = null;
    }

    _scanSubscription = stream.listen(
      (progress) {
        scanProgress = progress;
        _notifyListeners();
      },
      onError: (Object error) {
        scanError = error.toString();
        AppLogger.error('Catalog', 'Skan zakończony błędem', error);
        _scanSubscription = null;
        _notifyListeners();
        finishScanWait();
      },
      onDone: () {
        _scanSubscription = null;
        AppLogger.info('Catalog', 'Strumień skanowania został zamknięty.');
        _notifyListeners();
        finishScanWait();
      },
    );
    await done.future;
  }

  Future<List<FfmpegComponent>> searchCapabilities({
    String query = '',
    ComponentKind? kind,
    MediaType? mediaType,
  }) async {
    final active = snapshot;
    if (active == null) return const [];
    return repository.search(
      snapshotId: active.id,
      query: query,
      kind: kind,
      mediaType: mediaType,
      limit: options!.catalogSearchLimit,
    );
  }

  Future<Map<ComponentKind, int>> capabilityCounts() {
    final active = snapshot;
    if (active == null) return Future.value(const {});
    return repository.counts(active.id);
  }

  Future<List<FfmpegComponent>> commandOptions() {
    final active = snapshot;
    if (active == null) return Future.value(const []);
    return repository.commandOptions(active.id);
  }

  Future<FfmpegComponent> loadComponentDetails(
    FfmpegComponent component,
  ) async {
    final installed = ffmpeg;
    if (installed?.available != true) return component;
    return capabilityService.loadDetails(
      component: component,
      ffmpeg: installed!,
    );
  }

  void sendToTerminal({
    required BinaryKind kind,
    required List<String> arguments,
  }) {
    terminalSeedKind = kind;
    terminalSeed = arguments
        .map((argument) => CommandDraft.quoteArgument(argument))
        .join(' ');
    terminalSeedVersion++;
    _notifyListeners();
  }

  Future<void> updateOption(List<String> path, Object? value) async {
    options = await settingsService.setValue(path, value);
    AppLogger.info('Settings', 'Zapisano zmianę opcji: ${path.join('.')}.');
    if (path.length == 2 &&
        path[0] == 'scripts' &&
        path[1] == 'directoryPath') {
      await refreshScripts();
      return;
    }
    _notifyListeners();
  }

  Future<void> updateOptionsSection(
    String section,
    Map<String, Object?> values,
  ) async {
    options = await settingsService.setSection(section, values);
    AppLogger.info('Settings', 'Zapisano sekcję ustawień: $section.');
    _notifyListeners();
  }

  Future<void> restoreDefaultOptions() async {
    AppLogger.info('Settings', 'Rozpoczęcie przywracania ustawień domyślnych.');
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    final scanDone = _scanDone;
    if (scanDone != null && !scanDone.isCompleted) scanDone.complete();
    _scanDone = null;

    options = await settingsService.restoreDefaults();
    _updateScriptDirectories();
    await refreshScripts();
    if (_jobQueueInitialized) {
      jobQueue.setPaused(options!.queuePausedOnStart);
    }
    await detectBinaries(
      ffmpegPath: options!.ffmpegPath,
      ffprobePath: options!.ffprobePath,
      save: false,
    );
    terminalSeed = '';
    terminalSeedKind = options!.terminalDefaultBinary == BinaryKind.ffprobe.name
        ? BinaryKind.ffprobe
        : BinaryKind.ffmpeg;
    terminalSeedVersion++;
    interfaceRevision++;
    AppLogger.info(
      'Settings',
      'Przywrócono ustawienia domyślne i odświeżono interfejs.',
    );
    _notifyListeners();
  }

  Future<void> shutdown() {
    _shutdownRequested = true;
    return _shutdownFuture ??= _performShutdown();
  }

  Future<void> _performShutdown() async {
    AppLogger.info('Lifecycle', 'Rozpoczęcie poprawnego zamykania usług.');
    if (_jobQueueInitialized) {
      jobQueue.cancelRunning();
    }
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    final scanDone = _scanDone;
    if (scanDone != null && !scanDone.isCompleted) scanDone.complete();
    _scanDone = null;
    await processService.shutdown();
    await repository.close();
    AppLogger.info('Lifecycle', 'Wszystkie usługi zostały zamknięte.');
  }

  BinaryInstallation? _installation(BinaryKind kind) {
    for (final installation in installations) {
      if (installation.kind == kind) return installation;
    }
    return null;
  }

  void _updateScriptDirectories() {
    scriptDirectories = [
      scriptImportService.expectedScriptsDirectory(
        configuredDirectory: options?.scriptsDirectoryPath,
      ),
    ];
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    unawaited(shutdown());
    if (_jobQueueInitialized) jobQueue.dispose();
    AppLogger.info('AppController', 'Zwolniono kontroler aplikacji.');
    _disposed = true;
    super.dispose();
  }
}
