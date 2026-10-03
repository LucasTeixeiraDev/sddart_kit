import 'package:dio/dio.dart';

/// Datasource remoto de {{name}}. Lança exceptions (técnicas ou de negócio);
/// o repository as mapeia para Failures.
abstract interface class {{name.pascalCase()}}RemoteDataSource {
  /// Chama o backend; lança exception em caso de erro.
  Future<void> {{method.camelCase()}}();
}

/// Implementação Dio de [{{name.pascalCase()}}RemoteDataSource].
class {{name.pascalCase()}}RemoteDataSourceImpl
    implements {{name.pascalCase()}}RemoteDataSource {
  /// Cria o datasource com o [Dio] configurado.
  const {{name.pascalCase()}}RemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<void> {{method.camelCase()}}() async {
    await _dio.get<void>('/{{name.paramCase()}}');
  }
}
