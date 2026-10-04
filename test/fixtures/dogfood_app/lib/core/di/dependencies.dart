import 'package:dio/dio.dart';
import 'package:loja_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:loja_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:loja_app/features/profile/domain/usecases/fetch_profile_use_case.dart';
import 'package:loja_app/features/profile/presentation/cubit/profile_cubit.dart';

/// Composição manual das dependências do app (sem service locator).
class Dependencies {
  /// Cria as dependências a partir do cliente HTTP.
  Dependencies(this._dio);

  final Dio _dio;

  /// Cubit da tela de perfil.
  ProfileCubit profileCubit() => ProfileCubit(
    FetchProfileUseCase(
      ProfileRepositoryImpl(ProfileRemoteDataSourceImpl(_dio)),
    ),
  );
}
