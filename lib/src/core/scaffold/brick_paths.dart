import 'package:file/file.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:path/path.dart' as p;

final _wordBoundary = RegExp('[A-Z]?[a-z0-9]+|[A-Z]+(?![a-z])');

List<String> _words(String input) => [
  for (final m in _wordBoundary.allMatches(input)) m.group(0)!.toLowerCase(),
];

String _cap(String w) =>
    w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}';

/// Conversões de caixa usadas nos caminhos dos bricks (mesma semântica do
/// mason para os casos do kit).
String recase(String value, String method) {
  final words = _words(value);
  return switch (method) {
    'snakeCase' => words.join('_'),
    'paramCase' => words.join('-'),
    'pascalCase' => words.map(_cap).join(),
    'camelCase' =>
      words.isEmpty ? '' : words.first + words.skip(1).map(_cap).join(),
    'lowerCase' => value.toLowerCase(),
    'upperCase' => value.toUpperCase(),
    _ => throw FormatException('conversão "$method" não suportada'),
  };
}

final _tag = RegExp(r'\{\{\{?\s*([a-z_]+)(?:\.([a-zA-Z]+)\(\))?\s*\}?\}\}');

/// Renderiza um caminho de template (`{{{x}}}`, `{{x}}`, `{{x.snakeCase()}}`).
String renderBrickPath(String template, Map<String, Object?> vars) =>
    template.replaceAllMapped(_tag, (m) {
      final value = vars[m.group(1)];
      if (value == null) {
        throw FormatException('variável "${m.group(1)}" sem valor');
      }
      final method = m.group(2);
      return method == null ? '$value' : recase('$value', method);
    });

/// Arquivos de template do brick (caminhos relativos a `__brick__/`).
List<String> brickTemplatePaths(FileSystem fs, KitBrick brick) {
  final root = fs.directory(p.join(brick.path, '__brick__'));
  if (!root.existsSync()) return const [];
  return [
    for (final f in root.listSync(recursive: true).whereType<File>())
      p.relative(f.path, from: root.path).replaceAll(r'\', '/'),
  ]..sort();
}

/// Caminhos (relativos à raiz do projeto) que o brick geraria com [vars].
List<String> brickOutputPaths(
  FileSystem fs,
  KitBrick brick,
  Map<String, Object?> vars,
) => [
  for (final t in brickTemplatePaths(fs, brick))
    p.posix.normalize(renderBrickPath(t, vars)),
];

/// Camada de um caminho de template: `test` (começa em `{{{test_path}}}`),
/// `domain`, `data`, `presentation` ou `other`.
String templateLayer(String templatePath) {
  final segments = p.posix.split(templatePath);
  if (segments.first.contains('test_path')) return 'test';
  for (final layer in const ['domain', 'data', 'presentation']) {
    if (segments.contains(layer)) return layer;
  }
  return 'other';
}

/// Arquivo que só marca estrutura de pasta (não conta para camada nem
/// `owns`; está em `generated_globs` por padrão).
bool isStructural(String path) => p.posix.basename(path) == '.gitkeep';

/// Camadas que o brick gera, ignorando arquivos estruturais (`.gitkeep`).
Set<String> brickLayers(FileSystem fs, KitBrick brick) => {
  for (final t in brickTemplatePaths(fs, brick))
    if (!isStructural(t)) templateLayer(t),
};
