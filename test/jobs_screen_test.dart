import 'package:ffmpeg_ui/core/app_config.dart';
import 'package:ffmpeg_ui/core/app_controller.dart';
import 'package:ffmpeg_ui/models/app_options.dart';
import 'package:ffmpeg_ui/models/command_models.dart';
import 'package:ffmpeg_ui/services/job_queue_service.dart';
import 'package:ffmpeg_ui/services/process_service.dart';
import 'package:ffmpeg_ui/ui/screens/jobs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('jobs screen renders an empty paused queue', (tester) async {
    final controller = AppController()
      ..options = AppOptions.fromJson(
        Map<String, dynamic>.from(AppConfig.defaults),
      )
      ..jobQueue = JobQueueService(ProcessService(), paused: true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: JobsScreen(controller: controller)),
      ),
    );

    expect(find.text('Kolejka zadań'), findsOneWidget);
    expect(
      find.text('Kolejka jest pusta. Dodaj zadanie z kreatora.'),
      findsOneWidget,
    );
    expect(find.text('Uruchom kolejkę'), findsOneWidget);
  });

  testWidgets('queued job enables explicit queue start', (tester) async {
    final controller = AppController()
      ..options = AppOptions.fromJson(
        Map<String, dynamic>.from(AppConfig.defaults),
      )
      ..jobQueue = JobQueueService(ProcessService(), paused: true);
    addTearDown(controller.dispose);
    controller.jobQueue.add(
      'Smoke job',
      const CommandDraft(executable: '/usr/bin/printf', arguments: ['ok']),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: JobsScreen(controller: controller)),
      ),
    );
    final start = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Uruchom kolejkę'),
    );
    expect(start.onPressed, isNotNull);
    expect(find.text('Smoke job'), findsOneWidget);
  });
}
