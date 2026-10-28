import '{{{result_import}}}';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/domain/failures/{{feature.snakeCase()}}_failure.dart';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/domain/repositories/{{repository.snakeCase()}}_repository.dart';

/// Caso de uso {{name}}: nunca lança, devolve o [Result] do repository.
class {{name.pascalCase()}}UseCase {
  /// Cria o caso de uso sobre o repository.
  const {{name.pascalCase()}}UseCase(this._repository);

  final {{repository.pascalCase()}}Repository _repository;

  /// Executa o caso de uso.
  Future<Result<void, {{feature.pascalCase()}}Failure>> call() =>
      _repository.{{name.camelCase()}}();
}
