import 'dart:io';

import 'package:ffmpeg_ui/models/capability.dart';
import 'package:ffmpeg_ui/services/help_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = HelpParser();
  final root = Directory('test/fixtures/help_parser');

  final profiles = root.listSync().whereType<Directory>().toList()
    ..sort((left, right) => left.path.compareTo(right.path));

  test('has captured FFmpeg help from more than one binary profile', () {
    expect(profiles.length, greaterThanOrEqualTo(2));
  });

  for (final profile in profiles) {
    final profileName = profile.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .last;

    test(
      '$profileName keeps NVENC encoder, filter directions, and options',
      () {
        final encoders = parser.parseListing(
          File('${profile.path}/encoders.txt').readAsStringSync(),
          ComponentKind.encoder,
        );
        final filters = parser.parseListing(
          File('${profile.path}/filters.txt').readAsStringSync(),
          ComponentKind.filter,
        );
        final options = parser.parseOptions(
          File('${profile.path}/options.txt').readAsStringSync(),
        );

        expect(
          encoders.map((component) => component.name),
          contains('h264_nvenc'),
        );
        expect(
          encoders
              .singleWhere((component) => component.name == 'h264_nvenc')
              .mediaType,
          MediaType.video,
        );
        expect(
          filters.singleWhere((component) => component.name == 'aap').mediaType,
          MediaType.audio,
        );
        expect(
          filters
              .singleWhere((component) => component.name == 'scale')
              .mediaType,
          MediaType.video,
        );
        final preset = options.options.singleWhere(
          (option) => option.name == 'preset',
        );
        expect(preset.minimum, '0');
        expect(preset.maximum, '18');
        expect(preset.defaultValue, 'p4');
        expect(
          preset.choices.map((choice) => choice.name),
          containsAll(['p4', 'p7']),
        );
        expect(
          options.options.singleWhere((option) => option.name == 'gpu').choices,
          hasLength(2),
        );
      },
    );
  }
}
