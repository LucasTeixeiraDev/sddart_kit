import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/data/datasources/{{name.snakeCase()}}_remote_data_source.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late {{name.pascalCase()}}RemoteDataSourceImpl dataSource;

  setUp(() {
    dio = _MockDio();
    dataSource = {{name.pascalCase()}}RemoteDataSourceImpl(dio);
  });

  test('[{{ac}}] {{method.camelCase()}} chama o endpoint', () async {
    when(() => dio.get<void>(any())).thenAnswer(
      (_) async => Response<void>(requestOptions: RequestOptions()),
    );

    await dataSource.{{method.camelCase()}}();

    verify(() => dio.get<void>('/{{name.paramCase()}}')).called(1);
  });

  test('[{{ac}}] propaga DioException', () {
    when(() => dio.get<void>(any())).thenThrow(
      DioException(requestOptions: RequestOptions()),
    );

    expect(dataSource.{{method.camelCase()}}, throwsA(isA<DioException>()));
  });
}
