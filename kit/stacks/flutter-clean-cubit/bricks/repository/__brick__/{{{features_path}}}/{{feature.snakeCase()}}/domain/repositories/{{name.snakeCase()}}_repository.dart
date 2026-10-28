import '{{{result_import}}}';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/domain/failures/{{feature.snakeCase()}}_failure.dart';

/// Contrato de {{name}}: nunca lança, sempre retorna [Result].
abstract interface class {{name.pascalCase()}}Repository {
  /// Executa {{method}}.
  Future<Result<void, {{feature.pascalCase()}}Failure>> {{method.camelCase()}}();
}
