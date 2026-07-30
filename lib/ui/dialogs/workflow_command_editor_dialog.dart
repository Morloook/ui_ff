import 'package:flutter/material.dart' hide Text;

import '../../l10n/app_localizations.dart';
import '../../l10n/localized_text.dart';
import '../../models/command_models.dart';
import '../../models/workflow_models.dart';
import '../../services/process_service.dart';

Future<WorkflowDraft?> showWorkflowCommandEditorDialog({
  required BuildContext context,
  required WorkflowDraft workflow,
}) {
  return showDialog<WorkflowDraft>(
    context: context,
    barrierDismissible: false,
    builder: (context) => WorkflowCommandEditorDialog(workflow: workflow),
  );
}

class WorkflowCommandEditorDialog extends StatefulWidget {
  const WorkflowCommandEditorDialog({super.key, required this.workflow});

  final WorkflowDraft workflow;

  @override
  State<WorkflowCommandEditorDialog> createState() =>
      _WorkflowCommandEditorDialogState();
}

class _WorkflowCommandEditorDialogState
    extends State<WorkflowCommandEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = [
      for (final step in widget.workflow.steps)
        TextEditingController(text: _argumentsText(step.command)),
    ];
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ręczna edycja końcowych poleceń',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Możesz poprawić pełną listę argumentów każdego etapu. '
                'Program nadal uruchomi wyłącznie pokazany plik FFmpeg bez '
                'Basha, PowerShella ani interpretowania operatorów powłoki.',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView.separated(
                    itemCount: widget.workflow.steps.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final step = widget.workflow.steps[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${index + 1}/${widget.workflow.steps.length}: '
                                '${step.name}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: step.command.executable,
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: context.tr('Program wykonywalny'),
                                  helperText: context.tr(
                                    'Pole jest zablokowane ze względów bezpieczeństwa.',
                                  ),
                                ),
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: ValueKey('workflow-arguments-$index'),
                                controller: _controllers[index],
                                minLines: 4,
                                maxLines: 10,
                                decoration: InputDecoration(
                                  labelText: context.tr(
                                    'Końcowa lista argumentów',
                                  ),
                                  alignLabelWithHint: true,
                                  helperText: context.tr(
                                    'Cudzysłowy grupują jeden argument; składnia powłoki nie jest wykonywana.',
                                  ),
                                ),
                                style: const TextStyle(fontFamily: 'monospace'),
                                validator: _validateArguments,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _restoreGenerated,
                    icon: const Icon(Icons.restore),
                    label: const Text('Przywróć wygenerowane'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Anuluj'),
                  ),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Zastosuj i przejdź dalej'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateArguments(String? source) {
    try {
      const ArgumentLexer().parse(source ?? '');
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  void _restoreGenerated() {
    for (var index = 0; index < widget.workflow.steps.length; index++) {
      _controllers[index].text = _argumentsText(
        widget.workflow.steps[index].command,
      );
    }
    _formKey.currentState?.validate();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    final lexer = const ArgumentLexer();
    Navigator.pop(
      context,
      WorkflowDraft(
        name: widget.workflow.name,
        sourcePath: widget.workflow.sourcePath,
        steps: [
          for (var index = 0; index < widget.workflow.steps.length; index++)
            WorkflowStep(
              name: widget.workflow.steps[index].name,
              command: CommandDraft(
                executable: widget.workflow.steps[index].command.executable,
                arguments: lexer.parse(_controllers[index].text),
                private: widget.workflow.steps[index].command.private,
              ),
            ),
        ],
      ),
    );
  }

  String _argumentsText(CommandDraft command) =>
      command.arguments.map(CommandDraft.quoteArgument).join(' ');
}
