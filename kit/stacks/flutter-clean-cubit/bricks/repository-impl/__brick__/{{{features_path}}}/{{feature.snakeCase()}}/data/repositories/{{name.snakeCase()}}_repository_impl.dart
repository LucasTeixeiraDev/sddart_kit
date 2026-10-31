import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/domain/repositories/{{name.snakeCase()}}_repository.dart';

/// Fronteira de erro de {{name}}: cada método captura só `Exception`, mapeia
/// para Failures da feature e reporta as não mapeadas via
/// `FlutterError.reportError` (skill `sdd-result-failure`).
class {{name.pascalCase()}}RepositoryImpl implements {{name.pascalCase()}}Repository {
  /// Cria o repository.
  const {{name.pascalCase()}}RepositoryImpl();
}
