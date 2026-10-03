import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:flutter_sdd/src/core/specs/spec_repository.dart';
import 'package:flutter_sdd/src/core/status/spec_status.dart';
import 'package:flutter_sdd/src/core/tasks/task.dart';

/// Resultado de `sdd tasks validate`.
class ValidationResult {
  const ValidationResult(this.issues);

  final List<TaskIssue> issues;

  List<TaskIssue> get errors => issues.where((i) => !i.isWarning).toList();

  List<TaskIssue> get warnings => issues.where((i) => i.isWarning).toList();

  bool get ok => errors.isEmpty;
}

/// IDs de AC presentes em `spec.md`, na ordem de aparição.
List<String> specAcceptanceIds(String specMd, RegExp acPattern) =>
    acPattern.allMatches(specMd).map((m) => m.group(0)!).toSet().toList();

/// Valida o DAG de tarefas de uma spec.
///
/// [exists] responde se um caminho relativo à raiz existe no projeto.
/// [bundle], se informado, valida o agente e o tier de cada tarefa.
ValidationResult validateTasks(
  SpecDir spec, {
  required SddConfig config,
  required bool Function(String path) exists,
  KitBundle? bundle,
}) {
  final issues = <TaskIssue>[...spec.taskIssues];
  void error(TaskSpec t, String msg) =>
      issues.add(TaskIssue(msg, task: t.id, file: t.file));
  void warn(TaskSpec t, String msg) =>
      issues.add(TaskIssue(msg, task: t.id, file: t.file, isWarning: true));

  final tasks = spec.tasks;
  if (tasks.isEmpty && spec.taskIssues.isEmpty) {
    issues.add(const TaskIssue('nenhuma tarefa em tasks/'));
  }

  // IDs únicos.
  final byId = <String, TaskSpec>{};
  for (final t in tasks) {
    if (byId.containsKey(t.id)) {
      error(t, 'id duplicado (também em ${byId[t.id]!.file})');
    } else {
      byId[t.id] = t;
    }
  }

  // Dependências existentes e de ondas anteriores.
  for (final t in tasks) {
    for (final dep in t.dependsOn) {
      final d = byId[dep];
      if (d == null) {
        error(t, 'depends_on: $dep não existe');
      } else if (d.wave >= t.wave) {
        error(
          t,
          'depends_on: $dep está na onda ${d.wave} (deve ser < ${t.wave})',
        );
      }
    }
  }

  // Ciclos.
  for (final cycle in findCycles(byId)) {
    issues.add(TaskIssue('ciclo de dependências: ${cycle.join(' → ')}'));
  }

  // Conflito de owns na mesma onda.
  final ownerByWave = <(int, String), TaskSpec>{};
  for (final t in tasks) {
    for (final file in t.owns) {
      final other = ownerByWave[(t.wave, file)];
      if (other != null && other.id != t.id) {
        error(t, 'owns: $file também é de ${other.id} (onda ${t.wave})');
      } else {
        ownerByWave[(t.wave, file)] = t;
      }
    }
  }

  // reads existentes ou possuídos por uma dependência (transitiva).
  for (final t in tasks) {
    final owned = {
      for (final dep in _transitiveDeps(t, byId)) ...byId[dep]!.owns,
    };
    for (final read in t.reads) {
      if (!exists(read) && !owned.contains(read)) {
        error(t, 'reads: $read não existe nem é owns de uma dependência');
      }
    }
    if (t.exemplar != null && !exists(t.exemplar!)) {
      error(t, 'exemplar: ${t.exemplar} não existe');
    }
  }

  // Agente e tier.
  if (bundle != null) {
    final agents = {for (final a in bundle.agents) a.name: a};
    for (final t in tasks) {
      final agent = agents[t.agent];
      if (agent == null) {
        error(t, 'agent: "${t.agent}" não existe no kit');
      } else if (agent.tierVariants.isNotEmpty) {
        if (!agent.tierVariants.contains(t.tier)) {
          error(
            t,
            'tier: ${t.tier.name} sem variante em ${t.agent} '
            '(${agent.tierVariants.map((v) => v.name).join(', ')})',
          );
        }
        final escalate = config.execution.escalateTo;
        if (!agent.tierVariants.contains(escalate)) {
          warn(
            t,
            'escalonamento para ${escalate.name} sem variante em ${t.agent}',
          );
        }
      }
    }
  }

  // ACs: existem na spec e todos têm tarefa.
  final specMd = spec.specMd;
  if (specMd == null) {
    issues.add(TaskIssue('spec.md ausente', file: '${spec.path}/spec.md'));
  } else {
    final pattern = config.dod.traceability.acPattern;
    final specAcs = specAcceptanceIds(specMd, pattern);
    final covered = <String>{};
    for (final t in tasks) {
      for (final ac in t.acceptance) {
        if (!specAcs.contains(ac)) {
          error(t, 'acceptance: $ac não existe em spec.md');
        }
        covered.add(ac);
      }
    }
    for (final ac in specAcs.where((ac) => !covered.contains(ac))) {
      issues.add(
        TaskIssue(
          '$ac sem tarefa',
          file: '${spec.path}/spec.md',
          isWarning: true,
        ),
      );
    }
  }

  return ValidationResult(issues);
}

Set<String> _transitiveDeps(TaskSpec t, Map<String, TaskSpec> byId) {
  final seen = <String>{};
  final stack = [...t.dependsOn];
  while (stack.isNotEmpty) {
    final id = stack.removeLast();
    if (!seen.add(id)) continue;
    final dep = byId[id];
    if (dep != null) stack.addAll(dep.dependsOn);
  }
  return seen..removeWhere((id) => !byId.containsKey(id));
}

/// Ciclos do grafo (cada um como caminho fechado, ex.: T1 → T2 → T1).
List<List<String>> findCycles(Map<String, TaskSpec> byId) {
  const white = 0;
  const gray = 1;
  const black = 2;
  final color = {for (final id in byId.keys) id: white};
  final cycles = <List<String>>[];
  final path = <String>[];

  void visit(String id) {
    color[id] = gray;
    path.add(id);
    for (final dep in byId[id]!.dependsOn) {
      if (!byId.containsKey(dep)) continue;
      if (color[dep] == gray) {
        cycles.add([...path.sublist(path.indexOf(dep)), dep]);
      } else if (color[dep] == white) {
        visit(dep);
      }
    }
    path.removeLast();
    color[id] = black;
  }

  for (final id in byId.keys.toList()..sort(compareTaskIds)) {
    if (color[id] == white) visit(id);
  }
  return cycles;
}
