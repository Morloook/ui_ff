import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/command_models.dart';
import '../models/script_models.dart';
import '../models/workflow_models.dart';
import 'process_service.dart';

class ScriptWorkflowService {
  const ScriptWorkflowService(this.processService);

  final ProcessService processService;

  Future<Map<String, String>> autoFill({
    required ImportedScript script,
    required Map<String, String> current,
    required Set<String> manuallyChanged,
    required String? ffprobePath,
    bool inspectSource = false,
  }) async {
    final values = Map<String, String>.from(current);
    void automatic(String variable, String value) {
      if (value.isEmpty || manuallyChanged.contains(variable)) return;
      if (script.fields.any((field) => field.variable == variable)) {
        values[variable] = value;
      }
    }

    final audio = values['AUDIO_FILE']?.trim();
    final input = values['INPUT_FILE']?.trim();
    final sourcePath = audio?.isNotEmpty == true ? audio! : input ?? '';
    if (sourcePath.isNotEmpty) {
      final base = p.basenameWithoutExtension(sourcePath);
      final title = base
          .replaceFirst(RegExp(r'_[vV][0-9]+$'), '')
          .replaceFirst(RegExp(r'_clean$'), '')
          .replaceAll('_', ' ');
      automatic('TITLE', title);
      automatic('SHORT_TITLE', title);
      final selectedTitle = values['SHORT_TITLE']?.trim().isNotEmpty == true
          ? values['SHORT_TITLE']!.trim()
          : values['TITLE']?.trim().isNotEmpty == true
          ? values['TITLE']!.trim()
          : title;
      final safe = _safeName(selectedTitle);
      final directory = p.dirname(sourcePath);
      automatic('CLEAN_MP3', p.join(directory, '${safe}_clean.mp3'));
      automatic('OUTPUT_MP4', p.join(directory, '$safe.mp4'));
      if (script.source.contains('Short_')) {
        automatic('OUTPUT_FILE', p.join(directory, 'Short_$safe.mp4'));
      } else if (script.source.contains('_clean.mp3')) {
        automatic('OUTPUT_FILE', p.join(directory, '${safe}_clean.mp3'));
      }
      if (inspectSource &&
          ffprobePath != null &&
          File(sourcePath).existsSync()) {
        final codec = await _audioCodec(ffprobePath, sourcePath);
        if (codec != null) {
          values['_DETECTED_AUDIO_CODEC'] = codec;
          automatic(
            'AUDIO_ARGS',
            codec == 'mp3' ? '-c:a copy' : '-c:a libmp3lame -b:a 192k',
          );
        }
      }
    }

    final duration = values['DURATION']?.trim() ?? '';
    if (script.source.contains('VIDEO_FILTER=') && duration.isNotEmpty) {
      final fps = values['FPS']?.trim().isNotEmpty == true
          ? values['FPS']!.trim()
          : '30';
      final dimensions = RegExp(r'scale=(\d+):(\d+)').firstMatch(script.source);
      final width = dimensions?.group(1) ?? '1080';
      final height = dimensions?.group(2) ?? '1920';
      final zoomEnabled = _isTrue(
        values['ZOOM_ENABLED'] ?? values['ZOOM_ANSWER'] ?? 'false',
      );
      if (zoomEnabled &&
          !manuallyChanged.contains('ZOOM_PERCENT') &&
          {'', '0'}.contains(values['ZOOM_PERCENT']?.trim() ?? '')) {
        values['ZOOM_PERCENT'] = '15';
      }
      final zoomPercent = values['ZOOM_PERCENT']?.trim().isNotEmpty == true
          ? values['ZOOM_PERCENT']!.trim()
          : '15';
      automatic(
        'VIDEO_FILTER',
        _videoFilter(
          width: width,
          height: height,
          fps: fps,
          duration: duration,
          zoomEnabled: zoomEnabled,
          zoomPercent: zoomPercent,
        ),
      );
    }
    return values;
  }

  ScriptPreparation prepare({
    required ImportedScript script,
    required Map<String, String> values,
    required String? ffmpegPath,
  }) {
    final unresolved = <String>{};
    final errors = <String>[];
    if (ffmpegPath == null || ffmpegPath.isEmpty) {
      errors.add('FFmpeg nie jest dostępny.');
    }
    final detectedCodec = values['_DETECTED_AUDIO_CODEC'];
    if (script.source.contains(r'[[ "$CODEC" == "mp3" ]]') &&
        detectedCodec != null &&
        detectedCodec != 'mp3') {
      errors.add(
        'Skrypt wymaga wejściowego strumienia MP3, '
        'a FFprobe wykrył: $detectedCodec.',
      );
    }
    for (final field in script.fields) {
      if (field.required && (values[field.variable]?.trim().isEmpty ?? true)) {
        unresolved.add(field.variable);
      }
      if (field.kind == ScriptFieldKind.file &&
          values[field.variable]?.trim().isNotEmpty == true &&
          !File(values[field.variable]!.trim()).existsSync()) {
        errors.add('${field.label}: wskazany plik nie istnieje.');
      }
    }
    final optionalVariables = {
      for (final field in script.fields)
        if (!field.required) field.variable,
    };
    final steps = <WorkflowStep>[];
    for (final template in script.commands) {
      final arguments = <String>[];
      for (final templateArgument in template.arguments) {
        final array = RegExp(
          r'^\$\{([A-Z][A-Z0-9_]*)\[@\]\}$',
        ).firstMatch(templateArgument);
        if (array != null) {
          final variable = array.group(1)!;
          final value = values[variable]?.trim() ?? '';
          if (value.isEmpty) {
            unresolved.add(variable);
          } else {
            try {
              arguments.addAll(const ArgumentLexer().parse(value));
            } on FormatException catch (error) {
              errors.add('$variable: $error');
            }
          }
          continue;
        }
        final singleValue = RegExp(
          r'^\$(?:\{([A-Z][A-Z0-9_]*)\}|([A-Z][A-Z0-9_]*))$',
        ).firstMatch(templateArgument);
        if (singleValue != null) {
          final variable = singleValue.group(1) ?? singleValue.group(2)!;
          final value = values[variable]?.trim() ?? '';
          if (value.isEmpty && optionalVariables.contains(variable)) {
            continue;
          }
          if (value.isEmpty) unresolved.add(variable);
          arguments.add(value);
          continue;
        }
        arguments.add(_resolve(templateArgument, values, unresolved));
      }
      steps.add(
        WorkflowStep(
          name: '${template.name} · linia ${template.line}',
          command: CommandDraft(
            executable: ffmpegPath ?? template.executable,
            arguments: arguments,
          ),
        ),
      );
    }
    if (unresolved.isNotEmpty || errors.isNotEmpty || steps.isEmpty) {
      return ScriptPreparation(
        workflow: null,
        unresolvedVariables: unresolved,
        errors: errors,
      );
    }
    return ScriptPreparation(
      workflow: WorkflowDraft(
        name: script.name,
        steps: steps,
        sourcePath: script.path,
      ),
      unresolvedVariables: const {},
      errors: const [],
    );
  }

  Future<String?> _audioCodec(String ffprobePath, String sourcePath) async {
    final result = await processService.run(
      CommandDraft(
        executable: ffprobePath,
        arguments: [
          '-v',
          'error',
          '-select_streams',
          'a:0',
          '-show_entries',
          'stream=codec_name',
          '-of',
          'default=noprint_wrappers=1:nokey=1',
          sourcePath,
        ],
        private: true,
      ),
    );
    if (result.exitCode != 0) return null;
    return result.stdout.trim().split('\n').firstOrNull;
  }

  String _resolve(
    String template,
    Map<String, String> values,
    Set<String> unresolved,
  ) {
    final pattern = RegExp(r'\$(?:\{([A-Z][A-Z0-9_]*)\}|([A-Z][A-Z0-9_]*))');
    return template.replaceAllMapped(pattern, (match) {
      final variable = match.group(1) ?? match.group(2)!;
      final value = values[variable]?.trim() ?? '';
      if (value.isEmpty) unresolved.add(variable);
      return value;
    });
  }

  String _safeName(String value) => value
      .replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');

  bool _isTrue(String value) => const {
    'true',
    't',
    'tak',
    'y',
    'yes',
    '1',
  }.contains(value.trim().toLowerCase());

  String _videoFilter({
    required String width,
    required String height,
    required String fps,
    required String duration,
    required bool zoomEnabled,
    required String zoomPercent,
  }) {
    final base =
        'scale=$width:$height:force_original_aspect_ratio=decrease,'
        'pad=$width:$height:(ow-iw)/2:(oh-ih)/2,setsar=1,';
    if (!zoomEnabled) {
      return '${base}trim=duration=$duration,'
          'setpts=PTS-STARTPTS,format=yuv420p';
    }
    final percent = double.tryParse(zoomPercent.replaceAll(',', '.')) ?? 15;
    final factor = (1 + percent / 100).toStringAsFixed(6);
    return "$base"
        "zoompan=z='min(1+($factor-1)*on/($duration*$fps-1),$factor)':"
        "x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':"
        'd=1:s=${width}x$height:fps=$fps,'
        'trim=duration=$duration,setpts=PTS-STARTPTS,format=yuv420p';
  }
}
