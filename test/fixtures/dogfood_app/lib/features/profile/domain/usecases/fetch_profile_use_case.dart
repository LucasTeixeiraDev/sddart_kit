import 'package:loja_app/core/result/result.dart';
import 'package:loja_app/features/profile/domain/entities/profile.dart';
import 'package:loja_app/features/profile/domain/failures/profile_failure.dart';
import 'package:loja_app/features/profile/domain/repositories/profile_repository.dart';

/// Caso de uso fetchProfile: nunca lança, devolve o [Result] do repository.
class FetchProfileUseCase {
  /// Cria o caso de uso sobre o repository.
  const FetchProfileUseCase(this._repository);

  final ProfileRepository _repository;

  /// Executa o caso de uso.
  Future<Result<Profile, ProfileFailure>> call() => _repository.fetchProfile();
}
