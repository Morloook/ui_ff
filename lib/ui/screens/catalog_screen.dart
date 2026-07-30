import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../../core/app_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/localized_text.dart';
import '../../models/capability.dart';
import '../../widgets/page_header.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _search = TextEditingController();
  ComponentKind? _kind;
  MediaType? _mediaType;
  List<FfmpegComponent> _items = const [];
  FfmpegComponent? _selected;
  bool _loading = false;
  Timer? _debounce;
  int? _lastSnapshotId;
  int _requestSequence = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_controllerChanged);
    unawaited(_reload());
  }

  void _controllerChanged() {
    final id = widget.controller.snapshot?.id;
    if (id != _lastSnapshotId && id != null) {
      _lastSnapshotId = id;
      unawaited(_reload());
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerChanged);
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _scheduleReload(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _reload);
  }

  Future<void> _reload() async {
    if (widget.controller.snapshot == null) return;
    final request = ++_requestSequence;
    setState(() => _loading = true);
    final items = await widget.controller.searchCapabilities(
      query: _search.text,
      kind: _kind,
      mediaType: _mediaType,
    );
    if (!mounted || request != _requestSequence) return;
    setState(() {
      _items = items;
      _loading = false;
      if (_selected != null && !items.any((item) => item.id == _selected!.id)) {
        _selected = null;
      }
    });
  }

  Future<void> _select(FfmpegComponent item) async {
    setState(() {
      _selected = item;
      _loading = true;
    });
    final detailed = await widget.controller.loadComponentDetails(item);
    if (!mounted) return;
    setState(() {
      _selected = detailed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.snapshot == null) {
      return const Center(
        child: Text('Najpierw przeskanuj możliwości na ekranie Środowisko.'),
      );
    }
    return Column(
      children: [
        PageHeader(
          title: 'Możliwości FFmpeg i FFprobe',
          subtitle:
              'Opcje i komponenty zgłoszone przez lokalne ffmpeg oraz ffprobe.',
          actions: [
            IconButton(
              onPressed: _reload,
              tooltip: context.tr('Odśwież wyniki'),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _search,
                  onChanged: _scheduleReload,
                  decoration: InputDecoration(
                    hintText: context.tr('Szukaj nazwy, opisu albo flag…'),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<ComponentKind?>(
                  initialValue: _kind,
                  decoration: InputDecoration(
                    labelText: context.tr('Kategoria'),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Wszystkie'),
                    ),
                    ...ComponentKind.values.map(
                      (kind) => DropdownMenuItem(
                        value: kind,
                        child: Text(kind.label),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _kind = value);
                    unawaited(_reload());
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<MediaType?>(
                  initialValue: _mediaType,
                  decoration: InputDecoration(labelText: context.tr('Media')),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Wszystkie'),
                    ),
                    ...MediaType.values.map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _mediaType = value);
                    unawaited(_reload());
                  },
                ),
              ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Wyniki: ${_items.length}'
              '${_items.length == (widget.controller.options?.catalogSearchLimit ?? 0) ? ' (osiągnięto limit)' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 430,
                child: _CatalogList(
                  items: _items,
                  selected: _selected,
                  onSelected: _select,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _selected == null
                    ? const Center(
                        child: Text('Wybierz element, aby zobaczyć szczegóły.'),
                      )
                    : _ComponentDetails(component: _selected!),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({
    required this.items,
    required this.selected,
    required this.onSelected,
  });
  final List<FfmpegComponent> items;
  final FfmpegComponent? selected;
  final ValueChanged<FfmpegComponent> onSelected;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text('Brak wyników.'));
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          selected: selected?.id == item.id,
          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${item.kind.label} · ${item.description}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: item.flags.isEmpty
              ? null
              : Text(item.flags, style: Theme.of(context).textTheme.labelSmall),
          onTap: () => onSelected(item),
        );
      },
    );
  }
}

class _ComponentDetails extends StatelessWidget {
  const _ComponentDetails({required this.component});
  final FfmpegComponent component;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              component.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Chip(label: Text(component.kind.label)),
            if (component.flags.isNotEmpty)
              Chip(label: Text('Flagi: ${component.flags}')),
            if (component.mediaType != MediaType.unknown)
              Chip(label: Text(component.mediaType.label)),
          ],
        ),
        const SizedBox(height: 12),
        SelectableText(component.description),
        if (component.options.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Opcje', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final option in component.options) _OptionCard(option: option),
        ],
        const SizedBox(height: 24),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Surowa pomoc FFmpeg'),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                component.rawHelp.isEmpty
                    ? component.rawLine
                    : component.rawHelp,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.option});
  final OptionDefinition option;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              '-${option.name} ${option.valueType.isEmpty ? '' : '<${option.valueType}>'}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(option.description),
            if (option.defaultValue != null)
              Text('Domyślnie: ${option.defaultValue}'),
            if (option.minimum != null || option.maximum != null)
              Text(
                'Zakres: ${option.minimum ?? '?'} — ${option.maximum ?? '?'}',
              ),
            if (option.choices.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: option.choices
                    .map(
                      (choice) =>
                          Chip(label: Text('${choice.name} = ${choice.value}')),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
