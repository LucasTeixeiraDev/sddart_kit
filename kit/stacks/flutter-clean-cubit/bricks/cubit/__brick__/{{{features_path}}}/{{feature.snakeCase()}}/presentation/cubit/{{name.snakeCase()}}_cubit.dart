import 'package:flutter_bloc/flutter_bloc.dart';
import '{{{result_import}}}';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/domain/failures/{{feature.snakeCase()}}_failure.dart';
import 'package:{{{package}}}/{{{features_import}}}/{{feature.snakeCase()}}/domain/usecases/{{usecase.snakeCase()}}_use_case.dart';

part '{{name.snakeCase()}}_state.dart';

/// Estado da tela de {{name}}.
class {{name.pascalCase()}}Cubit extends Cubit<{{name.pascalCase()}}State> {
  /// Cria o cubit no estado inicial.
  {{name.pascalCase()}}Cubit(this._{{usecase.camelCase()}})
      : super(const {{name.pascalCase()}}Initial());

  final {{usecase.pascalCase()}}UseCase _{{usecase.camelCase()}};

  /// Executa {{usecase}} e emite Loading e o resultado.
  Future<void> {{usecase.camelCase()}}() async {
    emit(const {{name.pascalCase()}}Loading());
    final result = await _{{usecase.camelCase()}}();
    if (isClosed) return;
    emit(switch (result) {
      Ok() => const {{name.pascalCase()}}Success(),
      Err(:final error) => {{name.pascalCase()}}Error(error),
    });
  }
}
