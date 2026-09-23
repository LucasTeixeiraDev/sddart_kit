import 'package:flutter_sdd/src/core/config/sdd_config.dart';

/// Camada de onde um item do kit veio.
enum KitLayer { core, stack, override }

/// Ferramentas abstratas usadas no kit (traduzidas pelos adapters).
enum AbstractTool {
  read,
  search,
  edit,
  write,
  bash;

  static AbstractTool? tryParse(String value) =>
      values.where((t) => t.name == value).firstOrNull;
}

/// Prefixo de todos os itens gerados, para não colidir com os do usuário.
const generatedPrefix = 'sdd-';

String generatedName(String canonical) => '$generatedPrefix$canonical';

sealed class KitItem {
  const KitItem({
    required this.name,
    required this.description,
    required this.body,
    required this.layer,
    required this.sourcePath,
  });

  final String name;
  final String description;
  final String body;
  final KitLayer layer;

  /// Arquivo de origem (para mensagens de erro).
  final String sourcePath;
}

class KitAgent extends KitItem {
  const KitAgent({
    required super.name,
    required super.description,
    required super.body,
    required super.layer,
    required super.sourcePath,
    required this.tier,
    required this.tools,
    required this.readonly,
    this.tierVariants = const [],
    this.skills = const [],
    this.bashAllow = const [],
  });

  final Tier tier;
  final List<Tier> tierVariants;
  final List<AbstractTool> tools;
  final bool readonly;

  /// Nomes canônicos das skills pré-carregadas.
  final List<String> skills;

  /// Prefixos de comando Bash permitidos; vazio = sem restrição por hook.
  final List<String> bashAllow;
}

/// Arquivo de apoio de uma skill (caminho relativo à pasta da skill).
class SkillFile {
  const SkillFile(this.relativePath, this.bytes);

  final String relativePath;
  final List<int> bytes;
}

class KitSkill extends KitItem {
  const KitSkill({
    required super.name,
    required super.description,
    required super.body,
    required super.layer,
    required super.sourcePath,
    this.files = const [],
  });

  final List<SkillFile> files;
}

class KitRule extends KitItem {
  const KitRule({
    required super.name,
    required super.description,
    required super.body,
    required super.layer,
    required super.sourcePath,
    required this.globs,
    required this.always,
  });

  final List<String> globs;
  final bool always;
}

class KitCommand extends KitItem {
  const KitCommand({
    required super.name,
    required super.description,
    required super.body,
    required super.layer,
    required super.sourcePath,
    this.args,
  });

  /// Dica de argumentos, ex.: `<spec>`.
  final String? args;
}

/// Kit resolvido (core + stack + overrides), ordenado por nome.
class KitBundle {
  const KitBundle({
    required this.agents,
    required this.skills,
    required this.rules,
    required this.commands,
    required this.templates,
  });

  final List<KitAgent> agents;
  final List<KitSkill> skills;
  final List<KitRule> rules;
  final List<KitCommand> commands;

  /// Caminho relativo a `templates/` → conteúdo.
  final Map<String, String> templates;
}

/// Erro de conteúdo do kit ou dos overrides.
class KitException implements Exception {
  const KitException(this.issues);

  final List<String> issues;

  @override
  String toString() => issues.join('\n');
}
