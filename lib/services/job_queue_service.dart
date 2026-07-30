import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/app_logger.dart';
import '../models/command_models.dart';
import '../models/workflow_models.dart';
import 'ffmpeg_progress_service.dart';
import 'process_service.dart';

enum QueueJobState { waiting, running, completed, failed, cancelled }

class QueueJob {
  QueueJob({
    required this.id,
    required this.name,
    required this.workflow,
    this.state = QueueJobState.waiting,
    this.session,
  });

  final String id;
  final String name;
  final WorkflowDraft workflow;
  QueueJobState state;
  ProcessSession? session;
  final List<ProcessSession> sessions = [];
  int currentStepIndex = 0;
  DateTime? startedAt;
  CommandDraft? activeCommand;
  FfmpegProgress? progress;
  bool usesStructuredProgress = false;
  final StringBuffer _stdout = StringBuffer();
  final StringBuffer _stderr = StringBuffer();
  final StringBuffer _console = StringBuffer();

  CommandDraft get command => workflow.steps[currentStepIndex].command;
  CommandDraft get displayedCommand => activeCommand ?? command;
  WorkflowStep get currentStep => workflow.steps[currentStepIndex];
  String get stdout => _stdout.toString();
  String get stderr => _stderr.toString();
  String get console => _console.toString();

  void appendOutput(ProcessOutputEvent event) {
    (event.isStdErr ? _stderr : _stdout).write(event.text);
    _console.write(event.text);
  }

  void beginStep() {
    final header =
        '\n=== ${currentStepIndex + 1}/${workflow.steps.length}: '
        '${currentStep.name} ===\n';
    _stdout.write(header);
    _console.write(header);
  }
}

class JobQueueService extends ChangeNotifier {
  JobQueueService(this.processService, {required this.paused});
  final ProcessService processService;
  final List<QueueJob> jobs = [];
  bool paused;
  RunningCommand? _running;
  QueueJob? _runningJob;
  bool _started = false;
  bool _cancelRequested = false;
  int _sequence = 0;
  Timer? _outputNotification;

  bool get started => _started;
  QueueJob? get runningJob => _runningJob;
  int get waitingCount =>
      jobs.where((job) => job.state == QueueJobState.waiting).length;

  void add(String name, CommandDraft command) {
    addWorkflow(
      WorkflowDraft(
        name: name,
        steps: [WorkflowStep(name: 'Polecenie', command: command)],
      ),
    );
  }

  void addWorkflow(WorkflowDraft workflow) {
    jobs.add(
      QueueJob(
        id: '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
        name: workflow.name,
        workflow: workflow,
      ),
    );
    AppLogger.info('Queue', 'Dodano zadanie; oczekujące=${jobs.length}.');
    notifyListeners();
  }

  void start() {
    if (_started || waitingCount == 0) return;
    paused = false;
    _started = true;
    AppLogger.info('Queue', 'Uruchomiono kolejkę; oczekujące=$waitingCount.');
    notifyListeners();
    unawaited(_pump());
  }

  void setPaused(bool value) {
    paused = value;
    _started = !value && waitingCount > 0;
    AppLogger.info(
      'Queue',
      value
          ? 'Kolejka zostanie wstrzymana po bieżącym zadaniu.'
          : 'Kolejka została uruchomiona.',
    );
    notifyListeners();
    if (_started) unawaited(_pump());
  }

  void retry(QueueJob job) {
    job.state = QueueJobState.waiting;
    job.session = null;
    job.sessions.clear();
    job.currentStepIndex = 0;
    job.startedAt = null;
    job.activeCommand = null;
    job.progress = null;
    job.usesStructuredProgress = false;
    job._stdout.clear();
    job._stderr.clear();
    job._console.clear();
    AppLogger.info('Queue', 'Zadanie ${job.id} skierowane do ponowienia.');
    notifyListeners();
  }

  void cancelRunning() {
    _cancelRequested = true;
    paused = true;
    _started = false;
    AppLogger.info('Queue', 'Zażądano zatrzymania aktywnego zadania.');
    notifyListeners();
    _running?.cancel();
  }

  void removeFinished() {
    jobs.removeWhere(
      (job) => {
        QueueJobState.completed,
        QueueJobState.failed,
        QueueJobState.cancelled,
      }.contains(job.state),
    );
    notifyListeners();
  }

  Future<void> _pump() async {
    if (paused || !_started || _running != null) return;
    final pending = jobs.where((job) => job.state == QueueJobState.waiting);
    if (pending.isEmpty) {
      _started = false;
      notifyListeners();
      return;
    }
    final job = pending.first;
    job.state = QueueJobState.running;
    job.startedAt = DateTime.now();
    _runningJob = job;
    AppLogger.info('Queue', 'Uruchamianie zadania ${job.id}.');
    notifyListeners();
    try {
      _cancelRequested = false;
      for (var index = 0; index < job.workflow.steps.length; index++) {
        if (_cancelRequested) break;
        job.currentStepIndex = index;
        job.beginStep();
        notifyListeners();
        final prepared = QueueFfmpegProgressCommand.prepare(job.command);
        final progressParser = prepared.usesStructuredProgress
            ? FfmpegProgressParser()
            : null;
        job
          ..activeCommand = prepared.command
          ..progress = null
          ..usesStructuredProgress = prepared.usesStructuredProgress;
        _running = await processService.start(prepared.command);
        if (_cancelRequested) _running!.cancel();
        _running!.output.listen((event) {
          if (!event.isStdErr && progressParser != null) {
            final updates = progressParser.addChunk(event.text);
            if (updates.isNotEmpty) job.progress = updates.last;
          }
          job.appendOutput(event);
          _scheduleOutputNotification();
        });
        final session = await _running!.completed;
        job.session = session;
        job.sessions.add(session);
        _running = null;
        job.activeCommand = null;
        if (_cancelRequested || session.exitCode != 0) break;
      }
      job.state = _cancelRequested
          ? QueueJobState.cancelled
          : job.sessions.length == job.workflow.steps.length &&
                job.sessions.every((session) => session.exitCode == 0)
          ? QueueJobState.completed
          : QueueJobState.failed;
      AppLogger.info(
        'Queue',
        'Zadanie ${job.id} zakończone stanem ${job.state.name}.',
      );
    } on Object catch (error) {
      AppLogger.error('Queue', 'Błąd zadania ${job.id}', error);
      job.state = QueueJobState.failed;
      job.session = ProcessSession(
        id: job.id,
        command: job.command,
        state: ProcessState.failed,
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
        error: error.toString(),
      );
    } finally {
      _outputNotification?.cancel();
      _outputNotification = null;
      _running = null;
      _runningJob = null;
      _cancelRequested = false;
      notifyListeners();
      unawaited(_pump());
    }
  }

  void _scheduleOutputNotification() {
    if (_outputNotification != null) return;
    _outputNotification = Timer(const Duration(milliseconds: 100), () {
      _outputNotification = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _outputNotification?.cancel();
    super.dispose();
  }
}
