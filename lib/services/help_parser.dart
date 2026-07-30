import 'dart:convert';

import '../models/capability.dart';

class HelpParseResult {
  const HelpParseResult({required this.options, required this.unparsedLines});

  final List<OptionDefinition> options;
  final List<String> unparsedLines;
}

class HelpParser {
  const HelpParser();

  static final RegExp _optionPattern = RegExp(
    r'^\s{1,}-(\S+)(?:\s+<([^>]+)>)?\s+([A-Z.]{5,12})\s+(.*)$',
  );
  static final RegExp _simpleOptionPattern = RegExp(
    r'^\s{1,}-(\S+)(?:\s+<([^>]+)>)?\s{2,}(.*)$',
  );
  static final RegExp _rangePattern = RegExp(r'\(from\s+(.+?)\s+to\s+(.+?)\)');
  static final RegExp _defaultPattern = RegExp(r'\(default\s+(.+?)\)');
  static final RegExp _choicePattern = RegExp(
    r'^\s{3,}(\S+)\s+(\S+)\s+([A-Z.]{5,12})(?:\s+(.*))?$',
  );

  HelpParseResult parseOptions(String raw) {
    final options = <OptionDefinition>[];
    final unparsed = <String>[];
    OptionDefinition? current;

    for (final line in const LineSplitter().convert(raw)) {
      final flaggedMatch = _optionPattern.firstMatch(line);
      final optionMatch = flaggedMatch ?? _simpleOptionPattern.firstMatch(line);
      if (optionMatch != null) {
        final description = flaggedMatch != null
            ? optionMatch.group(4) ?? ''
            : optionMatch.group(3) ?? '';
        final type = optionMatch.group(2) ?? '';
        final flags = flaggedMatch == null ? '' : optionMatch.group(3) ?? '';
        final range = _rangePattern.firstMatch(description);
        final defaultValue = _defaultPattern.firstMatch(description)?.group(1);
        current = OptionDefinition(
          name: optionMatch.group(1) ?? '',
          valueType: type,
          flags: flags,
          description: description.trim(),
          rawLine: line,
          defaultValue: defaultValue,
          minimum: range?.group(1),
          maximum: range?.group(2),
        );
        options.add(current);
        continue;
      }

      final choiceMatch = _choicePattern.firstMatch(line);
      if (choiceMatch != null && current != null) {
        final choice = OptionChoice(
          name: choiceMatch.group(1) ?? '',
          value: choiceMatch.group(2) ?? '',
          description: choiceMatch.group(4)?.trim() ?? '',
        );
        final replacement = OptionDefinition(
          name: current.name,
          valueType: current.valueType,
          flags: current.flags,
          description: current.description,
          rawLine: current.rawLine,
          defaultValue: current.defaultValue,
          minimum: current.minimum,
          maximum: current.maximum,
          choices: [...current.choices, choice],
        );
        options[options.length - 1] = replacement;
        current = replacement;
        continue;
      }

      if (line.trim().isNotEmpty &&
          !line.startsWith('ffmpeg version') &&
          !line.startsWith('ffprobe version') &&
          !line.startsWith('configuration:') &&
          !line.startsWith('libav') &&
          line.trim() != 'Exiting with exit code 0') {
        unparsed.add(line);
      }
    }

    return HelpParseResult(options: options, unparsedLines: unparsed);
  }

  List<FfmpegComponent> parseGlobalOptions(String raw, ComponentKind kind) {
    final result = parseOptions(raw);
    return result.options.map((option) {
      return FfmpegComponent(
        id: null,
        kind: kind,
        name: option.name,
        description: option.description,
        flags: option.flags,
        mediaType: _mediaTypeFromFlags(option.flags),
        helpTarget: '',
        rawLine: option.rawLine,
        options: [option],
        detailsLoaded: true,
      );
    }).toList();
  }

  List<FfmpegComponent> parseListing(String raw, ComponentKind kind) {
    final result = <FfmpegComponent>[];
    var protocolDirection = '';
    for (final line in const LineSplitter().convert(raw)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          trimmed.startsWith('--') ||
          trimmed.startsWith('ffmpeg version') ||
          trimmed.startsWith('configuration:') ||
          trimmed.startsWith('libav') ||
          trimmed.startsWith('Codecs:') ||
          trimmed.startsWith('Encoders:') ||
          trimmed.startsWith('Decoders:') ||
          trimmed.startsWith('Filters:') ||
          trimmed.startsWith('File formats:') ||
          trimmed.startsWith('Devices:') ||
          trimmed.startsWith('Pixel formats:') ||
          trimmed.startsWith('Individual channels:') ||
          trimmed.startsWith('Standard channel layouts:') ||
          trimmed.startsWith('Supported file protocols:') ||
          trimmed.startsWith('Bitstream filters:') ||
          trimmed.startsWith('Hardware acceleration methods:') ||
          trimmed.startsWith('Disposition:') ||
          trimmed.startsWith('Exiting with exit code')) {
        continue;
      }
      if (trimmed == 'Input:' || trimmed == 'Output:') {
        protocolDirection = trimmed.substring(0, trimmed.length - 1);
        continue;
      }
      if (_isLegendLine(trimmed)) continue;

      final parsed = _parseListingLine(line, kind, protocolDirection);
      if (parsed != null) result.add(parsed);
    }
    return result;
  }

  FfmpegComponent? _parseListingLine(
    String line,
    ComponentKind kind,
    String protocolDirection,
  ) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    String flags = '';
    String name = '';
    String description = '';

    if ({
      ComponentKind.protocol,
      ComponentKind.bitstreamFilter,
      ComponentKind.hardwareAcceleration,
      ComponentKind.sampleFormat,
      ComponentKind.channelLayout,
      ComponentKind.disposition,
      ComponentKind.color,
    }.contains(kind)) {
      final parts = trimmed.split(RegExp(r'\s{2,}'));
      name = parts.first.trim();
      description = parts.length > 1 ? parts.sublist(1).join('  ').trim() : '';
      flags = protocolDirection;
    } else {
      final match = RegExp(
        r'^\s*([A-Z.]{1,8})\s+(\S+)(?:\s+(.*))?$',
      ).firstMatch(line);
      if (match == null) return null;
      flags = match.group(1) ?? '';
      name = match.group(2) ?? '';
      description = match.group(3)?.trim() ?? '';
    }

    if (name.isEmpty || name == '=') return null;
    return FfmpegComponent(
      id: null,
      kind: kind,
      name: name,
      description: description,
      flags: flags,
      mediaType: kind == ComponentKind.filter
          ? _filterMediaType(description)
          : _mediaTypeFromFlags(flags),
      helpTarget: _helpTarget(kind, name, flags),
      rawLine: line,
    );
  }

  bool _isLegendLine(String value) {
    return value.startsWith('D.') ||
        value.startsWith('.E') ||
        value.startsWith('N =') ||
        value.startsWith('T..') ||
        value.startsWith('IO...') ||
        value.startsWith('FLAGS');
  }

  String _helpTarget(ComponentKind kind, String name, String flags) {
    return switch (kind) {
      ComponentKind.encoder => 'encoder=$name',
      ComponentKind.decoder => 'decoder=$name',
      ComponentKind.filter => 'filter=$name',
      ComponentKind.bitstreamFilter => 'bsf=$name',
      ComponentKind.format =>
        flags.contains('E') ? 'muxer=$name' : 'demuxer=$name',
      ComponentKind.device =>
        flags.contains('E') ? 'muxer=$name' : 'demuxer=$name',
      ComponentKind.protocol => 'protocol=$name',
      _ => '',
    };
  }

  MediaType _mediaTypeFromFlags(String flags) {
    if (flags.contains('V')) return MediaType.video;
    if (flags.contains('A')) return MediaType.audio;
    if (flags.contains('S')) return MediaType.subtitle;
    if (flags.contains('D')) return MediaType.data;
    return MediaType.unknown;
  }

  MediaType _filterMediaType(String description) {
    final type = RegExp(r'^([VASD]+)->').firstMatch(description)?.group(1);
    return switch (type) {
      final value? when value.startsWith('V') => MediaType.video,
      final value? when value.startsWith('A') => MediaType.audio,
      final value? when value.startsWith('S') => MediaType.subtitle,
      final value? when value.startsWith('D') => MediaType.data,
      _ => MediaType.unknown,
    };
  }
}
