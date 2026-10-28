import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loja_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late ProfileRemoteDataSourceImpl dataSource;

  setUp(() {
    dio = _MockDio();
    dataSource = ProfileRemoteDataSourceImpl(dio);
  });

  test('retorna o DTO do perfil', () async {
    when(() => dio.get<Map<String, dynamic>>('/profile')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(),
        data: {'name': 'Ana', 'email': 'ana@loja.dev'},
      ),
    );

    final dto = await dataSource.fetchProfile();

    expect(dto.name, 'Ana');
  });

  test('PRF_404 vira ProfileNotFoundException', () {
    when(() => dio.get<Map<String, dynamic>>('/profile')).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 404,
          data: {'code': 'PRF_404'},
        ),
      ),
    );

    expect(dataSource.fetchProfile, throwsA(isA<ProfileNotFoundException>()));
  });
}
