import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '{{{result_import}}}';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/domain/failures/{{feature.snakeCase()}}_failure.dart';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/domain/repositories/{{repository.snakeCase()}}_repository.dart';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/domain/usecases/{{name.snakeCase()}}_use_case.dart';

class _MockRepository extends Mock
    implements {{repository.pascalCase()}}Repository {}

void main() {
  late _MockRepository repository;
  late {{name.pascalCase()}}UseCase useCase;

  setUp(() {
    repository = _MockRepository();
    useCase = {{name.pascalCase()}}UseCase(repository);
  });

  test('[{{ac}}] delega ao repository e devolve o Result', () async {
    when(() => repository.{{name.camelCase()}}()).thenAnswer(
      (_) async => const Ok<void, {{feature.pascalCase()}}Failure>(null),
    );

    expect(await useCase(), isA<Ok<void, {{feature.pascalCase()}}Failure>>());
    verify(() => repository.{{name.camelCase()}}()).called(1);
  });
}
