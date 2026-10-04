part of 'profile_cubit.dart';

/// Estados de [ProfileCubit].
sealed class ProfileState {
  /// Construtor base.
  const ProfileState();
}

/// Estado inicial.
final class ProfileInitial extends ProfileState {
  /// Cria o estado.
  const ProfileInitial();
}

/// Em andamento.
final class ProfileLoading extends ProfileState {
  /// Cria o estado.
  const ProfileLoading();
}

/// Perfil carregado.
final class ProfileSuccess extends ProfileState {
  /// Cria o estado com o perfil.
  const ProfileSuccess(this.profile);

  /// Perfil carregado.
  final Profile profile;
}

/// Falhou com [failure].
final class ProfileError extends ProfileState {
  /// Cria o estado com a falha.
  const ProfileError(this.failure);

  /// Falha da feature.
  final ProfileFailure failure;
}
