import 'package:flutter_sdd/src/core/specs/spec_repository.dart';
import 'package:flutter_sdd/src/core/status/spec_status.dart';
import 'package:flutter_sdd/src/core/tasks/task.dart';

Map<int, List<TaskSpec>> _byWave(List<TaskSpec> tasks) {
  final waves = <int, List<TaskSpec>>{};
  for (final t in tasks) {
    (waves[t.wave] ??= []).add(t);
  }
  return Map.fromEntries(
    waves.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

/// Grafo em texto compacto: uma linha por tarefa, agrupado por onda.
String renderGraphText(SpecDir spec) {
  final buffer = StringBuffer();
  for (final MapEntry(key: wave, value: tasks) in _byWave(spec.tasks).entries) {
    buffer.writeln('onda $wave');
    for (final t in tasks) {
      final state = spec.status.task(t.id).state;
      final deps = t.dependsOn.isEmpty ? '' : ' ← ${t.dependsOn.join(', ')}';
      buffer.writeln('  ${t.id} [${state.id}] ${t.title}$deps');
    }
  }
  return buffer.toString();
}

const Map<TaskState, String> _stateStyles = {
  TaskState.done: 'fill:#d4edda,stroke:#2e7d32',
  TaskState.inProgress: 'fill:#fff3cd,stroke:#b8860b',
  TaskState.failed: 'fill:#f8d7da,stroke:#c62828',
  TaskState.blocked: 'fill:#e0e0e0,stroke:#616161',
};

/// Grafo em Mermaid (`flowchart LR`), com ondas como subgrafos.
String renderGraphMermaid(SpecDir spec) {
  final buffer = StringBuffer()..writeln('flowchart LR');
  for (final MapEntry(key: wave, value: tasks) in _byWave(spec.tasks).entries) {
    buffer.writeln('  subgraph W$wave["Onda $wave"]');
    for (final t in tasks) {
      final title = t.title.replaceAll('"', "'");
      buffer.writeln('    ${t.id}["${t.id} · $title"]');
    }
    buffer.writeln('  end');
  }
  for (final t in spec.tasks) {
    for (final dep in t.dependsOn) {
      buffer.writeln('  $dep --> ${t.id}');
    }
  }
  final used = <TaskState, List<String>>{};
  for (final t in spec.tasks) {
    final state = spec.status.task(t.id).state;
    if (_stateStyles.containsKey(state)) (used[state] ??= []).add(t.id);
  }
  for (final MapEntry(key: state, value: ids) in used.entries) {
    final cls = state.id.replaceAll('_', '');
    buffer
      ..writeln('  classDef $cls ${_stateStyles[state]}')
      ..writeln('  class ${ids.join(',')} $cls');
  }
  return buffer.toString();
}
