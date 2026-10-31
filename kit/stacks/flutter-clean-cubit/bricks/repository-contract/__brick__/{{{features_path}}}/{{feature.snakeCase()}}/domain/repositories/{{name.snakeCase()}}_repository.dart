/// Contrato de {{name}}.
///
/// Cada método retorna `Result<T, {{feature.pascalCase()}}Failure>` e nunca
/// lança (skill `sdd-result-failure`). As assinaturas vêm do plano.
abstract interface class {{name.pascalCase()}}Repository {}
