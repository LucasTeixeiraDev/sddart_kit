import 'dart:convert';

import 'package:flutter_sdd/src/core/gates/gate_result.dart';
import 'package:flutter_sdd/src/core/gates/parsers/paths.dart';

/// Resultado do parse de `flutter test --reporter json`.
class TestRun {
  const TestRun(this.failures, {required this.passed, required this.sawEvents});

  final List<GateFailure> failures;
  final int passed;

  /// Se a saída tinha eventos do reporter JSON (senão, use fallback).
  final bool sawEvents;
}

/// Extrai só os testes que falharam: nome + primeira linha útil do erro.
/// Falhas de carregamento (testes ocultos, ex.: erro de compilação) também.
TestRun parseTestJson(String output, String root) {
  final suites = <int, String>{};
  final tests = <int, ({String name, int suite})>{};
  final errors = <int, String>{};
  final failures = <GateFailure>[];
  var passed = 0;
  var sawEvents = false;

  for (final line in output.split('\n')) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('{')) continue;
    final Object? event;
    try {
      event = jsonDecode(trimmed);
    } on FormatException {
      continue;
    }
    if (event is! Map<String, Object?>) continue;
    sawEvents = true;
    switch (event['type']) {
      case 'suite':
        final suite = event['suite']! as Map<String, Object?>;
        suites[suite['id']! as int] = '${suite['path']}';
      case 'testStart':
        final test = event['test']! as Map<String, Object?>;
        tests[test['id']! as int] = (
          name: '${test['name']}',
          suite: test['suiteID'] as int? ?? -1,
        );
      case 'error':
        final id = event['testID']! as int;
        final message = '${event['error']}';
        errors.putIfAbsent(id, () => message);
      case 'testDone':
        final id = event['testID']! as int;
        final hidden = event['hidden'] == true;
        final result = event['result'];
        if (event['skipped'] == true) continue;
        if (result == 'success') {
          if (!hidden) passed++;
          continue;
        }
        final test = tests[id];
        final suitePath = suites[test?.suite];
        final location = suitePath == null
            ? null
            : relativeToRoot(suitePath, root);
        final error = _usefulError(errors[id] ?? '$result');
        // Falha de carga (ex.: erro de compilação) chega como o teste
        // "loading <arquivo>" (oculto ou não, conforme a versão).
        final loading = hidden || (test?.name.startsWith('loading ') ?? false);
        failures.add(
          GateFailure(
            loading
                ? 'falha ao carregar: $error'
                : '"${truncate(test?.name ?? 'teste $id', 100)}"  $error',
            location: location,
          ),
        );
    }
  }
  return TestRun(failures, passed: passed, sawEvents: sawEvents);
}

/// Primeira linha útil; para matchers, junta `Expected:` e `Actual:`.
String _usefulError(String error) {
  final lines = error
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  // "Failed to load ...:" não diz nada; a linha seguinte tem o erro.
  if (lines.length > 1 && lines.first.startsWith('Failed to load')) {
    lines.removeAt(0);
  }
  if (lines.isEmpty) return 'falhou';
  final expected = lines.where((l) => l.startsWith('Expected:')).firstOrNull;
  final actual = lines.where((l) => l.startsWith('Actual:')).firstOrNull;
  if (expected != null && actual != null) {
    return truncate('$expected $actual');
  }
  return truncate(lines.first);
}
