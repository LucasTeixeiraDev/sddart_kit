import 'dart:convert';

import 'package:flutter_sdd/src/core/config/yaml_writer.dart';
import 'package:path/path.dart' as p;

/// Marca que identifica arquivos gerados (buscada nas primeiras linhas).
const generatedMarker = 'gerado por sdd v';

String generatedNotice(String version) =>
    '$generatedMarker$version — não edite; use .sdd/overrides/ ou o kit';

/// Arquivo gerado por um adapter (caminho relativo à raiz do projeto).
class GeneratedFile {
  GeneratedFile.text(this.path, String text) : bytes = utf8.encode(text);

  GeneratedFile.binary(this.path, this.bytes);

  final String path;
  final List<int> bytes;
}

/// Estilo de arquivo de hooks de cada ferramenta.
enum HookStyle {
  /// `.claude/settings.json`: `{hooks: {Evento: [{matcher, hooks: [...]}]}}`.
  claudeSettings,

  /// `.cursor/hooks.json`: `{version: 1, hooks: {evento: [{command}]}}`.
  cursorHooks,
}

/// Entradas de hook gerenciadas pelo sdd num arquivo JSON do usuário.
/// Lista vazia significa "remover as entradas do sdd, se houver".
class HookRegistration {
  const HookRegistration(this.path, this.style, this.entries);

  final String path;
  final HookStyle style;

  /// Evento → entradas no formato da ferramenta.
  final Map<String, List<Map<String, Object?>>> entries;
}

/// Saída de um adapter.
class AdapterOutput {
  const AdapterOutput({
    this.files = const [],
    this.hooks = const [],
    this.warnings = const [],
  });

  final List<GeneratedFile> files;
  final List<HookRegistration> hooks;
  final List<String> warnings;
}

/// Markdown gerado: frontmatter primeiro, depois o aviso, depois o corpo.
String generatedMarkdown(
  Map<String, Object?>? frontmatter,
  String body,
  String version,
) {
  final buffer = StringBuffer();
  if (frontmatter != null && frontmatter.isNotEmpty) {
    buffer
      ..writeln('---')
      ..write(toYaml(frontmatter))
      ..writeln('---');
  }
  buffer
    ..writeln('<!-- ${generatedNotice(version)} -->')
    ..writeln()
    ..write(body.trimRight())
    ..writeln();
  return buffer.toString();
}

/// Se o conteúdo tem o aviso de gerado pelo sdd nas primeiras linhas.
bool hasGeneratedMarker(String content) =>
    content.split('\n').take(40).any((l) => l.contains(generatedMarker));

/// Se o arquivo leva o aviso (senão, só o manifesto o identifica).
/// Arquivos em `.sdd/` (templates exportados) não levam aviso porque são
/// copiados pelos agentes para as specs (D-024).
bool supportsMarker(String path) =>
    !path.startsWith('.sdd/') &&
    const {'.md', '.mdc'}.contains(p.extension(path));
