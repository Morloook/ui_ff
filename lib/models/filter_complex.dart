class FilterComplexDraft {
  FilterComplexDraft({this.expression = ''});

  String expression;

  bool get isEmpty => expression.trim().isEmpty;
}

class FilterComplexValidation {
  const FilterComplexValidation({
    required this.errors,
    required this.warnings,
    required this.labels,
  });

  final List<String> errors;
  final List<String> warnings;
  final Set<String> labels;

  bool get isValid => errors.isEmpty;
}
