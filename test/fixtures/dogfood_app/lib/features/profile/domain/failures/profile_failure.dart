/// Falhas da feature profile. O repository mapeia Exception → Failure.
///
/// Subclasses precisam ficar neste arquivo (exigência de `sealed`).
sealed class ProfileFailure {
  /// Cria a falha com uma [message] opcional (diagnóstico, não para UI).
  const ProfileFailure([this.message]);

  /// Detalhe técnico opcional.
  final String? message;
}

/// O backend não encontrou o perfil (HTTP 404, código `PRF_404`).
final class ProfileNotFoundFailure extends ProfileFailure {
  /// Cria a falha.
  const ProfileNotFoundFailure([super.message]);
}

/// Falha de rede ou de transporte.
final class ProfileNetworkFailure extends ProfileFailure {
  /// Cria a falha.
  const ProfileNetworkFailure([super.message]);
}

/// Exception não mapeada (já reportada ao Crashlytics pelo repository).
final class ProfileUnexpectedFailure extends ProfileFailure {
  /// Cria a falha inesperada.
  const ProfileUnexpectedFailure([super.message]);
}
