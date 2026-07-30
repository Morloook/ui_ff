import '../models/filter_complex.dart';

class FilterComplexService {
  const FilterComplexService();

  FilterComplexValidation validate(
    String expression, {
    required int inputCount,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final labels = <String>{};
    if (expression.trim().isEmpty) {
      return FilterComplexValidation(
        errors: errors,
        warnings: warnings,
        labels: labels,
      );
    }

    final chains = _splitChains(expression, errors);
    for (var index = 0; index < chains.length; index++) {
      final chain = chains[index].trim();
      if (chain.isEmpty) {
        errors.add('Łańcuch ${index + 1} jest pusty.');
        continue;
      }
      _collectLabels(chain, inputCount, labels, errors);
    }
    if (labels.isEmpty) {
      warnings.add(
        'Graf nie zawiera etykiet strumieni, np. [0:v] lub [wynik].',
      );
    }
    return FilterComplexValidation(
      errors: errors,
      warnings: warnings,
      labels: labels,
    );
  }

  List<String> _splitChains(String value, List<String> errors) {
    final result = <String>[];
    final buffer = StringBuffer();
    String? quote;
    var escaping = false;
    for (final character in value.split('')) {
      if (escaping) {
        buffer.write(character);
        escaping = false;
        continue;
      }
      if (character == r'\') {
        buffer.write(character);
        escaping = true;
        continue;
      }
      if (character == '"' || character == "'") {
        quote = quote == character ? null : quote ?? character;
        buffer.write(character);
        continue;
      }
      if (character == ';' && quote == null) {
        result.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(character);
    }
    if (quote != null) errors.add('Niedomknięty cudzysłów w grafie filtrów.');
    result.add(buffer.toString());
    return result;
  }

  void _collectLabels(
    String chain,
    int inputCount,
    Set<String> labels,
    List<String> errors,
  ) {
    var bracketDepth = 0;
    for (final character in chain.split('')) {
      if (character == '[') bracketDepth++;
      if (character == ']') {
        bracketDepth--;
        if (bracketDepth < 0) {
          errors.add('Zamykający nawias ] nie ma pary w łańcuchu: $chain');
          bracketDepth = 0;
        }
      }
    }
    if (bracketDepth != 0) {
      errors.add('Niedomknięta etykieta strumienia w łańcuchu: $chain');
    }

    for (final match in RegExp(r'\[([^\]]*)\]').allMatches(chain)) {
      final label = match.group(1)?.trim() ?? '';
      if (label.isEmpty) {
        errors.add('Etykieta strumienia nie może być pusta.');
        continue;
      }
      labels.add(label);
      final input = RegExp(
        r'^(\d+):[vasd](?::\d+)?$',
        caseSensitive: false,
      ).firstMatch(label);
      final inputIndex = int.tryParse(input?.group(1) ?? '');
      if (inputIndex != null && inputIndex >= inputCount) {
        errors.add(
          'Etykieta [$label] wskazuje wejście ${inputIndex + 1}, '
          'ale kreator ma $inputCount wejść.',
        );
      }
    }
  }
}
