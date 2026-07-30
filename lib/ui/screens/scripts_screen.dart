import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:path/path.dart' as p;

import '../../core/app_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/localized_text.dart';
import '../../models/script_models.dart';
import '../../widgets/page_header.dart';
import '../dialogs/scripts_help_dialog.dart';
import '../dialogs/workflow_command_editor_dialog.dart';
import '../widgets/scripts_directory_editor.dart';

class ScriptsScreen extends StatefulWidget {
  const ScriptsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ScriptsScreen> createState() => _ScriptsScreenState();
}

class _ScriptsScreenState extends State<ScriptsScreen> {
  ImportedScript? _selected;
  Map<String, String> _values = {};
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _manuallyChanged = {};
  bool _detecting = false;
  int _calculation = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_controllerChanged);
    if (widget.controller.scripts.isNotEmpty) {
      _select(widget.controller.scripts.first);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerChanged);
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _controllerChanged() {
    final selected = _selected;
    ImportedScript? replacement;
    if (selected != null) {
      for (final item in widget.controller.scripts) {
        if (item.path == selected.path) {
          replacement = item;
          break;
        }
      }
    }
    if (selected != null && replacement == null) {
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();
      _selected = null;
      _values = {};
      _manuallyChanged.clear();
    } else if (replacement != null && !identical(replacement, selected)) {
      _select(replacement);
      return;
    } else if (selected == null && widget.controller.scripts.isNotEmpty) {
      _select(widget.controller.scripts.first);
      return;
    }
    if (mounted) setState(() {});
  }

  void _select(ImportedScript script) {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    final values = {
      for (final field in script.fields) field.variable: field.initialValue,
    };
    for (final field in script.fields) {
      if (field.kind != ScriptFieldKind.toggle) {
        _controllers[field.variable] = TextEditingController(
          text: values[field.variable],
        );
      }
    }
    setState(() {
      _selected = script;
      _values = values;
      _manuallyChanged.clear();
    });
    unawaited(_recalculate());
  }

  Future<void> _change(
    String variable,
    String value, {
    bool inspectSource = false,
  }) async {
    setState(() {
      _values[variable] = value;
      _manuallyChanged.add(variable);
    });
    await _recalculate(inspectSource: inspectSource);
  }

  Future<void> _restoreAutomatic(ScriptFieldDefinition field) async {
    setState(() {
      _manuallyChanged.remove(field.variable);
      _values[field.variable] = field.initialValue;
    });
    await _recalculate(inspectSource: field.kind == ScriptFieldKind.file);
  }

  Future<void> _recalculate({bool inspectSource = false}) async {
    final script = _selected;
    if (script == null) return;
    final generation = ++_calculation;
    if (inspectSource) setState(() => _detecting = true);
    final result = await widget.controller.scriptWorkflowService.autoFill(
      script: script,
      current: _values,
      manuallyChanged: _manuallyChanged,
      ffprobePath: widget.controller.ffprobe?.available == true
          ? widget.controller.ffprobe!.path
          : null,
      inspectSource: inspectSource,
    );
    if (!mounted || generation != _calculation) return;
    setState(() {
      _values = result;
      for (final entry in _controllers.entries) {
        final next = result[entry.key] ?? '';
        if (entry.value.text != next) entry.value.text = next;
      }
      _detecting = false;
    });
  }

  Future<void> _pickFile(ScriptFieldDefinition field) async {
    String? selected;
    if (field.kind == ScriptFieldKind.outputFile) {
      final current = _values[field.variable]?.trim() ?? '';
      selected = await FilePicker.saveFile(
        dialogTitle: field.label,
        initialDirectory: current.isEmpty ? null : p.dirname(current),
        fileName: current.isEmpty ? null : p.basename(current),
      );
    } else {
      final result = await FilePicker.pickFiles(dialogTitle: field.label);
      selected = result?.files.single.path;
    }
    if (selected == null) return;
    await _change(
      field.variable,
      selected,
      inspectSource: field.kind == ScriptFieldKind.file,
    );
  }

  Future<void> _addToQueue(ScriptPreparation preparation) async {
    final generatedWorkflow = preparation.workflow;
    if (generatedWorkflow == null) return;
    final workflow = await showWorkflowCommandEditorDialog(
      context: context,
      workflow: generatedWorkflow,
    );
    if (workflow == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dodać workflow do kolejki?'),
        content: Text(
          'Skrypt „${workflow.name}” zawiera ${workflow.steps.length} '
          '${workflow.steps.length == 1 ? 'etap' : 'etapy'}. '
          'Końcowe argumenty zostały sprawdzone. Potwierdź dodanie '
          'workflow do kolejki.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Dodaj do kolejki'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.controller.jobQueue.addWorkflow(workflow);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Dodano workflow „${workflow.name}” '
          '(${workflow.steps.length} etapów) do kolejki.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Column(
      children: [
        PageHeader(
          title: 'Skrypty',
          subtitle:
              'Skrypty .sh są analizowane bez uruchamiania powłoki. '
              'Dane formularza nie są zapisywane.',
          actions: [
            OutlinedButton.icon(
              onPressed: () => showScriptsHelpDialog(context),
              icon: const Icon(Icons.help_outline),
              label: const Text('Pomoc'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: controller.scriptsScanning
                  ? null
                  : controller.refreshScripts,
              icon: const Icon(Icons.refresh),
              label: const Text('Odśwież skrypty'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: ScriptsDirectoryEditor(
            controller: controller,
            padding: const EdgeInsets.all(14),
          ),
        ),
        if (controller.scriptsScanning || _detecting)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 850) {
                final scriptListHeight = (constraints.maxHeight * 0.38).clamp(
                  72.0,
                  180.0,
                );
                return Column(
                  children: [
                    SizedBox(height: scriptListHeight, child: _scriptList()),
                    const Divider(height: 1),
                    Expanded(child: _editor()),
                  ],
                );
              }
              return Row(
                children: [
                  SizedBox(width: 310, child: _scriptList()),
                  const VerticalDivider(width: 1),
                  Expanded(child: _editor()),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _scriptList() {
    final controller = widget.controller;
    if (controller.scriptsError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          controller.scriptsError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    if (controller.scripts.isEmpty) {
      final directory = controller.scriptDirectories.isEmpty
          ? controller.scriptImportService.expectedScriptsDirectory(
              configuredDirectory: controller.options?.scriptsDirectoryPath,
            )
          : controller.scriptDirectories.first;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Nie znaleziono plików .sh.\n'
          'Dodaj pliki do: $directory/',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      children: [
        for (final script in controller.scripts)
          Card(
            color: _selected?.path == script.path
                ? Theme.of(context).colorScheme.secondaryContainer
                : null,
            child: ListTile(
              selected: _selected?.path == script.path,
              leading: Icon(
                script.canPrepare ? Icons.code : Icons.error_outline,
              ),
              title: Text(script.name),
              subtitle: Text(
                script.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _select(script),
            ),
          ),
      ],
    );
  }

  Widget _editor() {
    final script = _selected;
    if (script == null) {
      return const Center(child: Text('Wybierz skrypt z listy.'));
    }
    final preparation = widget.controller.scriptWorkflowService.prepare(
      script: script,
      values: _values,
      ffmpegPath: widget.controller.ffmpeg?.available == true
          ? widget.controller.ffmpeg!.path
          : null,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        Text(script.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        SelectableText(
          script.path,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (script.warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(script.warnings.join('\n')),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text('Dane i opcje', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final field in script.fields) _field(field),
        const SizedBox(height: 16),
        _preparationStatus(preparation),
        const SizedBox(height: 12),
        Text('Podgląd workflow', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              preparation.workflow?.displayCommand ??
                  'Polecenia pojawią się po uzupełnieniu wszystkich danych.',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: preparation.isComplete
                ? () => _addToQueue(preparation)
                : null,
            icon: const Icon(Icons.edit_note),
            label: const Text('Edytuj końcowe polecenia i dodaj do kolejki'),
          ),
        ),
        const SizedBox(height: 16),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Oryginalna treść skryptu'),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                script.source,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field(ScriptFieldDefinition field) {
    final value = _values[field.variable] ?? '';
    final changed = _manuallyChanged.contains(field.variable);
    if (field.kind == ScriptFieldKind.toggle) {
      final enabled = field.enabledValue != null
          ? value == field.enabledValue
          : _toggleEnabled(value);
      return Card(
        child: SwitchListTile(
          value: enabled,
          title: Text(field.label),
          subtitle: Text(
            '${field.variable} · '
            '${changed ? 'zmieniono ręcznie' : field.help}',
          ),
          secondary: changed
              ? IconButton(
                  onPressed: () => _restoreAutomatic(field),
                  tooltip: context.tr(
                    'Przywróć wartość ze skryptu lub automatyczną',
                  ),
                  icon: const Icon(Icons.restore),
                )
              : null,
          onChanged: (selected) => _change(
            field.variable,
            field.enabledValue != null
                ? selected
                      ? field.enabledValue!
                      : ''
                : field.variable.contains('OVERWRITE')
                ? selected
                      ? '-y'
                      : '-n'
                : selected
                ? 'true'
                : 'false',
          ),
        ),
      );
    }
    final qualityPresets = field.variable == 'ENCODING_PRESET'
        ? const ['ultrafast', 'fast', 'medium', 'slow', 'veryslow']
        : null;
    if (qualityPresets != null) {
      final options = {...qualityPresets, if (value.isNotEmpty) value}.toList();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          key: ValueKey('${scriptKey()}-${field.variable}-$value'),
          initialValue: value.isEmpty ? null : value,
          isExpanded: true,
          decoration: _decoration(field, changed),
          items: [
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (selected) {
            if (selected != null) _change(field.variable, selected);
          },
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: _controllers[field.variable],
        keyboardType: field.kind == ScriptFieldKind.number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        minLines: field.kind == ScriptFieldKind.arguments ? 2 : 1,
        maxLines: field.kind == ScriptFieldKind.arguments ? 4 : 1,
        decoration: _decoration(field, changed).copyWith(
          suffixIcon:
              field.kind == ScriptFieldKind.file ||
                  field.kind == ScriptFieldKind.outputFile
              ? IconButton(
                  onPressed: () => _pickFile(field),
                  tooltip: field.kind == ScriptFieldKind.outputFile
                      ? context.tr('Wybierz plik wynikowy')
                      : context.tr('Wybierz plik'),
                  icon: const Icon(Icons.folder_open),
                )
              : changed
              ? IconButton(
                  onPressed: () => _restoreAutomatic(field),
                  tooltip: context.tr(
                    'Przywróć wartość ze skryptu lub automatyczną',
                  ),
                  icon: const Icon(Icons.restore),
                )
              : null,
        ),
        onChanged: (text) => _change(field.variable, text),
        onFieldSubmitted: field.kind == ScriptFieldKind.file
            ? (text) => _change(field.variable, text, inspectSource: true)
            : null,
      ),
    );
  }

  InputDecoration _decoration(ScriptFieldDefinition field, bool changed) {
    return InputDecoration(
      labelText: field.label,
      helperText:
          '${field.variable} · '
          '${changed ? 'zmieniono ręcznie' : field.help}',
    );
  }

  Widget _preparationStatus(ScriptPreparation preparation) {
    final messages = <String>[
      if (preparation.unresolvedVariables.isNotEmpty)
        'Uzupełnij: ${preparation.unresolvedVariables.join(', ')}',
      ...preparation.errors,
    ];
    if (messages.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.check_circle, color: Colors.green),
          title: Text('Workflow jest kompletny i gotowy do kolejki.'),
        ),
      );
    }
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: const Icon(Icons.warning_amber),
        title: const Text('Workflow nie jest jeszcze kompletny'),
        subtitle: Text(messages.join('\n')),
      ),
    );
  }

  bool _toggleEnabled(String value) => const {
    'true',
    't',
    'tak',
    'y',
    'yes',
    '1',
    '-y',
  }.contains(value.trim().toLowerCase());

  String scriptKey() => _selected?.path ?? '';
}
