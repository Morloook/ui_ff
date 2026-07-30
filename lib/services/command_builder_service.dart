import '../models/command_models.dart';
import '../models/filter_complex.dart';

class MediaInputDraft {
  MediaInputDraft({this.path = '', List<ScopedArgument>? arguments})
    : arguments = arguments ?? [];
  String path;
  final List<ScopedArgument> arguments;
}

class MediaOutputDraft {
  MediaOutputDraft({this.path = '', List<ScopedArgument>? arguments})
    : arguments = arguments ?? [];
  String path;
  final List<ScopedArgument> arguments;
}

class CommandBuilderDraft {
  CommandBuilderDraft({
    List<ScopedArgument>? globalArguments,
    List<MediaInputDraft>? inputs,
    List<MediaOutputDraft>? outputs,
    FilterComplexDraft? filterComplex,
  }) : globalArguments = globalArguments ?? [],
       inputs = inputs ?? [MediaInputDraft()],
       outputs = outputs ?? [MediaOutputDraft()],
       filterComplex = filterComplex ?? FilterComplexDraft();

  final List<ScopedArgument> globalArguments;
  final List<MediaInputDraft> inputs;
  final List<MediaOutputDraft> outputs;
  final FilterComplexDraft filterComplex;
}

class CommandBuilderService {
  const CommandBuilderService();

  CommandDraft build(String executable, CommandBuilderDraft draft) {
    final arguments = <String>[];
    _append(arguments, draft.globalArguments);
    if (!draft.filterComplex.isEmpty) {
      arguments.addAll([
        '-filter_complex',
        draft.filterComplex.expression.trim(),
      ]);
    }
    for (final input in draft.inputs) {
      _append(arguments, input.arguments);
      if (input.path.trim().isNotEmpty) {
        arguments.addAll(['-i', input.path.trim()]);
      }
    }
    for (final output in draft.outputs) {
      _append(arguments, output.arguments);
      if (output.path.trim().isNotEmpty) arguments.add(output.path.trim());
    }
    return CommandDraft(executable: executable, arguments: arguments);
  }

  void _append(List<String> target, List<ScopedArgument> scoped) {
    for (final argument in scoped) {
      final option = argument.option.trim();
      if (option.isEmpty) continue;
      target.add(option.startsWith('-') ? option : '-$option');
      if (argument.value.trim().isNotEmpty) {
        target.add(argument.value.trim());
      }
    }
  }
}
