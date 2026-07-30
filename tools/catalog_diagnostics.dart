import 'dart:io';

import 'package:ffmpeg_ui/models/capability.dart';
import 'package:ffmpeg_ui/services/help_parser.dart';

Future<void> main() async {
  const parser = HelpParser();
  final stopwatch = Stopwatch()..start();
  final help = await Process.run('ffmpeg', const [
    '-hide_banner',
    '-h',
    'full',
  ], runInShell: false);
  final raw = '${help.stdout}\n${help.stderr}';
  final parsed = parser.parseOptions(raw);
  stdout.writeln(
    'ffmpeg-help: ${parsed.options.length} opcji, '
    '${parsed.unparsedLines.length} wierszy surowych, '
    '${stopwatch.elapsedMilliseconds} ms',
  );

  for (final entry in <MapEntry<ComponentKind, String>>[
    const MapEntry(ComponentKind.encoder, 'encoders'),
    const MapEntry(ComponentKind.decoder, 'decoders'),
    const MapEntry(ComponentKind.filter, 'filters'),
    const MapEntry(ComponentKind.format, 'formats'),
  ]) {
    final result = await Process.run('ffmpeg', [
      '-hide_banner',
      '-${entry.value}',
    ], runInShell: false);
    final items = parser.parseListing(
      '${result.stdout}\n${result.stderr}',
      entry.key,
    );
    stdout.writeln('${entry.value}: ${items.length}');
  }
}
