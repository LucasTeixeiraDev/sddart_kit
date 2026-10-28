part of '{{name.snakeCase()}}_cubit.dart';

/// Estados de [{{name.pascalCase()}}Cubit].
sealed class {{name.pascalCase()}}State {
  /// Construtor base.
  const {{name.pascalCase()}}State();
}

/// Estado inicial.
final class {{name.pascalCase()}}Initial extends {{name.pascalCase()}}State {
  /// Cria o estado.
  const {{name.pascalCase()}}Initial();
}

/// Em andamento.
final class {{name.pascalCase()}}Loading extends {{name.pascalCase()}}State {
  /// Cria o estado.
  const {{name.pascalCase()}}Loading();
}

/// Concluído com sucesso.
final class {{name.pascalCase()}}Success extends {{name.pascalCase()}}State {
  /// Cria o estado.
  const {{name.pascalCase()}}Success();
}

/// Falhou com [failure].
final class {{name.pascalCase()}}Error extends {{name.pascalCase()}}State {
  /// Cria o estado com a falha.
  const {{name.pascalCase()}}Error(this.failure);

  /// Falha da feature.
  final {{feature.pascalCase()}}Failure failure;
}
