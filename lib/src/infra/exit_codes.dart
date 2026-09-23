/// Exit codes estáveis do CLI.
abstract final class ExitCodes {
  /// Sucesso.
  static const ok = 0;

  /// Falha de gate ou de validação.
  static const failure = 1;

  /// Erro de uso ou de configuração.
  static const usage = 2;
}
