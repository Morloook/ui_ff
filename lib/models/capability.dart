enum ComponentKind {
  globalOption('Opcje FFmpeg', 'option'),
  probeOption('Opcje FFprobe', 'probe_option'),
  encoder('Encodery', 'encoder'),
  decoder('Decodery', 'decoder'),
  filter('Filtry', 'filter'),
  format('Formaty', 'format'),
  device('Urządzenia', 'device'),
  protocol('Protokoły', 'protocol'),
  bitstreamFilter('Filtry strumienia bitowego', 'bsf'),
  hardwareAcceleration('Akceleracja sprzętowa', 'hwaccel'),
  pixelFormat('Formaty pikseli', 'pix_fmt'),
  sampleFormat('Formaty próbek', 'sample_fmt'),
  channelLayout('Układy kanałów', 'channel_layout'),
  codec('Kodeki', 'codec'),
  disposition('Dyspozycje', 'disposition'),
  color('Nazwy kolorów', 'color');

  const ComponentKind(this.label, this.storageKey);
  final String label;
  final String storageKey;

  static ComponentKind fromStorageKey(String value) {
    return values.firstWhere(
      (kind) => kind.storageKey == value,
      orElse: () => ComponentKind.globalOption,
    );
  }
}

enum MediaType {
  audio('Audio'),
  video('Wideo'),
  subtitle('Napisy'),
  data('Dane'),
  attachment('Załącznik'),
  unknown('Inne');

  const MediaType(this.label);
  final String label;
}

class OptionChoice {
  const OptionChoice({
    required this.name,
    required this.value,
    this.description = '',
  });

  final String name;
  final String value;
  final String description;

  Map<String, Object?> toJson() => {
    'name': name,
    'value': value,
    'description': description,
  };

  factory OptionChoice.fromJson(Map<String, Object?> json) => OptionChoice(
    name: json['name'] as String? ?? '',
    value: json['value'] as String? ?? '',
    description: json['description'] as String? ?? '',
  );
}

class OptionDefinition {
  const OptionDefinition({
    required this.name,
    required this.valueType,
    required this.flags,
    required this.description,
    required this.rawLine,
    this.defaultValue,
    this.minimum,
    this.maximum,
    this.choices = const [],
  });

  final String name;
  final String valueType;
  final String flags;
  final String description;
  final String rawLine;
  final String? defaultValue;
  final String? minimum;
  final String? maximum;
  final List<OptionChoice> choices;
}

class FfmpegComponent {
  const FfmpegComponent({
    required this.id,
    required this.kind,
    required this.name,
    required this.description,
    required this.flags,
    required this.mediaType,
    required this.helpTarget,
    required this.rawLine,
    this.options = const [],
    this.rawHelp = '',
    this.detailsLoaded = false,
  });

  final int? id;
  final ComponentKind kind;
  final String name;
  final String description;
  final String flags;
  final MediaType mediaType;
  final String helpTarget;
  final String rawLine;
  final List<OptionDefinition> options;
  final String rawHelp;
  final bool detailsLoaded;

  FfmpegComponent copyWith({
    int? id,
    List<OptionDefinition>? options,
    String? rawHelp,
    bool? detailsLoaded,
  }) {
    return FfmpegComponent(
      id: id ?? this.id,
      kind: kind,
      name: name,
      description: description,
      flags: flags,
      mediaType: mediaType,
      helpTarget: helpTarget,
      rawLine: rawLine,
      options: options ?? this.options,
      rawHelp: rawHelp ?? this.rawHelp,
      detailsLoaded: detailsLoaded ?? this.detailsLoaded,
    );
  }
}

class CapabilitySnapshot {
  const CapabilitySnapshot({
    required this.id,
    required this.fingerprint,
    required this.binaryPath,
    required this.version,
    required this.configuration,
    required this.probePath,
    required this.probeVersion,
    required this.probeConfiguration,
    required this.createdAt,
  });

  final int id;
  final String fingerprint;
  final String binaryPath;
  final String version;
  final String configuration;
  final String probePath;
  final String probeVersion;
  final String probeConfiguration;
  final DateTime createdAt;
}

class ScanProgress {
  const ScanProgress({
    required this.completed,
    required this.total,
    required this.label,
    this.error,
  });

  final int completed;
  final int total;
  final String label;
  final String? error;
  double get fraction => total == 0 ? 0 : completed / total;
}
