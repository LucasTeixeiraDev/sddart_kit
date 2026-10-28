/// Falhas da feature {{feature}}. O repository mapeia Exception → Failure.
///
/// Subclasses precisam ficar neste arquivo (exigência de `sealed`).
sealed class {{feature.pascalCase()}}Failure {
  /// Cria a falha com uma [message] opcional (diagnóstico, não para UI).
  const {{feature.pascalCase()}}Failure([this.message]);

  /// Detalhe técnico opcional.
  final String? message;
}

/// Exception não mapeada (já reportada ao Crashlytics pelo repository).
final class {{feature.pascalCase()}}UnexpectedFailure
    extends {{feature.pascalCase()}}Failure {
  /// Cria a falha inesperada.
  const {{feature.pascalCase()}}UnexpectedFailure([super.message]);
}
