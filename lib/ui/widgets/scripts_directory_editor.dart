import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;

import '../../core/app_controller.dart';
import '../../l10n/localized_text.dart';

class ScriptsDirectoryEditor extends StatefulWidget {
  const ScriptsDirectoryEditor({
    super.key,
    required this.controller,
    this.padding = const EdgeInsets.all(18),
  });

  final AppController controller;
  final EdgeInsetsGeometry padding;

  @override
  State<ScriptsDirectoryEditor> createState() => _ScriptsDirectoryEditorState();
}

class _ScriptsDirectoryEditorState extends State<ScriptsDirectoryEditor> {
  late final TextEditingController _pathController;
  String _knownConfiguredPath = '';
  bool _saving = false;

  String get _configuredPath =>
      widget.controller.options?.scriptsDirectoryPath.trim() ?? '';

  String get _effectivePath => widget.controller.scriptImportService
      .expectedScriptsDirectory(configuredDirectory: _configuredPath);

  bool get _usesDefault => _configuredPath.isEmpty;

  @override
  void initState() {
    super.initState();
    _knownConfiguredPath = _configuredPath;
    _pathController = TextEditingController(text: _effectivePath);
    widget.controller.addListener(_syncFromController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    _pathController.dispose();
    super.dispose();
  }

  void _syncFromController() {
    final configured = _configuredPath;
    if (configured == _knownConfiguredPath) return;
    _knownConfiguredPath = configured;
    _pathController.text = _effectivePath;
    if (mounted) setState(() {});
  }

  Future<void> _selectDirectory() async {
    final selected = await FilePicker.getDirectoryPath(
      dialogTitle: 'Wybierz katalog skryptów',
    );
    if (selected == null || !mounted) return;
    _pathController.text = selected;
    await _save();
  }

  Future<void> _save() async {
    final candidate = _pathController.text.trim();
    if (candidate.isEmpty) {
      await _restoreDefault();
      return;
    }
    if (!Directory(candidate).existsSync()) {
      _showMessage('Wskazany katalog skryptów nie istnieje.');
      return;
    }
    await _setDirectory(candidate, success: 'Zapisano katalog skryptów.');
  }

  Future<void> _restoreDefault() async {
    if (_usesDefault) {
      _pathController.text = _effectivePath;
      return;
    }
    await _setDirectory(
      '',
      success: 'Przywrócono domyślny katalog skryptów obok programu.',
    );
  }

  Future<void> _setDirectory(String value, {required String success}) async {
    setState(() => _saving = true);
    try {
      await widget.controller.updateOption(['scripts', 'directoryPath'], value);
      _knownConfiguredPath = value.trim();
      _pathController.text = _effectivePath;
      _showMessage(success);
    } on Object catch (error) {
      _showMessage('Nie można zapisać katalogu skryptów: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Katalog skryptów',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _usesDefault
                  ? 'Domyślnie: katalog skrypty obok uruchomionego programu.'
                  : 'Katalog wybrany przez użytkownika.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pathController,
              enabled: !_saving,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Ścieżka do katalogu skryptów',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Zastosuj katalog'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _selectDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Wybierz katalog'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving || _usesDefault ? null : _restoreDefault,
                  icon: const Icon(Icons.restore),
                  label: const Text('Użyj domyślnego'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
