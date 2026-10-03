import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/specs/spec_repository.dart';
import 'package:flutter_sdd/src/core/status/spec_status.dart';
import 'package:flutter_sdd/src/core/tasks/scheduler.dart';
import 'package:flutter_sdd/src/core/tasks/task.dart';

/// Mutação recusada. [usage] = erro de gramática (exit 2); senão, transição
/// inválida (exit 1).
class StatusSetException implements Exception {
  const StatusSetException(this.message, {this.usage = false});

  final String message;
  final bool usage;

  @override
  String toString() => message;
}

class StatusSetResult {
  const StatusSetResult(this.status, this.message, this.change);

  final SpecStatus status;

  /// Linha curta para humanos, ex.: `T03: in_progress → done`.
  final String message;

  /// Detalhes para `--json`.
  final Map<String, Object?> change;
}

const statusSetUsage =
    'uso: sdd status set <spec> <Txx> '
    '<pending|in_progress|done|failed|blocked>\n'
    '     sdd status set <spec> gate <analysis_approved|plan_approved> '
    '[true|false]\n'
    '     sdd status set <spec> phase '
    '<analyze|spec|plan|tasks|exec|review|done>\n'
    '     sdd status set <spec> review '
    '<pending|in_progress|changes_requested|approved> [blockers=N]';

/// Aplica `sdd status set` sobre o estado atual de [spec].
StatusSetResult applyStatusSet(
  SpecDir spec,
  List<String> args,
  SddConfig config,
) {
  if (args.length < 2) {
    throw const StatusSetException(statusSetUsage, usage: true);
  }
  final [target, value, ...extra] = args;
  if (taskIdPattern.hasMatch(target)) {
    _noExtra(extra);
    return _setTask(spec, target, value, config);
  }
  return switch (target) {
    'gate' => _setGate(spec.status, value, extra),
    'phase' => () {
      _noExtra(extra);
      return _setPhase(spec, value);
    }(),
    'review' => _setReview(spec.status, value, extra, config),
    _ => throw StatusSetException(
      'alvo "$target" inválido\n$statusSetUsage',
      usage: true,
    ),
  };
}

void _noExtra(List<String> extra) {
  if (extra.isNotEmpty) {
    throw StatusSetException(
      'argumentos extras: ${extra.join(' ')}\n$statusSetUsage',
      usage: true,
    );
  }
}

Never _fail(String message) => throw StatusSetException(message);

StatusSetResult _setTask(
  SpecDir spec,
  String id,
  String value,
  SddConfig config,
) {
  final to =
      TaskState.tryParse(value) ??
      (throw StatusSetException(
        'estado "$value" inválido\n$statusSetUsage',
        usage: true,
      ));
  final task = spec.task(id) ?? _fail('tarefa $id não existe em tasks/');
  final status = spec.status;
  final current = status.task(id);
  final from = current.state;
  var next = current.copyWith(state: to);
  var note = '';

  switch (to) {
    case TaskState.inProgress:
      if (status.phase != Phase.exec) {
        _fail(
          'fase atual é ${status.phase.name}; rode sdd status set '
          '${spec.id} phase exec',
        );
      }
      if (from == TaskState.done || from == TaskState.inProgress) {
        _fail('$id já está ${from.id}');
      }
      final pendingDeps = task.dependsOn
          .where((d) => status.task(d).state != TaskState.done)
          .toList();
      if (pendingDeps.isNotEmpty) {
        _fail(
          '$id depende de tarefas não concluídas: ${pendingDeps.join(', ')}',
        );
      }
      final plan = executionFor(task, current, config.execution);
      if (plan.exhausted && from != TaskState.blocked) {
        _fail(
          '$id sem tentativas restantes; marque blocked ou resete com pending',
        );
      }
      next = next.copyWith(tierUsed: plan.tier);
      note = ' (tier ${plan.tier.name}${plan.escalated ? ', escalada' : ''})';
    case TaskState.done:
      if (from == TaskState.pending) {
        _fail('$id nunca foi iniciada; use in_progress antes');
      }
    case TaskState.failed:
      if (from != TaskState.inProgress) {
        _fail('$id não está in_progress (está ${from.id})');
      }
      next = next.copyWith(attempts: current.attempts + 1);
      if (executionFor(task, next, config.execution).exhausted) {
        next = next.copyWith(state: TaskState.blocked);
        note = ' → blocked (tentativas esgotadas; precisa de humano)';
      }
    case TaskState.blocked:
      if (from == TaskState.done) _fail('$id já está done');
    case TaskState.pending:
      // Reset manual (humano): zera tentativas.
      next = const TaskStatus();
  }

  return StatusSetResult(
    status.withTask(id, next),
    '$id: ${from.id} → ${to.id}$note',
    {
      'target': id,
      'from': from.id,
      'to': next.state.id,
      'attempts': next.attempts,
      if (next.tierUsed != null) 'tier_used': next.tierUsed!.name,
    },
  );
}

StatusSetResult _setGate(SpecStatus status, String name, List<String> extra) {
  if (!knownGates.contains(name)) {
    throw StatusSetException(
      'gate "$name" inválido (use ${knownGates.join(', ')})',
      usage: true,
    );
  }
  final value = switch (extra) {
    [] || ['true'] => true,
    ['false'] => false,
    _ => throw const StatusSetException(statusSetUsage, usage: true),
  };
  final index = knownGates.indexOf(name);
  if (value && index > 0 && !status.gate(knownGates[index - 1])) {
    _fail('$name exige ${knownGates[index - 1]} antes');
  }
  final gates = {...status.gates, name: value};
  // Revogar um gate revoga os seguintes.
  if (!value) {
    for (final later in knownGates.skip(index + 1)) {
      gates[later] = false;
    }
  }
  return StatusSetResult(
    status.copyWith(gates: gates),
    'gate $name: ${status.gate(name)} → $value',
    {'target': 'gate', 'gate': name, 'from': status.gate(name), 'to': value},
  );
}

StatusSetResult _setPhase(SpecDir spec, String value) {
  final status = spec.status;
  final phase =
      Phase.tryParse(value) ??
      (throw StatusSetException(
        'fase "$value" inválida\n$statusSetUsage',
        usage: true,
      ));
  String? requires(String gate) =>
      status.gate(gate) ? null : 'fase ${phase.name} exige gate $gate';
  final problem = switch (phase) {
    Phase.analyze => null,
    Phase.spec || Phase.plan => requires('analysis_approved'),
    Phase.tasks || Phase.exec || Phase.review => requires('plan_approved'),
    Phase.done => requires('plan_approved') ?? _doneProblem(spec),
  };
  if (problem != null) _fail(problem);
  return StatusSetResult(
    status.copyWith(phase: phase),
    'phase: ${status.phase.name} → ${phase.name}',
    {'target': 'phase', 'from': status.phase.name, 'to': phase.name},
  );
}

String? _doneProblem(SpecDir spec) {
  final open = spec.tasks
      .where((t) => spec.status.task(t.id).state != TaskState.done)
      .map((t) => t.id)
      .toList();
  if (open.isNotEmpty) return 'tarefas não concluídas: ${open.join(', ')}';
  if (spec.status.review.state != ReviewState.approved) {
    return 'revisão não aprovada (review ${spec.status.review.state.id})';
  }
  return null;
}

StatusSetResult _setReview(
  SpecStatus status,
  String value,
  List<String> extra,
  SddConfig config,
) {
  final state =
      ReviewState.tryParse(value) ??
      (throw StatusSetException(
        'estado de revisão "$value" inválido\n$statusSetUsage',
        usage: true,
      ));
  var blockers = status.review.blockers;
  for (final arg in extra) {
    final match = RegExp(r'^blockers=(\d+)$').firstMatch(arg);
    if (match == null) {
      throw StatusSetException(
        'argumento "$arg" inválido\n$statusSetUsage',
        usage: true,
      );
    }
    blockers = int.parse(match.group(1)!);
  }
  var cycles = status.review.cycles;
  if (state == ReviewState.inProgress &&
      status.review.state != ReviewState.inProgress) {
    if (cycles >= config.execution.maxReviewCycles) {
      _fail(
        'máximo de ${config.execution.maxReviewCycles} ciclos de revisão '
        'atingido; escale para o humano',
      );
    }
    cycles++;
  }
  if (state == ReviewState.approved && blockers > 0) {
    _fail('revisão com $blockers blockers não pode ser approved');
  }
  final review = ReviewStatus(state: state, blockers: blockers, cycles: cycles);
  return StatusSetResult(
    status.copyWith(review: review),
    'review: ${status.review.state.id} → ${state.id} '
    '(blockers $blockers, ciclo $cycles)',
    {'target': 'review', 'from': status.review.state.id, ...review.toMap()},
  );
}
