enum GateStatus { pass, fail, skip }

/// Uma falha compacta de gate (nunca o log bruto).
class GateFailure {
  const GateFailure(this.message, {this.location, this.interferenceWith});

  /// `arquivo` ou `arquivo:linha`, relativo à raiz do projeto.
  final String? location;
  final String message;

  /// Tarefa em andamento cujo arquivo provavelmente causou a falha (D-007).
  final String? interferenceWith;

  GateFailure withInterference(String task) =>
      GateFailure(message, location: location, interferenceWith: task);

  Map<String, Object?> toJson() => {
    if (location != null) 'location': location,
    'message': message,
    if (interferenceWith != null) 'interference_with': interferenceWith,
  };
}

class GateResult {
  const GateResult(
    this.gate,
    this.status, {
    this.failures = const [],
    this.note,
  });

  const GateResult.pass(this.gate, {this.note})
    : status = GateStatus.pass,
      failures = const [];

  const GateResult.skip(this.gate, this.note)
    : status = GateStatus.skip,
      failures = const [];

  /// Falha com a lista de falhas (lista vazia vira uma falha genérica).
  GateResult.fail(this.gate, List<GateFailure> failures, {this.note})
    : status = GateStatus.fail,
      failures = failures.isEmpty
          ? [const GateFailure('falhou sem detalhes')]
          : failures;

  final String gate;
  final GateStatus status;
  final List<GateFailure> failures;
  final String? note;

  /// Todas as falhas são interferência de outras tarefas.
  bool get onlyInterference =>
      status == GateStatus.fail &&
      failures.every((f) => f.interferenceWith != null);

  Map<String, Object?> toJson() => {
    'gate': gate,
    'status': status.name,
    if (note != null) 'note': note,
    if (failures.isNotEmpty) 'failures': [for (final f in failures) f.toJson()],
  };
}

/// Resultado de `sdd check`.
class CheckReport {
  const CheckReport({
    required this.mode,
    required this.results,
    this.spec,
    this.task,
  });

  /// `task` ou `spec`.
  final String mode;
  final String? spec;
  final String? task;
  final List<GateResult> results;

  bool get ok => results.every((r) => r.status != GateStatus.fail);

  /// Há falhas e todas são interferência: rechecar ao fim da onda.
  bool get onlyInterference =>
      !ok &&
      results
          .where((r) => r.status == GateStatus.fail)
          .every((r) => r.onlyInterference);

  int get failureCount => results
      .where((r) => r.status == GateStatus.fail)
      .fold(0, (n, r) => n + r.failures.length);
}
