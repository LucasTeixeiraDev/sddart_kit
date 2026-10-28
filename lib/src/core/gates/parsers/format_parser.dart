import 'package:flutter_sdd/src/core/gates/gate_result.dart';
import 'package:flutter_sdd/src/core/gates/parsers/paths.dart';

final _changed = RegExp(r'^Changed (.+)$');

/// `dart format --set-exit-if-changed`: uma linha `Changed <arquivo>` por
/// arquivo fora do padrão.
List<GateFailure> parseFormat(String output, String root) => [
  for (final m in output.split('\n').map((l) => _changed.firstMatch(l.trim())))
    if (m != null)
      GateFailure('não formatado', location: relativeToRoot(m.group(1)!, root)),
];
