/// Problema encontrado ao validar o `config.yaml`.
class ConfigIssue {
  const ConfigIssue(this.path, this.message, {this.isWarning = false});

  /// Caminho do campo, ex.: `commands.test`.
  final String path;
  final String message;
  final bool isWarning;

  @override
  String toString() => '$path: $message';
}

/// Config inválido: carrega todas as falhas encontradas, não só a primeira.
class ConfigException implements Exception {
  const ConfigException(this.issues);

  final List<ConfigIssue> issues;

  @override
  String toString() => issues.join('\n');
}
