import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loja_app/core/result/result.dart';
import 'package:loja_app/features/profile/domain/entities/profile.dart';
import 'package:loja_app/features/profile/domain/failures/profile_failure.dart';
import 'package:loja_app/features/profile/domain/usecases/fetch_profile_use_case.dart';

part 'profile_state.dart';

/// Estado da tela de perfil.
class ProfileCubit extends Cubit<ProfileState> {
  /// Cria o cubit no estado inicial.
  ProfileCubit(this._fetchProfile) : super(const ProfileInitial());

  final FetchProfileUseCase _fetchProfile;

  /// Carrega o perfil e emite Loading e o resultado.
  Future<void> load() async {
    emit(const ProfileLoading());
    final result = await _fetchProfile();
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => ProfileSuccess(value),
      Err(:final error) => ProfileError(error),
    });
  }
}
