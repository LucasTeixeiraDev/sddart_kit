import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '{{{result_import}}}';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/domain/failures/{{feature.snakeCase()}}_failure.dart';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/domain/usecases/{{usecase.snakeCase()}}_use_case.dart';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/presentation/cubit/{{name.snakeCase()}}_cubit.dart';

class _MockUseCase extends Mock implements {{usecase.pascalCase()}}UseCase {}

void main() {
  late _MockUseCase useCase;

  setUp(() => useCase = _MockUseCase());

  blocTest<{{name.pascalCase()}}Cubit, {{name.pascalCase()}}State>(
    '[{{ac}}] emite Loading e Success',
    build: () {
      when(() => useCase()).thenAnswer(
        (_) async => const Ok<void, {{feature.pascalCase()}}Failure>(null),
      );
      return {{name.pascalCase()}}Cubit(useCase);
    },
    act: (cubit) => cubit.{{usecase.camelCase()}}(),
    expect: () => [
      const {{name.pascalCase()}}Loading(),
      const {{name.pascalCase()}}Success(),
    ],
  );

  blocTest<{{name.pascalCase()}}Cubit, {{name.pascalCase()}}State>(
    '[{{ac}}] emite Loading e Error com a falha',
    build: () {
      when(() => useCase()).thenAnswer(
        (_) async => const Err<void, {{feature.pascalCase()}}Failure>(
          {{feature.pascalCase()}}UnexpectedFailure(),
        ),
      );
      return {{name.pascalCase()}}Cubit(useCase);
    },
    act: (cubit) => cubit.{{usecase.camelCase()}}(),
    expect: () => [
      const {{name.pascalCase()}}Loading(),
      isA<{{name.pascalCase()}}Error>().having(
        (s) => s.failure,
        'failure',
        isA<{{feature.pascalCase()}}UnexpectedFailure>(),
      ),
    ],
  );
}
