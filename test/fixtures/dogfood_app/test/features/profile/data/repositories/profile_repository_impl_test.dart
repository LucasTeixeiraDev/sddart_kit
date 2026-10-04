import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loja_app/core/result/result.dart';
import 'package:loja_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:loja_app/features/profile/data/models/profile_dto.dart';
import 'package:loja_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:loja_app/features/profile/domain/entities/profile.dart';
import 'package:loja_app/features/profile/domain/failures/profile_failure.dart';
import 'package:mocktail/mocktail.dart';

class _MockDataSource extends Mock implements ProfileRemoteDataSource {}

void main() {
  late _MockDataSource dataSource;
  late ProfileRepositoryImpl repository;
  late List<FlutterErrorDetails> reported;
  final originalOnError = FlutterError.onError;

  setUp(() {
    dataSource = _MockDataSource();
    repository = ProfileRepositoryImpl(dataSource);
    reported = [];
    FlutterError.onError = reported.add;
  });

  tearDown(() => FlutterError.onError = originalOnError);

  Future<ProfileFailure> failureFor(Object error) async {
    when(() => dataSource.fetchProfile()).thenThrow(error);
    final result = await repository.fetchProfile();
    return (result as Err<Profile, ProfileFailure>).error;
  }

  test('sucesso converte o DTO em entidade', () async {
    when(() => dataSource.fetchProfile()).thenAnswer(
      (_) async => const ProfileDto(name: 'Ana', email: 'ana@loja.dev'),
    );

    final result = await repository.fetchProfile();

    expect((result as Ok<Profile, ProfileFailure>).value.name, 'Ana');
  });

  test('ProfileNotFoundException vira ProfileNotFoundFailure', () async {
    expect(
      await failureFor(ProfileNotFoundException()),
      isA<ProfileNotFoundFailure>(),
    );
  });

  test('DioException vira ProfileNetworkFailure', () async {
    expect(
      await failureFor(DioException(requestOptions: RequestOptions())),
      isA<ProfileNetworkFailure>(),
    );
  });

  test('exception não mapeada vira Unexpected e é reportada', () async {
    expect(await failureFor(Exception('x')), isA<ProfileUnexpectedFailure>());
    expect(reported, hasLength(1));
  });
}
