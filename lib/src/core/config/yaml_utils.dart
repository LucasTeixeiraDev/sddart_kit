import 'package:yaml/yaml.dart';

/// Converte nós do pacote `yaml` em Map/List/escalares Dart puros.
Object? toPlain(Object? node) => switch (node) {
  YamlMap() => {
    for (final e in node.nodes.entries)
      '${(e.key as YamlNode).value}': toPlain(e.value),
  },
  YamlList() => [for (final n in node.nodes) toPlain(n)],
  YamlScalar() => node.value,
  _ => node,
};

/// Faz o parse de um documento YAML para estruturas Dart puras.
Object? loadPlainYaml(String source, {Uri? sourceUrl}) =>
    toPlain(loadYamlNode(source, sourceUrl: sourceUrl));

/// Merge profundo: mapas são combinados recursivamente; listas e escalares de
/// [override] substituem os de [base].
Map<String, Object?> deepMerge(
  Map<String, Object?> base,
  Map<String, Object?> override,
) {
  final result = <String, Object?>{...base};
  for (final MapEntry(:key, :value) in override.entries) {
    final current = result[key];
    result[key] =
        current is Map<String, Object?> && value is Map<String, Object?>
        ? deepMerge(current, value)
        : value;
  }
  return result;
}
