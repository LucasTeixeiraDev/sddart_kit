/// Resultado funcional: [Ok] ou [Err].
sealed class Result<T, E> {
  const Result();
}

/// Sucesso.
final class Ok<T, E> extends Result<T, E> {
  /// Cria um sucesso.
  const Ok(this.value);

  /// Valor.
  final T value;
}

/// Falha.
final class Err<T, E> extends Result<T, E> {
  /// Cria uma falha.
  const Err(this.error);

  /// Erro.
  final E error;
}
