import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loja_app/features/profile/domain/failures/profile_failure.dart';
import 'package:loja_app/features/profile/presentation/cubit/profile_cubit.dart';

/// Tela de perfil: só lê estado e chama o cubit.
class ProfilePage extends StatelessWidget {
  /// Cria a tela.
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) => switch (state) {
        ProfileInitial() ||
        ProfileLoading() => const Center(child: CircularProgressIndicator()),
        ProfileSuccess(:final profile) => ListTile(
          title: Text(profile.name),
          subtitle: Text(profile.email),
        ),
        ProfileError(:final failure) => Center(
          child: Text(switch (failure) {
            ProfileNotFoundFailure() => 'Perfil não encontrado',
            ProfileNetworkFailure() => 'Sem conexão',
            ProfileUnexpectedFailure() => 'Algo deu errado',
          }),
        ),
      },
    );
  }
}
