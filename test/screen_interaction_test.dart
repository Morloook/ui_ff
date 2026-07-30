import 'dart:io';

import 'package:ffmpeg_ui/core/app_config.dart';
import 'package:ffmpeg_ui/core/app_controller.dart';
import 'package:ffmpeg_ui/models/app_options.dart';
import 'package:ffmpeg_ui/models/capability.dart';
import 'package:ffmpeg_ui/ui/screens/catalog_screen.dart';
import 'package:ffmpeg_ui/ui/screens/environment_screen.dart';
import 'package:ffmpeg_ui/ui/screens/scripts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('environment sends manually entered binary paths to detection', (
    tester,
  ) async {
    final controller = _ScreenController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EnvironmentScreen(controller: controller)),
      ),
    );
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, '/custom/ffmpeg');
    await tester.enterText(fields.last, '/custom/ffprobe');
    await tester.tap(find.text('Sprawdź ścieżki'));
    expect(controller.detectedPaths, ['/custom/ffmpeg', '/custom/ffprobe']);
  });

  testWidgets('catalog searches and opens a selected component', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _ScreenController()..snapshot = _snapshot;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CatalogScreen(controller: controller)),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'x264');
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.lastQuery, 'x264');
    await tester.tap(find.text('libx264'));
    await tester.pump();
    expect(controller.detailsLoaded, isTrue);
  });

  testWidgets('catalog debounces rapid search input', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _ScreenController()..snapshot = _snapshot;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CatalogScreen(controller: controller)),
      ),
    );
    await tester.pump();
    controller.queries.clear();

    final search = find.byType(TextField).first;
    await tester.enterText(search, 'x');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(search, 'x264');
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.queries, ['x264']);
  });

  testWidgets('scripts refresh action invokes the controller', (tester) async {
    final controller = _ScreenController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ScriptsScreen(controller: controller)),
      ),
    );
    await tester.tap(find.text('Odśwież skrypty'));
    expect(controller.refreshCalls, 1);
  });

  testWidgets('scripts directory entered on the Scripts screen uses settings', (
    tester,
  ) async {
    final directory = Directory.current;
    final controller = _ScreenController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ScriptsScreen(controller: controller)),
      ),
    );

    await tester.enterText(find.byType(TextField).first, directory.path);
    await tester.tap(find.text('Zastosuj katalog'));
    await tester.pump();

    expect(controller.updatedOptionPath, ['scripts', 'directoryPath']);
    expect(controller.updatedOptionValue, directory.path);
  });
}

final _snapshot = CapabilitySnapshot(
  id: 1,
  fingerprint: 'test',
  binaryPath: 'ffmpeg',
  version: 'test',
  configuration: '',
  probePath: 'ffprobe',
  probeVersion: 'test',
  probeConfiguration: '',
  createdAt: DateTime(2026),
);

class _ScreenController extends AppController {
  _ScreenController() {
    options = AppOptions.fromJson(
      Map<String, dynamic>.from(AppConfig.defaults),
    );
  }
  List<String>? detectedPaths;
  String lastQuery = '';
  final List<String> queries = [];
  bool detailsLoaded = false;
  int refreshCalls = 0;
  List<String>? updatedOptionPath;
  Object? updatedOptionValue;

  @override
  Future<void> detectBinaries({
    String? ffmpegPath,
    String? ffprobePath,
    bool save = true,
  }) async {
    detectedPaths = [ffmpegPath ?? '', ffprobePath ?? ''];
  }

  @override
  Future<List<FfmpegComponent>> searchCapabilities({
    String query = '',
    ComponentKind? kind,
    MediaType? mediaType,
  }) async {
    lastQuery = query;
    queries.add(query);
    return const [
      FfmpegComponent(
        id: 1,
        kind: ComponentKind.encoder,
        name: 'libx264',
        description: 'H.264',
        flags: 'V',
        mediaType: MediaType.video,
        helpTarget: 'encoder=libx264',
        rawLine: '',
      ),
    ];
  }

  @override
  Future<FfmpegComponent> loadComponentDetails(
    FfmpegComponent component,
  ) async {
    detailsLoaded = true;
    return component;
  }

  @override
  Future<void> refreshScripts() async {
    refreshCalls++;
  }

  @override
  Future<void> updateOption(List<String> path, Object? value) async {
    updatedOptionPath = path;
    updatedOptionValue = value;
  }
}
