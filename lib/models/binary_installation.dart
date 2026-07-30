enum BinaryKind { ffmpeg, ffprobe }

class BinaryInstallation {
  const BinaryInstallation({
    required this.kind,
    required this.path,
    required this.available,
    this.version = '',
    this.configuration = '',
    this.error,
  });

  final BinaryKind kind;
  final String path;
  final bool available;
  final String version;
  final String configuration;
  final String? error;

  String get executableName => kind.name;

  BinaryInstallation copyWith({
    String? path,
    bool? available,
    String? version,
    String? configuration,
    String? error,
  }) {
    return BinaryInstallation(
      kind: kind,
      path: path ?? this.path,
      available: available ?? this.available,
      version: version ?? this.version,
      configuration: configuration ?? this.configuration,
      error: error,
    );
  }
}
