import 'dart:convert';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../core/app_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/localized_text.dart';
import '../../models/probe_result.dart';
import '../../services/probe_service.dart';
import '../../widgets/page_header.dart';

class InspectorScreen extends StatefulWidget {
  const InspectorScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<InspectorScreen> createState() => _InspectorScreenState();
}

class _InspectorScreenState extends State<InspectorScreen> {
  final _path = TextEditingController();
  late final TextEditingController _showEntries;
  late final TextEditingController _streamSelector;
  late final TextEditingController _readIntervals;
  ProbeResult? _result;
  bool _busy = false;
  bool _dragging = false;
  late bool _showPackets;
  late bool _showFrames;
  late bool _useExifTool;

  @override
  void initState() {
    super.initState();
    final options = widget.controller.options!;
    _showEntries = TextEditingController(text: options.inspectorShowEntries);
    _streamSelector = TextEditingController(
      text: options.inspectorStreamSelector,
    );
    _readIntervals = TextEditingController(
      text: options.inspectorReadIntervals,
    );
    _showPackets = options.inspectorShowPackets;
    _showFrames = options.inspectorShowFrames;
    _useExifTool = options.inspectorUseExifTool;
  }

  @override
  void dispose() {
    _path.dispose();
    _showEntries.dispose();
    _streamSelector.dispose();
    _readIntervals.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles();
    final selected = result?.files.single.path;
    if (selected == null) return;
    _path.text = selected;
    await _inspect();
  }

  Future<void> _inspect() async {
    final ffprobe = widget.controller.ffprobe;
    if (ffprobe?.available != true || _path.text.trim().isEmpty) return;
    await widget.controller.updateOptionsSection('inspector', {
      'showEntries': _showEntries.text,
      'streamSelector': _streamSelector.text,
      'readIntervals': _readIntervals.text,
      'showPackets': _showPackets,
      'showFrames': _showFrames,
      'useExifTool': _useExifTool,
    });
    setState(() => _busy = true);
    final result = await widget.controller.probeService.inspect(
      ffprobe!,
      ProbeRequest(
        sourcePath: _path.text.trim(),
        showEntries: _showEntries.text,
        streamSelector: _streamSelector.text,
        readIntervals: _readIntervals.text,
        showPackets: _showPackets,
        showFrames: _showFrames,
        useExifTool: _useExifTool,
      ),
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
    });
  }

  String get _prettyJson =>
      const JsonEncoder.withIndent('  ').convert(_result?.combinedJson ?? {});

  Future<void> _export() async {
    if (_result == null) return;
    final path = await FilePicker.saveFile(
      dialogTitle: context.tr('Eksport wyniku inspektora'),
      fileName: 'inspector.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (path == null) return;
    await File(path).writeAsString(_prettyJson);
  }

  Future<void> _editMetadata(String suggestedTag, Object? currentValue) async {
    final inspected = _result;
    if (inspected == null) return;
    final tagController = TextEditingController(text: suggestedTag);
    final valueController = TextEditingController(
      text: currentValue is Map || currentValue is List
          ? const JsonEncoder.withIndent('  ').convert(currentValue)
          : '${currentValue ?? ''}',
    );
    final input = await showDialog<({String tag, String value})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Zmień metadane pliku'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ExifTool zmodyfikuje wskazany plik. Przy pierwszej zmianie '
                'zachowa oryginał jako plik z końcówką _original.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tagController,
                decoration: InputDecoration(
                  labelText: context.tr('Nazwa tagu'),
                  hintText: 'np. EXIF:Artist, XMP:Title, QuickTime:Title',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueController,
                minLines: 2,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: context.tr('Nowa wartość'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, (
              tag: tagController.text,
              value: valueController.text,
            )),
            child: const Text('Zapisz metadane'),
          ),
        ],
      ),
    );
    tagController.dispose();
    valueController.dispose();
    if (input == null || !mounted) return;

    setState(() => _busy = true);
    final writeResult = await widget.controller.probeService.writeMetadata(
      sourcePath: inspected.sourcePath,
      tag: input.tag,
      value: input.value,
    );
    if (!mounted) return;
    if (!writeResult.success) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nie zapisano metadanych: ${writeResult.message}'),
        ),
      );
      return;
    }
    final backupMessage = writeResult.backupPath == null
        ? ''
        : ' Kopia oryginału: ${writeResult.backupPath}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Metadane zostały zapisane.$backupMessage')),
    );
    await _inspect();
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        if (details.files.isEmpty) return;
        _path.text = details.files.first.path;
        _inspect();
      },
      child: Column(
        children: [
          PageHeader(
            title: 'Inspektor FFprobe',
            subtitle:
                'Przeciągnij plik albo wybierz go, aby odczytać strukturę i metadane.',
            actions: [
              OutlinedButton.icon(
                onPressed: _result == null ? null : _export,
                icon: const Icon(Icons.save_alt),
                label: const Text('Eksportuj JSON'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _inspect,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Analizuj'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _dragging
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _path,
                      onSubmitted: (_) => _inspect(),
                      decoration: InputDecoration(
                        labelText: context.tr('Plik źródłowy'),
                        prefixIcon: const Icon(
                          Icons.insert_drive_file_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _pickFile,
                    tooltip: context.tr('Wybierz plik'),
                    icon: const Icon(Icons.folder_open),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Opcje zaawansowane'),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _showEntries,
                        decoration: const InputDecoration(
                          labelText: 'show_entries',
                          hintText: 'format:stream=index,codec_name',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _streamSelector,
                        decoration: const InputDecoration(
                          labelText: 'select_streams',
                          hintText: 'v:0',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _readIntervals,
                        decoration: const InputDecoration(
                          labelText: 'read_intervals',
                          hintText: '%+10',
                        ),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Checkbox(
                      value: _showPackets,
                      onChanged: (value) {
                        setState(() => _showPackets = value ?? false);
                      },
                    ),
                    const Text('Pakiety'),
                    Checkbox(
                      value: _showFrames,
                      onChanged: (value) {
                        setState(() => _showFrames = value ?? false);
                      },
                    ),
                    const Text('Ramki'),
                    Checkbox(
                      value: _useExifTool,
                      onChanged: (value) {
                        setState(() => _useExifTool = value ?? true);
                      },
                    ),
                    const Text('Pełne metadane ExifTool'),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        'Uwaga: pakiety i ramki mogą tworzyć bardzo duże wyniki.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildResult()),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final result = _result;
    if (result == null) {
      return Center(
        child: Text(_dragging ? 'Upuść plik tutaj' : 'Nie wybrano pliku.'),
      );
    }
    if (result.error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(result.error!),
            ),
          ),
        ],
      );
    }
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: context.tr('Podsumowanie')),
              Tab(text: context.tr('Strumienie')),
              Tab(text: context.tr('Metadane')),
              Tab(text: context.tr('Surowy JSON')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SummaryTab(result: result),
                _StreamsTab(streams: result.streams),
                _MetadataTab(result: result, onEdit: _editMetadata),
                _RawJsonTab(
                  json: _prettyJson,
                  onCopy: () =>
                      Clipboard.setData(ClipboardData(text: _prettyJson)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.result});
  final ProbeResult result;

  @override
  Widget build(BuildContext context) {
    final format = result.format ?? const <String, dynamic>{};
    final rows = <MapEntry<String, Object?>>[
      MapEntry('Plik', result.sourcePath),
      MapEntry('Format', format['format_long_name'] ?? format['format_name']),
      MapEntry('Czas', format['duration']),
      MapEntry('Rozmiar', format['size']),
      MapEntry('Bitrate', format['bit_rate']),
      MapEntry('Strumienie', result.streams.length),
      MapEntry('Rozdziały', result.chapters.length),
      MapEntry('Czas analizy', '${result.duration.inMilliseconds} ms'),
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (final row in rows)
          ListTile(
            dense: true,
            title: Text(row.key),
            trailing: SelectableText('${row.value ?? '—'}'),
          ),
      ],
    );
  }
}

class _StreamsTab extends StatelessWidget {
  const _StreamsTab({required this.streams});
  final List<Map<String, dynamic>> streams;

  @override
  Widget build(BuildContext context) {
    if (streams.isEmpty) return const Center(child: Text('Brak strumieni.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: streams.length,
      itemBuilder: (context, index) {
        final stream = streams[index];
        return Card(
          child: ExpansionTile(
            initiallyExpanded: index == 0,
            title: Text(
              '#${stream['index'] ?? index} · '
              '${stream['codec_type'] ?? 'unknown'} · '
              '${stream['codec_name'] ?? 'unknown'}',
            ),
            children: stream.entries
                .map(
                  (entry) => ListTile(
                    dense: true,
                    title: Text(entry.key),
                    subtitle: SelectableText('${entry.value}'),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _MetadataTab extends StatelessWidget {
  const _MetadataTab({required this.result, required this.onEdit});
  final ProbeResult result;
  final Future<void> Function(String tag, Object? value) onEdit;

  @override
  Widget build(BuildContext context) {
    final ffprobe = result.ffprobeMetadata;
    final exifTool = result.exifToolMetadata;
    final sections = <Widget>[
      _ExifToolStatus(result: result, onEdit: onEdit),
      if (exifTool.isNotEmpty)
        _MetadataSource(
          title: 'ExifTool · ${exifTool.length} tagów',
          metadata: exifTool,
          onEdit: onEdit,
        ),
      if (ffprobe.isNotEmpty)
        _MetadataSource(
          title: 'FFprobe · ${ffprobe.length} tagów',
          metadata: ffprobe,
        ),
    ];
    return ListView(padding: const EdgeInsets.all(16), children: sections);
  }
}

class _ExifToolStatus extends StatelessWidget {
  const _ExifToolStatus({required this.result, required this.onEdit});
  final ProbeResult result;
  final Future<void> Function(String tag, Object? value) onEdit;

  @override
  Widget build(BuildContext context) {
    final (icon, title, detail) = switch (result.exifToolState) {
      ExifToolState.completed => (
        Icons.check_circle_outline,
        'ExifTool odczytał rozszerzone metadane',
        '${result.exifToolMetadata.length} tagów, w tym duplikaty, '
            'nieznane tagi i dane osadzone.',
      ),
      ExifToolState.unavailable => (
        Icons.info_outline,
        'ExifTool nie jest zainstalowany',
        result.exifToolError ??
            'Zainstaluj pakiet perl-image-exiftool, aby odczytać pełne dane.',
      ),
      ExifToolState.failed => (
        Icons.warning_amber,
        'ExifTool nie odczytał metadanych',
        result.exifToolError ?? 'Nieznany błąd ExifTool.',
      ),
      ExifToolState.disabled => (
        Icons.visibility_off_outlined,
        'Odczyt ExifTool jest wyłączony',
        'Można go włączyć w opcjach zaawansowanych inspektora.',
      ),
    };
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(detail),
        trailing: result.exifToolState == ExifToolState.completed
            ? FilledButton.tonalIcon(
                onPressed: () => onEdit('', null),
                icon: const Icon(Icons.edit),
                label: const Text('Dodaj lub zmień'),
              )
            : null,
      ),
    );
  }
}

class _MetadataSource extends StatelessWidget {
  const _MetadataSource({
    required this.title,
    required this.metadata,
    this.onEdit,
  });
  final String title;
  final Map<String, dynamic> metadata;
  final Future<void> Function(String tag, Object? value)? onEdit;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<MapEntry<String, dynamic>>>{};
    for (final entry in metadata.entries) {
      final separator = entry.key.indexOf(':');
      final group = separator > 0 ? entry.key.substring(0, separator) : 'Inne';
      groups.putIfAbsent(group, () => []).add(entry);
    }
    final sortedGroups = groups.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(title),
        children: [
          for (final group in sortedGroups)
            _MetadataGroup(
              name: group.key,
              entries: group.value,
              onEdit: onEdit,
            ),
        ],
      ),
    );
  }
}

class _MetadataGroup extends StatefulWidget {
  const _MetadataGroup({
    required this.name,
    required this.entries,
    this.onEdit,
  });
  final String name;
  final List<MapEntry<String, dynamic>> entries;
  final Future<void> Function(String tag, Object? value)? onEdit;

  @override
  State<_MetadataGroup> createState() => _MetadataGroupState();
}

class _MetadataGroupState extends State<_MetadataGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text('${widget.name} · ${widget.entries.length}'),
      onExpansionChanged: (value) => setState(() => _expanded = value),
      children: _expanded
          ? [
              for (final entry in widget.entries)
                ListTile(
                  dense: true,
                  title: Text(entry.key),
                  subtitle: SelectableText(_metadataValue(entry.value)),
                  trailing: _canEdit
                      ? IconButton(
                          onPressed: () =>
                              widget.onEdit!(entry.key, entry.value),
                          tooltip: context.tr('Zmień ten tag'),
                          icon: const Icon(Icons.edit_outlined),
                        )
                      : null,
                ),
            ]
          : const [],
    );
  }

  bool get _canEdit {
    if (widget.onEdit == null) return false;
    return !const {
      'ExifTool',
      'System',
      'File',
      'Composite',
    }.contains(widget.name);
  }

  String _metadataValue(Object? value) {
    if (value is Map || value is List) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return '$value';
  }
}

class _RawJsonTab extends StatelessWidget {
  const _RawJsonTab({required this.json, required this.onCopy});
  final String json;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SelectableText(
            json,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        Positioned(
          top: 12,
          right: 20,
          child: IconButton.filledTonal(
            onPressed: onCopy,
            tooltip: context.tr('Kopiuj JSON'),
            icon: const Icon(Icons.copy),
          ),
        ),
      ],
    );
  }
}
