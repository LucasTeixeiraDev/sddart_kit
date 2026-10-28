import 'package:flutter_sdd/src/core/specs/spec_repository.dart';
import 'package:flutter_sdd/src/core/status/spec_status.dart';

/// Contagem de tarefas por estado (tarefas sem entrada no status = pending).
Map<TaskState, int> taskCounts(SpecDir spec) {
  final counts = {for (final s in TaskState.values) s: 0};
  for (final t in spec.tasks) {
    final state = spec.status.task(t.id).state;
    counts[state] = counts[state]! + 1;
  }
  return counts;
}

String _gateMark(SpecStatus s, String gate) => s.gate(gate) ? '✓' : '·';

/// Uma linha por spec (lista de specs abertas).
String summaryLine(SpecDir spec) {
  final s = spec.status;
  final c = taskCounts(spec);
  final total = spec.tasks.length;
  final parts = [
    if (total == 0) 'sem tarefas' else 'tarefas ${c[TaskState.done]}/$total',
    if (c[TaskState.inProgress]! > 0) '${c[TaskState.inProgress]} em andamento',
    if (c[TaskState.blocked]! > 0) '${c[TaskState.blocked]} bloqueadas',
  ];
  final tasks = parts.join(' · ');
  return '${spec.id}  ${s.phase.name.padRight(7)}  $tasks  '
      '(análise ${_gateMark(s, 'analysis_approved')} '
      'plano ${_gateMark(s, 'plan_approved')})';
}

/// Detalhe de uma spec.
String specDetail(SpecDir spec) {
  final s = spec.status;
  final buffer = StringBuffer()
    ..writeln('${spec.id} · fase ${s.phase.name}')
    ..writeln(
      'gates: análise ${_gateMark(s, 'analysis_approved')} · '
      'plano ${_gateMark(s, 'plan_approved')}',
    );
  final waves = <int, List<String>>{};
  for (final t in spec.tasks) {
    final st = s.task(t.id);
    final extra = st.attempts > 0 ? ' x${st.attempts}' : '';
    (waves[t.wave] ??= []).add('${t.id} ${st.state.id}$extra');
  }
  for (final wave in waves.keys.toList()..sort()) {
    buffer.writeln('onda $wave: ${waves[wave]!.join(' · ')}');
  }
  buffer.writeln(
    'review: ${s.review.state.id} · blockers ${s.review.blockers} · '
    'ciclos ${s.review.cycles}',
  );
  return buffer.toString().trimRight();
}

Map<String, Object?> specJson(SpecDir spec) => {
  'spec': spec.id,
  'phase': spec.status.phase.name,
  'gates': spec.status.gates,
  'tasks': {
    for (final t in spec.tasks)
      t.id: {'wave': t.wave, ...spec.status.task(t.id).toMap()},
  },
  'counts': {
    for (final MapEntry(:key, :value) in taskCounts(spec).entries)
      key.id: value,
  },
  'review': spec.status.review.toMap(),
};

/// Lições pendentes no `learnings.md`: itens de lista no nível superior.
int countLearnings(String content) =>
    content.split('\n').where((l) => l.startsWith('- ')).length;
