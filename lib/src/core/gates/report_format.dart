import 'package:flutter_sdd/src/core/gates/gate_result.dart';

/// Saída humana compacta (só falhas; nunca o log bruto). No máximo
/// [maxLines] falhas por gate.
String formatReport(CheckReport report, {int maxLines = 20}) {
  final buffer = StringBuffer();
  final ok = <GateResult>[];
  for (final r in report.results) {
    if (r.status != GateStatus.fail) {
      ok.add(r);
      continue;
    }
    for (final f in r.failures.take(maxLines)) {
      final tag = f.interferenceWith == null ? 'FAIL' : 'INTF';
      final parts = [
        '$tag ${r.gate.padRight(8)}',
        ?f.location,
        f.message,
        if (f.interferenceWith != null) '(${f.interferenceWith} em andamento)',
      ];
      buffer.writeln(parts.join('  '));
    }
    final hidden = r.failures.length - maxLines;
    if (hidden > 0) {
      buffer.writeln('     ${r.gate.padRight(8)}  … +$hidden falhas');
    }
  }
  for (final r in ok) {
    final tag = r.status == GateStatus.pass ? 'PASS' : 'SKIP';
    buffer.writeln(
      r.note == null
          ? '$tag ${r.gate}'
          : '$tag ${r.gate.padRight(8)}  ${r.note}',
    );
  }
  final passed = report.results
      .where((r) => r.status == GateStatus.pass)
      .length;
  buffer.write('${report.failureCount} falhas · $passed gates ok');
  if (report.onlyInterference) {
    buffer.write(' · só interferência: recheque ao fim da onda');
  }
  buffer.writeln();
  return buffer.toString();
}

/// Documento `--json` estável (falhas também limitadas a [maxLines]).
Map<String, Object?> reportJson(CheckReport report, {int maxLines = 20}) => {
  'ok': report.ok,
  'mode': report.mode,
  if (report.spec != null) 'spec': report.spec,
  if (report.task != null) 'task': report.task,
  'failures': report.failureCount,
  'interference': report.onlyInterference,
  'gates': [
    for (final r in report.results)
      {
        ...r.toJson(),
        if (r.failures.length > maxLines) ...{
          'failures': [for (final f in r.failures.take(maxLines)) f.toJson()],
          'truncated': r.failures.length - maxLines,
        },
      },
  ],
};
