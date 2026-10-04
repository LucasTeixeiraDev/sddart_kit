import 'package:dio/dio.dart';
import 'package:loja_app/features/profile/data/models/profile_dto.dart';

/// O backend não encontrou o perfil (código `PRF_404`).
class ProfileNotFoundException implements Exception {}

/// Datasource remoto de profile. Lança exceptions (técnicas ou de negócio);
/// o repository as mapeia para Failures.
abstract interface class ProfileRemoteDataSource {
  /// Busca o perfil; lança [ProfileNotFoundException] ou [DioException].
  Future<ProfileDto> fetchProfile();
}

/// Implementação Dio de [ProfileRemoteDataSource].
class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  /// Cria o datasource com o [Dio] configurado.
  const ProfileRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<ProfileDto> fetchProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/profile');
      return ProfileDto.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.data case {'code': 'PRF_404'}) {
        throw ProfileNotFoundException();
      }
      rethrow;
    }
  }
}
