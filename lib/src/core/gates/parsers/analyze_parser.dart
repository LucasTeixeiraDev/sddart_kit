import 'package:flutter_sdd/src/core/gates/gate_result.dart';
import 'package:flutter_sdd/src/core/gates/parsers/paths.dart';

/// Linha de `dart analyze --format=machine`:
/// `SEVERITY|TYPE|CODE|FILE|LINE|COLUMN|LENGTH|MESSAGE` (`|` escapado como `\|`).
List<GateFailure> parseAnalyzeMachine(String output, String root) {
  final failures = <GateFailure>[];
  for (final line in output.split('\n')) {
    final fields = _splitEscaped(line.trim());
    if (fields.length < 8) continue;
    final severity = fields[0];
    if (!const {'INFO', 'WARNING', 'ERROR'}.contains(severity)) continue;
    final code = fields[2].toLowerCase();
    final file = relativeToRoot(fields[3], root);
    failures.add(
      GateFailure(
        '$code: ${truncate(fields.sublist(7).join('|'), 100)}',
        location: '$file:${fields[4]}',
      ),
    );
  }
  return failures;
}

final _humanLine = RegExp(
  r'^\s*(error|warning|info)\s+[•-]\s+(.+?)\s+[•-]\s+(\S+?):(\d+):\d+\s+[•-]\s+(\S+)\s*$',
);

/// Saída humana de `flutter analyze`/`dart analyze`:
/// `  error • mensagem • lib/a.dart:3:5 • codigo`.
List<GateFailure> parseAnalyzeHuman(String output, String root) => [
  for (final m in output.split('\n').map(_humanLine.firstMatch).nonNulls)
    GateFailure(
      '${m.group(5)}: ${truncate(m.group(2)!, 100)}',
      location: '${relativeToRoot(m.group(3)!, root)}:${m.group(4)}',
    ),
];

List<String> _splitEscaped(String line) {
  final fields = <String>[];
  final current = StringBuffer();
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == r'\' && i + 1 < line.length) {
      current.write(line[++i]);
    } else if (c == '|') {
      fields.add(current.toString());
      current.clear();
    } else {
      current.write(c);
    }
  }
  fields.add(current.toString());
  return fields;
}
