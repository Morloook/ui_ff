enum ExifToolState { disabled, unavailable, completed, failed }

class ProbeResult {
  const ProbeResult({
    required this.sourcePath,
    required this.json,
    required this.startedAt,
    required this.duration,
    this.error,
    this.exifToolState = ExifToolState.disabled,
    this.exifToolMetadata = const {},
    this.exifToolError,
  });

  final String sourcePath;
  final Map<String, dynamic> json;
  final DateTime startedAt;
  final Duration duration;
  final String? error;
  final ExifToolState exifToolState;
  final Map<String, dynamic> exifToolMetadata;
  final String? exifToolError;

  Map<String, dynamic> get combinedJson => {
    ...json,
    'exiftool': <String, Object?>{
      'state': exifToolState.name,
      if (exifToolError != null) 'error': exifToolError,
      'metadata': exifToolMetadata,
    },
  };

  Map<String, dynamic>? get format => json['format'] is Map<String, dynamic>
      ? json['format'] as Map<String, dynamic>
      : null;

  List<Map<String, dynamic>> get streams {
    final value = json['streams'];
    if (value is! List) return const [];
    return value.whereType<Map>().map((entry) {
      return entry.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
  }

  List<Map<String, dynamic>> get chapters {
    final value = json['chapters'];
    if (value is! List) return const [];
    return value.whereType<Map>().map((entry) {
      return entry.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
  }

  Map<String, dynamic> get ffprobeMetadata {
    final metadata = <String, dynamic>{};
    _addTags(metadata, 'format', format?['tags']);
    for (final stream in streams) {
      _addTags(metadata, 'stream[${stream['index'] ?? '?'}]', stream['tags']);
    }
    for (var index = 0; index < chapters.length; index++) {
      _addTags(metadata, 'chapter[$index]', chapters[index]['tags']);
    }
    return metadata;
  }

  static void _addTags(
    Map<String, dynamic> target,
    String prefix,
    Object? source,
  ) {
    if (source is! Map) return;
    for (final entry in source.entries) {
      target['$prefix:${entry.key}'] = entry.value;
    }
  }
}
