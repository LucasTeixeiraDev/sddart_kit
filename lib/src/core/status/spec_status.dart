import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/config/yaml_utils.dart';
import 'package:flutter_sdd/src/core/config/yaml_writer.dart';
import 'package:yaml/yaml.dart';

enum Phase {
  analyze,
  spec,
  plan,
  tasks,
  exec,
  review,
  done;

  static Phase? tryParse(String v) =>
      values.where((p) => p.name == v).firstOrNull;
}

enum TaskState {
  pending('pending'),
  inProgress('in_progress'),
  done('done'),
  failed('failed'),
  blocked('blocked');

  const TaskState(this.id);

  final String id;

  static TaskState? tryParse(String v) =>
      values.where((s) => s.id == v).firstOrNull;
}

enum ReviewState {
  pending('pending'),
  inProgress('in_progress'),
  changesRequested('changes_requested'),
  approved('approved');

  const ReviewState(this.id);

  final String id;

  static ReviewState? tryParse(String v) =>
      values.where((s) => s.id == v).firstOrNull;
}

/// Gates humanos conhecidos, na ordem em que precisam ser aprovados.
const knownGates = ['analysis_approved', 'plan_approved'];

class TaskStatus {
  const TaskStatus({
    this.state = TaskState.pending,
    this.attempts = 0,
    this.tierUsed,
  });

  final TaskState state;

  /// Falhas registradas (cada `failed` incrementa).
  final int attempts;
  final Tier? tierUsed;

  TaskStatus copyWith({TaskState? state, int? attempts, Tier? tierUsed}) =>
      TaskStatus(
        state: state ?? this.state,
        attempts: attempts ?? this.attempts,
        tierUsed: tierUsed ?? this.tierUsed,
      );

  Map<String, Object?> toMap() => {
    'state': state.id,
    'attempts': attempts,
    if (tierUsed != null) 'tier_used': tierUsed!.name,
  };
}

class ReviewStatus {
  const ReviewStatus({
    this.state = ReviewState.pending,
    this.blockers = 0,
    this.cycles = 0,
  });

  final ReviewState state;
  final int blockers;

  /// Quantas vezes a revisão foi iniciada.
  final int cycles;

  Map<String, Object?> toMap() => {
    'state': state.id,
    'blockers': blockers,
    'cycles': cycles,
  };
}

/// `specs/<id>/status.yaml`. Escrito só pelo CLI.
class SpecStatus {
  const SpecStatus({
    required this.spec,
    this.phase = Phase.analyze,
    this.gates = const {'analysis_approved': false, 'plan_approved': false},
    this.tasks = const {},
    this.review = const ReviewStatus(),
  });

  /// Lança [FormatException] com o campo inválido.
  factory SpecStatus.parse(String source) {
    final Object? raw;
    try {
      raw = loadPlainYaml(source);
    } on YamlException catch (e) {
      throw FormatException('status.yaml inválido: ${e.message}');
    }
    if (raw is! Map<String, Object?>) {
      throw const FormatException('status.yaml inválido: esperado mapa');
    }
    Never bad(String field) =>
        throw FormatException('status.yaml inválido: campo $field');
    final spec = raw['spec'];
    if (spec is! String) bad('spec');
    final phase = Phase.tryParse('${raw['phase']}') ?? bad('phase');

    final gatesRaw = raw['gates'] ?? const <String, Object?>{};
    if (gatesRaw is! Map<String, Object?> ||
        gatesRaw.values.any((v) => v is! bool)) {
      bad('gates');
    }

    final tasks = <String, TaskStatus>{};
    final tasksRaw = raw['tasks'] ?? const <String, Object?>{};
    if (tasksRaw is! Map<String, Object?>) bad('tasks');
    for (final MapEntry(:key, :value) in tasksRaw.entries) {
      if (value is! Map<String, Object?>) bad('tasks.$key');
      final state =
          TaskState.tryParse('${value['state']}') ?? bad('tasks.$key.state');
      final attempts = value['attempts'] ?? 0;
      if (attempts is! int || attempts < 0) bad('tasks.$key.attempts');
      final tierRaw = value['tier_used'];
      final tier = tierRaw == null ? null : Tier.tryParse('$tierRaw');
      if (tierRaw != null && tier == null) bad('tasks.$key.tier_used');
      tasks[key] = TaskStatus(state: state, attempts: attempts, tierUsed: tier);
    }

    final reviewRaw = raw['review'] ?? const <String, Object?>{};
    if (reviewRaw is! Map<String, Object?>) bad('review');
    final reviewState =
        ReviewState.tryParse('${reviewRaw['state'] ?? 'pending'}') ??
        bad('review.state');
    final blockers = reviewRaw['blockers'] ?? 0;
    final cycles = reviewRaw['cycles'] ?? 0;
    if (blockers is! int) bad('review.blockers');
    if (cycles is! int) bad('review.cycles');

    return SpecStatus(
      spec: spec,
      phase: phase,
      gates: {
        for (final g in knownGates) g: false,
        ...gatesRaw.cast<String, bool>(),
      },
      tasks: tasks,
      review: ReviewStatus(
        state: reviewState,
        blockers: blockers,
        cycles: cycles,
      ),
    );
  }

  final String spec;
  final Phase phase;
  final Map<String, bool> gates;
  final Map<String, TaskStatus> tasks;
  final ReviewStatus review;

  bool gate(String name) => gates[name] ?? false;

  TaskStatus task(String id) => tasks[id] ?? const TaskStatus();

  SpecStatus copyWith({
    Phase? phase,
    Map<String, bool>? gates,
    Map<String, TaskStatus>? tasks,
    ReviewStatus? review,
  }) => SpecStatus(
    spec: spec,
    phase: phase ?? this.phase,
    gates: gates ?? this.gates,
    tasks: tasks ?? this.tasks,
    review: review ?? this.review,
  );

  SpecStatus withTask(String id, TaskStatus status) =>
      copyWith(tasks: {...tasks, id: status});

  /// YAML compacto e determinístico (tarefas em ordem natural de id).
  String serialize() {
    final ids = tasks.keys.toList()..sort(compareTaskIds);
    final buffer = StringBuffer()
      ..writeln('# escrito pelo sdd — não edite; use sdd status set')
      ..writeln('spec: ${inlineYaml(spec)}')
      ..writeln('phase: ${phase.name}')
      ..writeln('gates: ${inlineYaml(gates)}');
    if (ids.isEmpty) {
      buffer.writeln('tasks: {}');
    } else {
      buffer.writeln('tasks:');
      for (final id in ids) {
        buffer.writeln('  $id: ${inlineYaml(tasks[id]!.toMap())}');
      }
    }
    buffer.writeln('review: ${inlineYaml(review.toMap())}');
    return buffer.toString();
  }
}

final _taskNumber = RegExp(r'\d+');

/// Ordem natural: T2 < T10.
int compareTaskIds(String a, String b) {
  final na = int.tryParse(_taskNumber.firstMatch(a)?.group(0) ?? '');
  final nb = int.tryParse(_taskNumber.firstMatch(b)?.group(0) ?? '');
  if (na != null && nb != null && na != nb) return na.compareTo(nb);
  return a.compareTo(b);
}
