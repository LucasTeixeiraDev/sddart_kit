import 'package:flutter_sdd/src/core/gates/gate_result.dart';
import 'package:flutter_sdd/src/core/gates/parsers/paths.dart';

final _location = RegExp(
  r'((?:lib|test|bin|integration_test)/\S+?\.dart)(?::(\d+))?',
);

/// Gate sem parser dedicado (custom_lint, dart_code_linter...): uma falha
/// por linha não vazia que pareça diagnóstico (com caminho), ou as primeiras
/// linhas da saída quando nada for reconhecido.
List<GateFailure> parseGeneric(String output, String root) {
  final lines = output
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final located = <GateFailure>[];
  for (final line in lines) {
    final m = _location.firstMatch(line);
    if (m == null) continue;
    final file = relativeToRoot(m.group(1)!, root);
    final rest = line
        .replaceFirst(m.group(0)!, '')
        .replaceAll(RegExp(r'^[\s•:-]+'), '');
    located.add(
      GateFailure(
        truncate(rest.isEmpty ? line : rest, 120),
        location: m.group(2) == null ? file : '$file:${m.group(2)}',
      ),
    );
  }
  if (located.isNotEmpty) return located;
  return [for (final line in lines.take(5)) GateFailure(truncate(line, 120))];
}
