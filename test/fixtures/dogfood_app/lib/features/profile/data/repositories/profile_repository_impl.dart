import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:loja_app/core/result/result.dart';
import 'package:loja_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:loja_app/features/profile/domain/entities/profile.dart';
import 'package:loja_app/features/profile/domain/failures/profile_failure.dart';
import 'package:loja_app/features/profile/domain/repositories/profile_repository.dart';

/// Fronteira de erro: nenhuma exception atravessa este repository.
class ProfileRepositoryImpl implements ProfileRepository {
  /// Cria o repository sobre o datasource.
  const ProfileRepositoryImpl(this._dataSource);

  final ProfileRemoteDataSource _dataSource;

  @override
  Future<Result<Profile, ProfileFailure>> fetchProfile() async {
    try {
      final dto = await _dataSource.fetchProfile();
      return Ok(dto.toEntity());
    } on ProfileNotFoundException {
      return const Err(ProfileNotFoundFailure());
    } on DioException catch (e) {
      return Err(ProfileNetworkFailure(e.message));
    } on Exception catch (e, s) {
      // Não mapeada: não engolir; chega ao FlutterError.onError (Crashlytics).
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: s));
      return Err(ProfileUnexpectedFailure(e.toString()));
    }
  }
}
