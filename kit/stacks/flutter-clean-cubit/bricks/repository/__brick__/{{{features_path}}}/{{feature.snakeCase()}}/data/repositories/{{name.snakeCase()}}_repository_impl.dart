import 'package:flutter/foundation.dart';
import '{{{result_import}}}';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/data/datasources/{{datasource.snakeCase()}}_remote_data_source.dart';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/domain/failures/{{feature.snakeCase()}}_failure.dart';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/domain/repositories/{{name.snakeCase()}}_repository.dart';

/// Fronteira de erro: nenhuma exception atravessa este repository.
class {{name.pascalCase()}}RepositoryImpl implements {{name.pascalCase()}}Repository {
  /// Cria o repository sobre o datasource.
  const {{name.pascalCase()}}RepositoryImpl(this._dataSource);

  final {{datasource.pascalCase()}}RemoteDataSource _dataSource;

  @override
  Future<Result<void, {{feature.pascalCase()}}Failure>> {{method.camelCase()}}() async {
    try {
      await _dataSource.{{method.camelCase()}}();
      return const Ok(null);
      // Mapeie aqui as exceptions de negócio conhecidas (on XException),
      // antes do catch genérico.
    } on Exception catch (e, s) {
      // Não mapeada: não engolir; chega ao FlutterError.onError (Crashlytics).
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: s));
      return Err({{feature.pascalCase()}}UnexpectedFailure(e.toString()));
    }
  }
}
