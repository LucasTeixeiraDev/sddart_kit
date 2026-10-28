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
    this.writeAllow = const [],
  });

  final Tier tier;
  final List<Tier> tierVariants;
  final List<AbstractTool> tools;
  final bool readonly;

  /// Nomes canônicos das skills pré-carregadas.
  final List<String> skills;

  /// Prefixos de comando Bash permitidos; vazio = sem restrição por hook.
  final List<String> bashAllow;

  /// Globs (relativos à raiz) que um agente `readonly` pode gravar, ex.:
  /// `specs/*/review.md`. No Claude vira a tool Write + hook de guarda; no
  /// Cursor o agente continua readonly e devolve o conteúdo (D-039).
  final List<String> writeAllow;
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

/// Variável declarada no `brick.yaml`.
class BrickVar {
  const BrickVar({
    required this.name,
    this.type = 'string',
    this.description,
    this.defaultValue,
  });

  final String name;
  final String type;
  final String? description;
  final Object? defaultValue;

  bool get required => defaultValue == null;
}

/// Brick mason (`bricks/<nome>/brick.yaml` + `__brick__/`).
class KitBrick {
  const KitBrick({
    required this.name,
    required this.description,
    required this.path,
    required this.layer,
    required this.vars,
  });

  final String name;
  final String description;

  /// Diretório do brick (contém `brick.yaml`).
  final String path;
  final KitLayer layer;
  final List<BrickVar> vars;
}

/// Kit resolvido (core + stack + overrides), ordenado por nome.
class KitBundle {
  const KitBundle({
    required this.agents,
    required this.skills,
    required this.rules,
    required this.commands,
    required this.templates,
    this.bricks = const [],
  });

  final List<KitAgent> agents;
  final List<KitSkill> skills;
  final List<KitRule> rules;
  final List<KitCommand> commands;

  /// Caminho relativo a `templates/` → conteúdo.
  final Map<String, String> templates;
  final List<KitBrick> bricks;

  KitBrick? brick(String name) =>
      bricks.where((b) => b.name == name).firstOrNull;
}

/// Erro de conteúdo do kit ou dos overrides.
class KitException implements Exception {
  const KitException(this.issues);

  final List<String> issues;

  @override
  String toString() => issues.join('\n');
}
