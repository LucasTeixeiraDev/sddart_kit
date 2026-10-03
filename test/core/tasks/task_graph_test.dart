import 'package:flutter_sdd/src/core/status/spec_status.dart';
import 'package:flutter_sdd/src/core/tasks/task_graph.dart';
import 'package:test/test.dart';

import '../../helpers/task_builders.dart';

void main() {
  final spec = specWith(
    [
      task('T01'),
      task('T02', wave: 1, deps: ['T01']),
      task('T03', wave: 1, deps: ['T01']),
    ],
    status: statusWith({
      'T01': const TaskStatus(state: TaskState.done),
      'T02': const TaskStatus(state: TaskState.inProgress),
    }),
  );

  test('texto compacto', () {
    expect(renderGraphText(spec), '''
onda 0
  T01 [done] Tarefa T01
onda 1
  T02 [in_progress] Tarefa T02 ← T01
  T03 [pending] Tarefa T03 ← T01
''');
  });

  test('mermaid', () {
    final m = renderGraphMermaid(spec);
    expect(m, startsWith('flowchart LR\n  subgraph W0["Onda 0"]\n'));
    expect(m, contains('    T02["T02 · Tarefa T02"]'));
    expect(m, contains('  T01 --> T02\n  T01 --> T03\n'));
    expect(m, contains('  class T01 done\n'));
    expect(m, contains('  class T02 inprogress\n'));
  });
}
