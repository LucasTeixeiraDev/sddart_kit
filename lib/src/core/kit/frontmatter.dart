import 'package:flutter_sdd/src/core/config/yaml_utils.dart';
import 'package:yaml/yaml.dart';

/// Documento markdown com frontmatter YAML opcional.
class FrontmatterDoc {
  const FrontmatterDoc(this.data, this.body);

  final Map<String, Object?> data;

  /// Corpo sem o frontmatter (sem a quebra de linha inicial).
  final String body;
}

final _fence = RegExp(r'^---[ \t]*$', multiLine: true);

/// Separa frontmatter (`---` ... `---`) e corpo.
///
/// Lança [FormatException] se o frontmatter existir mas for inválido.
FrontmatterDoc parseFrontmatter(String source) {
  final text = source.replaceAll('\r\n', '\n');
  if (!text.startsWith('---')) return FrontmatterDoc(const {}, text);
  final matches = _fence.allMatches(text).toList();
  if (matches.isEmpty || matches.first.start != 0 || matches.length < 2) {
    throw const FormatException('frontmatter sem "---" de fechamento');
  }
  final yamlText = text.substring(matches[0].end, matches[1].start);
  final Object? raw;
  try {
    raw = loadPlainYaml(yamlText);
  } on YamlException catch (e) {
    throw FormatException('frontmatter inválido: ${e.message}');
  }
  if (raw != null && raw is! Map<String, Object?>) {
    throw const FormatException('frontmatter deve ser um mapa');
  }
  var body = text.substring(matches[1].end);
  if (body.startsWith('\n')) body = body.substring(1);
  return FrontmatterDoc((raw as Map<String, Object?>?) ?? const {}, body);
}
