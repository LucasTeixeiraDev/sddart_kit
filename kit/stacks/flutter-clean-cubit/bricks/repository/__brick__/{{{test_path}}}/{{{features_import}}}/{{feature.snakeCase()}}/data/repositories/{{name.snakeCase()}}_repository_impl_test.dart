import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '{{{result_import}}}';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/data/datasources/{{datasource.snakeCase()}}_remote_data_source.dart';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/data/repositories/{{name.snakeCase()}}_repository_impl.dart';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/domain/failures/{{feature.snakeCase()}}_failure.dart';

class _MockDataSource extends Mock
    implements {{datasource.pascalCase()}}RemoteDataSource {}

void main() {
  late _MockDataSource dataSource;
  late {{name.pascalCase()}}RepositoryImpl repository;
  late List<FlutterErrorDetails> reported;
  final originalOnError = FlutterError.onError;

  setUp(() {
    dataSource = _MockDataSource();
    repository = {{name.pascalCase()}}RepositoryImpl(dataSource);
    reported = [];
    FlutterError.onError = reported.add;
  });

  tearDown(() => FlutterError.onError = originalOnError);

  test('[{{ac}}] retorna Ok quando o datasource conclui', () async {
    when(() => dataSource.{{method.camelCase()}}()).thenAnswer((_) async {});

    expect(await repository.{{method.camelCase()}}(), isA<Ok<void, {{feature.pascalCase()}}Failure>>());
  });

  test('[{{ac}}] exception não mapeada vira Unexpected e é reportada', () async {
    when(() => dataSource.{{method.camelCase()}}()).thenThrow(Exception('x'));

    final result = await repository.{{method.camelCase()}}();

    expect(
      result,
      isA<Err<void, {{feature.pascalCase()}}Failure>>().having(
        (e) => e.error,
        'error',
        isA<{{feature.pascalCase()}}UnexpectedFailure>(),
      ),
    );
    expect(reported, hasLength(1));
  });
}
