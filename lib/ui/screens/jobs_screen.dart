import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../core/app_config.dart';
import '../../core/app_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/localized_text.dart';
import '../../models/command_models.dart';
import '../../services/job_queue_service.dart';
import '../../widgets/page_header.dart';

class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final queue = controller.jobQueue;
    return AnimatedBuilder(
      animation: queue,
      builder: (context, _) {
        final runningJob = queue.runningJob;
        return Column(
          children: [
            PageHeader(
              title: 'Kolejka zadań',
              subtitle:
                  'Oczekujące: ${queue.waitingCount}. '
                  'Dodanie zadania nie uruchamia go automatycznie.',
              actions: [
                OutlinedButton.icon(
                  onPressed: queue.jobs.isEmpty ? null : queue.removeFinished,
                  icon: const Icon(Icons.cleaning_services),
                  label: const Text('Usuń zakończone'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: queue.started
                      ? () => queue.setPaused(true)
                      : queue.waitingCount == 0
                      ? null
                      : queue.start,
                  icon: Icon(queue.started ? Icons.pause : Icons.play_arrow),
                  label: Text(
                    queue.started ? 'Wstrzymaj po bieżącym' : 'Uruchom kolejkę',
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  if (runningJob != null) ...[
                    _LiveJobConsole(
                      job: runningJob,
                      onStop: queue.cancelRunning,
                      characterLimit:
                          controller.options?.queueLiveLogCharacterLimit ??
                          AppConfig.queueLiveLogCharacterLimit,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (queue.jobs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 120),
                      child: Center(
                        child: Text(
                          'Kolejka jest pusta. Dodaj zadanie z kreatora.',
                        ),
                      ),
                    )
                  else
                    for (final job in queue.jobs)
                      _JobCard(
                        job: job,
                        queue: queue,
                        completedLogCharacterLimit:
                            controller
                                .options
                                ?.queueCompletedLogCharacterLimit ??
                            AppConfig.queueCompletedLogCharacterLimit,
                      ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.queue,
    required this.completedLogCharacterLimit,
  });

  final QueueJob job;
  final JobQueueService queue;
  final int completedLogCharacterLimit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: _StateIcon(state: job.state),
        title: Text(job.name),
        subtitle: Text(
          '${_stateLabel(job.state)}'
          '${job.state == QueueJobState.running ? ' · etap ${job.currentStepIndex + 1}/${job.workflow.steps.length}' : ''}'
          '\n${job.workflow.displayCommand}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (job.state == QueueJobState.running)
              IconButton(
                onPressed: queue.cancelRunning,
                tooltip: context.tr('Zatrzymaj'),
                icon: const Icon(Icons.stop),
              ),
            if ({
              QueueJobState.failed,
              QueueJobState.cancelled,
            }.contains(job.state))
              IconButton(
                onPressed: () => queue.retry(job),
                tooltip: context.tr('Ponów'),
                icon: const Icon(Icons.replay),
              ),
          ],
        ),
        children: [
          if (job.session != null)
            _CompletedJobReport(
              job: job,
              characterLimit: completedLogCharacterLimit,
            ),
        ],
      ),
    );
  }
}

class _LiveJobConsole extends StatelessWidget {
  const _LiveJobConsole({
    required this.job,
    required this.onStop,
    required this.characterLimit,
  });

  final QueueJob job;
  final VoidCallback onStop;
  final int characterLimit;

  @override
  Widget build(BuildContext context) {
    final output = _normalizeConsoleText(job.console);
    final visibleOutput = _limitedTail(output, characterLimit);
    final colors = Theme.of(context).colorScheme;

    return Card(
      color: colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bieżące zadanie: ${job.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop),
                  label: const Text('Zatrzymaj'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              'Etap ${job.currentStepIndex + 1}/${job.workflow.steps.length}: '
              '${job.currentStep.name}\n${job.command.displayCommand}',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 120, maxHeight: 260),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: SelectableText(
                  visibleOutput.isEmpty
                      ? 'Proces uruchomiony. Oczekiwanie na dane…'
                      : visibleOutput,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedJobReport extends StatelessWidget {
  const _CompletedJobReport({required this.job, required this.characterLimit});

  final QueueJob job;
  final int characterLimit;

  @override
  Widget build(BuildContext context) {
    final sessions = job.sessions.isEmpty
        ? [if (job.session != null) job.session!]
        : job.sessions;
    final colors = Theme.of(context).colorScheme;
    final fullLog = _buildFullLog(job, sessions);
    final duration = sessions.fold<Duration>(
      Duration.zero,
      (sum, session) => sum + session.duration,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Etapy: ${sessions.length}/${job.workflow.steps.length}'),
              Text('Czas: ${_formatDuration(duration)}'),
              Text(
                'Kod zakończenia: '
                '${sessions.lastOrNull?.exitCode?.toString() ?? 'brak'}',
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: fullLog));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Skopiowano pełny log zadania.'),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Kopiuj pełny log'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < sessions.length; index++) ...[
            _CompletedStepReport(
              index: index,
              total: job.workflow.steps.length,
              name: index < job.workflow.steps.length
                  ? job.workflow.steps[index].name
                  : 'Etap ${index + 1}',
              session: sessions[index],
              characterLimit: characterLimit,
            ),
            if (index + 1 < sessions.length) const SizedBox(height: 12),
          ],
          if (sessions.any(
            (session) => _usesErrorOnlyLogLevel(session.command),
          )) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'To polecenie używa „-loglevel error”. FFmpeg celowo ukrywa '
                'informacje o wejściu, mapowaniu i kodekach, dlatego w logu '
                'pozostają przede wszystkim błędy oraz wiersze postępu '
                'włączone opcją „-stats”.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompletedStepReport extends StatelessWidget {
  const _CompletedStepReport({
    required this.index,
    required this.total,
    required this.name,
    required this.session,
    required this.characterLimit,
  });

  final int index;
  final int total;
  final String name;
  final ProcessSession session;
  final int characterLimit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final output = _normalizeConsoleText(session.stdout);
    final errors = _normalizeConsoleText(session.stderr);
    final failure = session.error?.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Etap ${index + 1}/$total: $name',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Stan: ${session.exitCode == 0 ? 'sukces' : 'błąd'} · '
            'kod: ${session.exitCode?.toString() ?? 'brak'} · '
            'czas: ${_formatDuration(session.duration)}',
          ),
          const SizedBox(height: 10),
          const Text('Uruchomione polecenie:'),
          const SizedBox(height: 4),
          SelectableText(
            session.command.displayCommand,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 10),
          _OutputSection(
            title: 'stdout',
            text: output,
            emptyMessage: 'Proces nie zwrócił danych na stdout.',
            characterLimit: characterLimit,
          ),
          const SizedBox(height: 8),
          _OutputSection(
            title: 'stderr / postęp FFmpeg',
            text: errors,
            emptyMessage: 'Proces nie zwrócił danych na stderr.',
            characterLimit: characterLimit,
          ),
          if (failure.isNotEmpty) ...[
            const SizedBox(height: 8),
            _OutputSection(
              title: 'Błąd uruchomienia',
              text: failure,
              emptyMessage: '',
              characterLimit: characterLimit,
            ),
          ],
        ],
      ),
    );
  }
}

class _OutputSection extends StatelessWidget {
  const _OutputSection({
    required this.title,
    required this.text,
    required this.emptyMessage,
    required this.characterLimit,
  });

  final String title;
  final String text;
  final String emptyMessage;
  final int characterLimit;

  @override
  Widget build(BuildContext context) {
    final limited = _limitedTail(text, characterLimit);
    final truncated = text.length > characterLimit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 3),
        SelectableText(
          text.isEmpty ? emptyMessage : limited,
          style: TextStyle(
            fontFamily: 'monospace',
            color: text.isEmpty
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
          ),
        ),
        if (truncated)
          Text(
            'Widok pokazuje końcowe $characterLimit znaków. '
            'Przycisk „Kopiuj pełny log” kopiuje całość.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _StateIcon extends StatelessWidget {
  const _StateIcon({required this.state});
  final QueueJobState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      QueueJobState.waiting => const Icon(Icons.schedule),
      QueueJobState.running => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      QueueJobState.completed => const Icon(
        Icons.check_circle,
        color: Colors.green,
      ),
      QueueJobState.failed => Icon(
        Icons.error,
        color: Theme.of(context).colorScheme.error,
      ),
      QueueJobState.cancelled => const Icon(Icons.cancel),
    };
  }
}

String _stateLabel(QueueJobState state) => switch (state) {
  QueueJobState.waiting => 'Oczekuje na uruchomienie',
  QueueJobState.running => 'W trakcie',
  QueueJobState.completed => 'Zakończono poprawnie',
  QueueJobState.failed => 'Błąd',
  QueueJobState.cancelled => 'Anulowano',
};

String _normalizeConsoleText(String value) =>
    value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

String _limitedTail(String value, int limit) => value.length > limit
    ? '…\n${value.substring(value.length - limit)}'
    : value;

bool _usesErrorOnlyLogLevel(CommandDraft command) {
  final arguments = command.arguments;
  for (var index = 0; index + 1 < arguments.length; index++) {
    if ({'-loglevel', '-v'}.contains(arguments[index]) &&
        {'error', 'fatal', 'quiet'}.contains(arguments[index + 1])) {
      return true;
    }
  }
  return false;
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  final milliseconds = duration.inMilliseconds.remainder(1000);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}.'
      '${milliseconds.toString().padLeft(3, '0')}';
}

String _buildFullLog(QueueJob job, List<ProcessSession> sessions) {
  final buffer = StringBuffer()
    ..writeln('Zadanie: ${job.name}')
    ..writeln('Stan: ${_stateLabel(job.state)}');
  for (var index = 0; index < sessions.length; index++) {
    final session = sessions[index];
    final name = index < job.workflow.steps.length
        ? job.workflow.steps[index].name
        : 'Etap ${index + 1}';
    buffer
      ..writeln()
      ..writeln('=== ${index + 1}/${job.workflow.steps.length}: $name ===')
      ..writeln('Polecenie: ${session.command.displayCommand}')
      ..writeln('Start: ${session.startedAt.toIso8601String()}')
      ..writeln('Koniec: ${session.finishedAt?.toIso8601String() ?? 'brak'}')
      ..writeln('Czas: ${_formatDuration(session.duration)}')
      ..writeln('Kod zakończenia: ${session.exitCode ?? 'brak'}')
      ..writeln()
      ..writeln('[stdout]')
      ..writeln(session.stdout.isEmpty ? '(brak danych)' : session.stdout)
      ..writeln('[stderr / postęp FFmpeg]')
      ..writeln(session.stderr.isEmpty ? '(brak danych)' : session.stderr);
    if (session.error?.isNotEmpty == true) {
      buffer
        ..writeln('[błąd uruchomienia]')
        ..writeln(session.error);
    }
  }
  return buffer.toString();
}
