import 'command_models.dart';

class WorkflowStep {
  const WorkflowStep({required this.name, required this.command});

  final String name;
  final CommandDraft command;
}

class WorkflowDraft {
  const WorkflowDraft({
    required this.name,
    required this.steps,
    this.sourcePath,
  });

  final String name;
  final List<WorkflowStep> steps;
  final String? sourcePath;

  String get displayCommand => steps
      .map((step) => '${step.name}:\n${step.command.displayCommand}')
      .join('\n\n');
}
