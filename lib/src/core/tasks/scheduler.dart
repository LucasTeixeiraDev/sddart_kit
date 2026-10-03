import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:flutter_sdd/src/core/specs/spec_repository.dart';
import 'package:flutter_sdd/src/core/status/spec_status.dart';
import 'package:flutter_sdd/src/core/tasks/task.dart';

const Map<Tier, int> _tierRank = {Tier.fast: 0, Tier.standard: 1, Tier.deep: 2};

/// Como a próxima execução de uma tarefa deve rodar.
class ExecutionPlan {
  const ExecutionPlan({
    required this.tier,
    required this.attempt,
    this.escalated = false,
    this.exhausted = false,
  });

  final Tier tier;

  /// Número desta execução (1 = primeira).
  final int attempt;
  final bool escalated;

  /// Sem tentativas restantes: a tarefa deve ficar `blocked`.
  final bool exhausted;
}

/// Política de tentativas: até `max_fix_attempts` falhas no tier da tarefa;
/// depois uma execução escalada para `escalate_to` (se for um tier acima);
/// depois esgotada.
ExecutionPlan executionFor(
  TaskSpec task,
  TaskStatus status,
  ExecutionConfig execution,
) {
  final failures = status.attempts;
  final attempt = failures + 1;
  if (failures < execution.maxFixAttempts) {
    return ExecutionPlan(tier: task.tier, attempt: attempt);
  }
  final canEscalate = _tierRank[execution.escalateTo]! > _tierRank[task.tier]!;
  if (failures == execution.maxFixAttempts && canEscalate) {
    return ExecutionPlan(
      tier: execution.escalateTo,
      attempt: attempt,
      escalated: true,
    );
  }
  return ExecutionPlan(tier: task.tier, attempt: attempt, exhausted: true);
}

/// Nome do agente gerado para a tarefa no tier dado.
String resolveAgentName(String agent, Tier tier, KitBundle? bundle) {
  final def = bundle?.agents.where((a) => a.name == agent).firstOrNull;
  if (def == null || def.tierVariants.isEmpty) return generatedName(agent);
  final variant = def.tierVariants.contains(tier)
      ? tier
      : (def.tierVariants.toList()
              ..sort((a, b) => _tierRank[a]!.compareTo(_tierRank[b]!)))
            .last;
  return '${generatedName(agent)}-${variant.name}';
}

class ReadyTask {
  const ReadyTask(this.task, this.plan, this.agent);

  final TaskSpec task;
  final ExecutionPlan plan;
  final String agent;

  Map<String, Object?> toJson() => {
    'id': task.id,
    'title': task.title,
    'file': task.file,
    'tier': plan.tier.name,
    'agent': agent,
    'attempt': plan.attempt,
    'escalated': plan.escalated,
  };
}

/// Resultado de `sdd tasks next`.
class NextResult {
  const NextResult({
    required this.wave,
    required this.ready,
    required this.inProgress,
    required this.blocked,
    required this.remaining,
  });

  /// Menor onda com tarefas não concluídas (`null` = tudo concluído).
  final int? wave;
  final List<ReadyTask> ready;
  final List<String> inProgress;
  final List<String> blocked;

  /// Tarefas não concluídas em todas as ondas.
  final int remaining;

  bool get complete => remaining == 0;

  Map<String, Object?> toJson(String spec) => {
    'spec': spec,
    'complete': complete,
    'wave': wave,
    'ready': [for (final r in ready) r.toJson()],
    'in_progress': inProgress,
    'blocked': blocked,
    'remaining': remaining,
  };
}

/// Tarefas prontas da menor onda não concluída (ondas são sequenciais: o
/// orquestrador faz commit ao fim de cada uma, D-007).
NextResult computeNext(SpecDir spec, SddConfig config, {KitBundle? bundle}) {
  final status = spec.status;
  final notDone = spec.tasks
      .where((t) => status.task(t.id).state != TaskState.done)
      .toList();
  if (notDone.isEmpty) {
    return const NextResult(
      wave: null,
      ready: [],
      inProgress: [],
      blocked: [],
      remaining: 0,
    );
  }
  final wave = notDone.map((t) => t.wave).reduce((a, b) => a < b ? a : b);
  final ready = <ReadyTask>[];
  final inProgress = <String>[];
  final blocked = <String>[];
  for (final t in notDone.where((t) => t.wave == wave)) {
    final st = status.task(t.id);
    switch (st.state) {
      case TaskState.inProgress:
        inProgress.add(t.id);
      case TaskState.blocked:
        blocked.add(t.id);
      case TaskState.pending || TaskState.failed:
        final depsDone = t.dependsOn.every(
          (d) => status.task(d).state == TaskState.done,
        );
        final plan = executionFor(t, st, config.execution);
        if (plan.exhausted) {
          blocked.add(t.id);
        } else if (depsDone) {
          ready.add(
            ReadyTask(t, plan, resolveAgentName(t.agent, plan.tier, bundle)),
          );
        }
      case TaskState.done:
        break;
    }
  }
  return NextResult(
    wave: wave,
    ready: ready,
    inProgress: inProgress,
    blocked: blocked,
    remaining: notDone.length,
  );
}
