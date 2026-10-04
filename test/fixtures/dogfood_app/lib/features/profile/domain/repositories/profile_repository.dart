import 'package:loja_app/core/result/result.dart';
import 'package:loja_app/features/profile/domain/entities/profile.dart';
import 'package:loja_app/features/profile/domain/failures/profile_failure.dart';

/// Contrato de profile: nunca lança, sempre retorna [Result].
abstract interface class ProfileRepository {
  /// Busca o perfil do usuário logado.
  Future<Result<Profile, ProfileFailure>> fetchProfile();
}
