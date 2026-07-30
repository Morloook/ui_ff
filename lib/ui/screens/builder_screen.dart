import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../core/app_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/localized_text.dart';
import '../../models/binary_installation.dart';
import '../../models/capability.dart';
import '../../models/command_models.dart';
import '../../services/command_builder_service.dart';
import '../../widgets/page_header.dart';

class BuilderScreen extends StatefulWidget {
  const BuilderScreen({
    super.key,
    required this.controller,
    required this.onOpenTerminal,
  });
  final AppController controller;
  final VoidCallback onOpenTerminal;

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  final _draft = CommandBuilderDraft();

  String get _executable => widget.controller.ffmpeg?.path ?? 'ffmpeg';

  CommandDraft get _command =>
      widget.controller.commandBuilderService.build(_executable, _draft);

  Future<void> _addArgument(
    List<ScopedArgument> target,
    ArgumentScope scope,
  ) async {
    final input = await showDialog<_BuilderArgumentInput>(
      context: context,
      builder: (context) =>
          _OptionPickerDialog(controller: widget.controller, scope: scope),
    );
    if (input == null || input.option.trim().isEmpty) return;
    setState(() {
      target.add(
        ScopedArgument(scope: scope, option: input.option, value: input.value),
      );
    });
  }

  void _sendToTerminal(List<String> arguments) {
    widget.controller.sendToTerminal(
      kind: BinaryKind.ffmpeg,
      arguments: arguments,
    );
    widget.onOpenTerminal();
  }

  @override
  Widget build(BuildContext context) {
    final command = _command;
    return Column(
      children: [
        PageHeader(
          title: 'Kreator polecenia',
          subtitle:
              'Kolejność sekcji odpowiada kolejności argumentów wymaganej przez FFmpeg.',
          actions: [
            OutlinedButton.icon(
              onPressed: () => Clipboard.setData(
                ClipboardData(text: command.displayCommand),
              ),
              icon: const Icon(Icons.copy),
              label: const Text('Kopiuj'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _sendToTerminal(command.arguments),
              icon: const Icon(Icons.terminal),
              label: const Text('Do terminala'),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              _ArgumentSection(
                title: 'Opcje globalne',
                subtitle: 'Umieszczane przed wszystkimi wejściami.',
                arguments: _draft.globalArguments,
                onAdd: () =>
                    _addArgument(_draft.globalArguments, ArgumentScope.global),
                onRemove: (value) {
                  setState(() => _draft.globalArguments.remove(value));
                },
              ),
              for (var index = 0; index < _draft.inputs.length; index++)
                _InputSection(
                  index: index,
                  input: _draft.inputs[index],
                  onChanged: () => setState(() {}),
                  onAddArgument: () => _addArgument(
                    _draft.inputs[index].arguments,
                    ArgumentScope.input,
                  ),
                  onRemove: _draft.inputs.length == 1
                      ? null
                      : () => setState(() => _draft.inputs.removeAt(index)),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => _draft.inputs.add(MediaInputDraft()));
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Dodaj wejście'),
                ),
              ),
              for (var index = 0; index < _draft.outputs.length; index++)
                _OutputSection(
                  index: index,
                  output: _draft.outputs[index],
                  onChanged: () => setState(() {}),
                  onAddArgument: () => _addArgument(
                    _draft.outputs[index].arguments,
                    ArgumentScope.output,
                  ),
                  onRemove: _draft.outputs.length == 1
                      ? null
                      : () => setState(() => _draft.outputs.removeAt(index)),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => _draft.outputs.add(MediaOutputDraft()));
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Dodaj wyjście'),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Podgląd',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        command.displayCommand,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: command.arguments.isEmpty
                            ? null
                            : () {
                                widget.controller.jobQueue.add(
                                  'Zadanie z kreatora',
                                  command,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Dodano do kolejki.'),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.add_to_queue),
                        label: const Text('Dodaj do kolejki'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BuilderArgumentInput {
  const _BuilderArgumentInput({required this.option, required this.value});
  final String option;
  final String value;
}

enum _OptionSort {
  nameAsc('Nazwa A–Z'),
  nameDesc('Nazwa Z–A'),
  mediaThenName('Typ mediów, potem nazwa');

  const _OptionSort(this.label);
  final String label;
}

class _OptionPickerDialog extends StatefulWidget {
  const _OptionPickerDialog({required this.controller, required this.scope});
  final AppController controller;
  final ArgumentScope scope;

  @override
  State<_OptionPickerDialog> createState() => _OptionPickerDialogState();
}

class _OptionPickerDialogState extends State<_OptionPickerDialog> {
  final _search = TextEditingController();
  final _option = TextEditingController();
  final _value = TextEditingController();
  List<FfmpegComponent> _options = const [];
  FfmpegComponent? _selected;
  FfmpegComponent? _selectedDetails;
  bool _loading = true;
  bool _loadingDetails = false;
  String? _error;
  String? _detailError;
  late _OptionSort _sort;
  late String _mediaFilter;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.options!;
    _sort = _OptionSort.values.firstWhere(
      (value) => value.name == settings.builderOptionSort,
      orElse: () => _OptionSort.nameAsc,
    );
    _mediaFilter = settings.builderMediaFilter;
    _search.addListener(_refresh);
    unawaited(_loadOptions());
  }

  @override
  void dispose() {
    _search.removeListener(_refresh);
    _search.dispose();
    _option.dispose();
    _value.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await widget.controller.commandOptions();
      if (!mounted) return;
      setState(() {
        _options = options;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<FfmpegComponent> get _visibleOptions {
    final query = _search.text.trim().toLowerCase();
    final result = _options.where((option) {
      if (_mediaFilter != 'all' && option.mediaType.name != _mediaFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return option.name.toLowerCase().contains(query) ||
          option.description.toLowerCase().contains(query) ||
          option.flags.toLowerCase().contains(query) ||
          option.mediaType.label.toLowerCase().contains(query);
    }).toList();
    result.sort(switch (_sort) {
      _OptionSort.nameAsc => _compareName,
      _OptionSort.nameDesc => (left, right) => _compareName(right, left),
      _OptionSort.mediaThenName => (left, right) {
        final media = left.mediaType.label.compareTo(right.mediaType.label);
        return media != 0 ? media : _compareName(left, right);
      },
    });
    return result;
  }

  static int _compareName(FfmpegComponent left, FfmpegComponent right) {
    final name = left.name.toLowerCase().compareTo(right.name.toLowerCase());
    if (name != 0) return name;
    final flags = left.flags.compareTo(right.flags);
    if (flags != 0) return flags;
    return left.description.compareTo(right.description);
  }

  Future<void> _select(FfmpegComponent component) async {
    setState(() {
      _selected = component;
      _selectedDetails = null;
      _loadingDetails = true;
      _detailError = null;
      _option.text = '-${component.name}';
    });
    try {
      final details = await widget.controller.loadComponentDetails(component);
      if (!mounted || _selected?.id != component.id) return;
      setState(() {
        _selectedDetails = details;
        _loadingDetails = false;
      });
    } on Object catch (error) {
      if (!mounted || _selected?.id != component.id) return;
      setState(() {
        _loadingDetails = false;
        _detailError = 'Nie można pobrać szczegółów opcji: $error';
      });
    }
  }

  OptionDefinition? get _definition {
    final options = _selectedDetails?.options;
    return options == null || options.isEmpty ? null : options.first;
  }

  Future<void> _setSort(_OptionSort value) async {
    setState(() => _sort = value);
    await widget.controller.updateOption(['builder', 'optionSort'], value.name);
  }

  Future<void> _setMediaFilter(String value) async {
    setState(() => _mediaFilter = value);
    await widget.controller.updateOption(['builder', 'mediaFilter'], value);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleOptions;
    final definition = _definition;
    final screenHeight = MediaQuery.sizeOf(context).height;
    return AlertDialog(
      title: Text('Dodaj opcję · ${widget.scope.label}'),
      content: SizedBox(
        width: 780,
        height: screenHeight * 0.68,
        child: SingleChildScrollView(
          child: Column(
            children: [
              ExpansionTile(
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Lista lokalnych opcji FFmpeg'
                  '${_loading ? '' : ' · ${visible.length}/${_options.length}'}',
                ),
                subtitle: const Text(
                  'Wybierz pozycję, aby uzupełnić pole opcji i zobaczyć opis.',
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          decoration: InputDecoration(
                            labelText: context.tr('Szukaj nazwy lub opisu'),
                            prefixIcon: const Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 190,
                        child: DropdownButtonFormField<_OptionSort>(
                          initialValue: _sort,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: context.tr('Sortowanie'),
                          ),
                          items: [
                            for (final value in _OptionSort.values)
                              DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) unawaited(_setSort(value));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<String>(
                          initialValue: _mediaFilter,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: context.tr('Rodzaj'),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('Wszystkie'),
                            ),
                            for (final type in MediaType.values)
                              DropdownMenuItem(
                                value: type.name,
                                child: Text(type.label),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              unawaited(_setMediaFilter(value));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: screenHeight * 0.28,
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                        ? Center(child: SelectableText(_error!))
                        : visible.isEmpty
                        ? const Center(
                            child: Text(
                              'Brak pasujących opcji. Możesz wpisać własną.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final component = visible[index];
                              return ListTile(
                                dense: true,
                                selected: component.id == _selected?.id,
                                onTap: () => _select(component),
                                title: Text(
                                  '-${component.name}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                subtitle: Text(
                                  component.description.isEmpty
                                      ? 'Brak opisu w pomocy FFmpeg.'
                                      : component.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text(
                                  '${component.mediaType.label}\n'
                                  '${component.flags}',
                                  textAlign: TextAlign.end,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
              if (_selected != null)
                Card(
                  child: ListTile(
                    leading: _loadingDetails
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.info_outline),
                    title: Text('-${_selected!.name}'),
                    subtitle: SelectableText(
                      [
                        _selected!.description,
                        ?_detailError,
                        if (definition?.valueType.isNotEmpty == true)
                          'Typ wartości: ${definition!.valueType}',
                        if (definition?.defaultValue != null)
                          'Domyślnie: ${definition!.defaultValue}',
                        if (definition?.minimum != null ||
                            definition?.maximum != null)
                          'Zakres: ${definition?.minimum ?? '—'} – '
                              '${definition?.maximum ?? '—'}',
                        if (definition?.choices.isNotEmpty == true)
                          'Dozwolone: ${definition!.choices.map((item) => item.name).join(', ')}',
                      ].where((line) => line.isNotEmpty).join('\n'),
                    ),
                  ),
                ),
              TextField(
                controller: _option,
                autofocus: _options.isEmpty,
                decoration: InputDecoration(
                  labelText: context.tr('Opcja'),
                  hintText: '-c:v',
                  helperText:
                      'Możesz zmienić wybraną opcję albo wpisać własną.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _value,
                decoration: InputDecoration(
                  labelText: context.tr('Wartość (opcjonalna)'),
                  hintText: definition?.valueType.isNotEmpty == true
                      ? '<${definition!.valueType}>'
                      : 'libx264',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: () {
            if (_option.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _BuilderArgumentInput(option: _option.text, value: _value.text),
            );
          },
          child: const Text('Dodaj'),
        ),
      ],
    );
  }
}

class _ArgumentSection extends StatelessWidget {
  const _ArgumentSection({
    required this.title,
    required this.subtitle,
    required this.arguments,
    required this.onAdd,
    required this.onRemove,
  });
  final String title;
  final String subtitle;
  final List<ScopedArgument> arguments;
  final VoidCallback onAdd;
  final ValueChanged<ScopedArgument> onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(subtitle),
            const SizedBox(height: 8),
            for (final argument in arguments)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${argument.option} ${argument.value}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                trailing: IconButton(
                  onPressed: () => onRemove(argument),
                  icon: const Icon(Icons.close),
                ),
              ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Dodaj opcję'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputSection extends StatefulWidget {
  const _InputSection({
    required this.index,
    required this.input,
    required this.onChanged,
    required this.onAddArgument,
    required this.onRemove,
  });
  final int index;
  final MediaInputDraft input;
  final VoidCallback onChanged;
  final VoidCallback onAddArgument;
  final VoidCallback? onRemove;

  @override
  State<_InputSection> createState() => _InputSectionState();
}

class _InputSectionState extends State<_InputSection> {
  late final TextEditingController _path;

  @override
  void initState() {
    super.initState();
    _path = TextEditingController(text: widget.input.path);
  }

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _MediaSection(
      title: 'Wejście ${widget.index + 1}',
      controller: _path,
      arguments: widget.input.arguments,
      onPathChanged: (value) {
        widget.input.path = value;
        widget.onChanged();
      },
      onAddArgument: widget.onAddArgument,
      onRemove: widget.onRemove,
      onRemoveArgument: (argument) {
        widget.input.arguments.remove(argument);
        widget.onChanged();
      },
    );
  }
}

class _OutputSection extends StatefulWidget {
  const _OutputSection({
    required this.index,
    required this.output,
    required this.onChanged,
    required this.onAddArgument,
    required this.onRemove,
  });
  final int index;
  final MediaOutputDraft output;
  final VoidCallback onChanged;
  final VoidCallback onAddArgument;
  final VoidCallback? onRemove;

  @override
  State<_OutputSection> createState() => _OutputSectionState();
}

class _OutputSectionState extends State<_OutputSection> {
  late final TextEditingController _path;

  @override
  void initState() {
    super.initState();
    _path = TextEditingController(text: widget.output.path);
  }

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _MediaSection(
      title: 'Wyjście ${widget.index + 1}',
      controller: _path,
      arguments: widget.output.arguments,
      onPathChanged: (value) {
        widget.output.path = value;
        widget.onChanged();
      },
      onAddArgument: widget.onAddArgument,
      onRemove: widget.onRemove,
      onRemoveArgument: (argument) {
        widget.output.arguments.remove(argument);
        widget.onChanged();
      },
    );
  }
}

class _MediaSection extends StatelessWidget {
  const _MediaSection({
    required this.title,
    required this.controller,
    required this.arguments,
    required this.onPathChanged,
    required this.onAddArgument,
    required this.onRemove,
    required this.onRemoveArgument,
  });
  final String title;
  final TextEditingController controller;
  final List<ScopedArgument> arguments;
  final ValueChanged<String> onPathChanged;
  final VoidCallback onAddArgument;
  final VoidCallback? onRemove;
  final ValueChanged<ScopedArgument> onRemoveArgument;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    tooltip: context.tr('Usuń sekcję'),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => TextField(
                controller: controller,
                onChanged: onPathChanged,
                decoration: InputDecoration(
                  labelText: context.tr('Ścieżka'),
                  suffixIcon: IconButton(
                    onPressed: value.text.isEmpty
                        ? null
                        : () {
                            controller.clear();
                            onPathChanged('');
                          },
                    tooltip: context.tr('Wyczyść całą ścieżkę'),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ),
            for (final argument in arguments)
              ListTile(
                dense: true,
                title: Text('${argument.option} ${argument.value}'),
                trailing: IconButton(
                  onPressed: () => onRemoveArgument(argument),
                  icon: const Icon(Icons.close),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddArgument,
                icon: const Icon(Icons.add),
                label: const Text('Dodaj opcję przed tą ścieżką'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
