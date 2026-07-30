import 'package:ffmpeg_ui/models/capability.dart';
import 'package:ffmpeg_ui/services/help_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HelpParser', () {
    const parser = HelpParser();

    test('parses types, flags, ranges, defaults and enum choices', () {
      const help = '''
libx264 AVOptions:
  -crf               <float>      E..V....... Select quality (from -1 to FLT_MAX) (default -1)
  -aq-mode           <int>        E..V....... AQ method (from -1 to 3) (default -1)
     none            0            E..V....... Disabled
     variance        1            E..V....... Variance AQ
''';

      final result = parser.parseOptions(help);

      expect(result.options, hasLength(2));
      expect(result.options.first.name, 'crf');
      expect(result.options.first.valueType, 'float');
      expect(result.options.first.minimum, '-1');
      expect(result.options.first.maximum, 'FLT_MAX');
      expect(result.options.first.defaultValue, '-1');
      expect(result.options.last.choices, hasLength(2));
      expect(result.options.last.choices.last.name, 'variance');
    });

    test('keeps unknown non-empty lines in raw fallback collection', () {
      final result = parser.parseOptions('Nagłówek nieznanego typu\n');
      expect(result.options, isEmpty);
      expect(result.unparsedLines, ['Nagłówek nieznanego typu']);
    });

    test('parses global options that do not contain AVOption flags', () {
      final result = parser.parseOptions(
        '  -hide_banner       do not show program banner\n',
      );
      expect(result.options.single.name, 'hide_banner');
      expect(result.options.single.flags, isEmpty);
      expect(result.options.single.description, 'do not show program banner');
    });

    test('parses encoder listing and media type', () {
      const listing = '''
Encoders:
 V..... libx264              libx264 H.264
 A..... libmp3lame           MP3
''';
      final components = parser.parseListing(listing, ComponentKind.encoder);

      expect(components, hasLength(2));
      expect(components.first.name, 'libx264');
      expect(components.first.mediaType, MediaType.video);
      expect(components.first.helpTarget, 'encoder=libx264');
      expect(components.last.mediaType, MediaType.audio);
    });

    test('keeps every unrecognized line while parsing mixed help output', () {
      const help = '''
  -threads <int> E..V....... Number of threads (from 0 to 64) (default 0)
unrecognized diagnostic line
     auto 0 E..V....... Automatic
''';
      final result = parser.parseOptions(help);

      expect(result.options.single.name, 'threads');
      expect(result.options.single.minimum, '0');
      expect(result.options.single.maximum, '64');
      expect(result.unparsedLines, contains('unrecognized diagnostic line'));
    });

    test('maps listing flags to subtitle media type and ignores headers', () {
      const listing = '''
Filters:
 ..C scale             V->V       Scale video
 ..C aresample         A->A       Resample audio
''';
      final components = parser.parseListing(listing, ComponentKind.filter);

      expect(components, hasLength(2));
      expect(components.first.mediaType, MediaType.video);
      expect(components.last.mediaType, MediaType.audio);
    });
  });
}
