/// Tier abstrato de modelo. O kit nunca cita nomes de modelo.
enum Tier {
  deep,
  standard,
  fast;

  static Tier? tryParse(String value) =>
      values.where((t) => t.name == value).firstOrNull;
}

/// Ferramentas para as quais o `sync` gera arquivos.
enum Target {
  claude,
  cursor;

  static Target? tryParse(String value) =>
      values.where((t) => t.name == value).firstOrNull;
}

enum ErrorHandling { result, exceptions }

/// Mapeamento de um tier para modelo: valor padrão + override por ferramenta.
class ModelMapping {
  const ModelMapping({this.defaultModel, this.perTarget = const {}});

  final String? defaultModel;
  final Map<Target, String> perTarget;

  /// Modelo explícito para [target], ou o padrão; `null` se nenhum.
  String? forTarget(Target target) => perTarget[target] ?? defaultModel;

  /// Se [target] tem valor próprio (não herdado do padrão).
  bool hasExplicit(Target target) => perTarget.containsKey(target);
}

class ProjectConfig {
  const ProjectConfig({
    required this.featuresPath,
    required this.testPath,
    required this.stateManagement,
    required this.errorHandling,
    required this.generatedGlobs,
  });

  final String featuresPath;
  final String testPath;
  final String stateManagement;
  final ErrorHandling errorHandling;
  final List<String> generatedGlobs;
}

class CoverageConfig {
  const CoverageConfig({required this.min, required this.paths});

  final num min;
  final List<String> paths;
}

class TraceabilityConfig {
  const TraceabilityConfig({
    required this.acPattern,
    required this.testTagPattern,
  });

  final RegExp acPattern;
  final RegExp testTagPattern;
}

class DodConfig {
  const DodConfig({
    required this.gates,
    required this.coverage,
    required this.traceability,
    required this.checklist,
  });

  final List<String> gates;
  final CoverageConfig coverage;
  final TraceabilityConfig traceability;
  final List<String> checklist;
}

class ExecutionConfig {
  const ExecutionConfig({
    required this.maxFixAttempts,
    required this.escalateTo,
  });

  final int maxFixAttempts;
  final Tier escalateTo;
}

/// Como o Cursor recebe skills e agentes (ver docs/adapters.md).
enum CursorSkills {
  /// Usa `.claude/skills/`, que o Cursor também lê (quando claude é target).
  shared,

  /// Gera cópia própria em `.cursor/skills/`.
  own,
}

enum CursorAgents {
  /// Gera `.cursor/agents/` com `model` e `readonly` próprios.
  own,

  /// Usa apenas `.claude/agents/` (quando claude é target).
  shared,
}

class AdaptersConfig {
  const AdaptersConfig({
    this.cursorSkills = CursorSkills.shared,
    this.cursorAgents = CursorAgents.own,
  });

  final CursorSkills cursorSkills;
  final CursorAgents cursorAgents;
}

class HooksConfig {
  const HooksConfig({required this.formatOnEdit});

  final bool formatOnEdit;
}

/// `.sdd/config.yaml` validado.
class SddConfig {
  const SddConfig({
    required this.version,
    required this.stack,
    required this.targets,
    required this.language,
    required this.project,
    required this.commands,
    required this.dod,
    required this.execution,
    required this.learningsWarnAfter,
    required this.models,
    required this.hooks,
    this.adapters = const AdaptersConfig(),
  });

  static const currentVersion = 1;

  /// Gates calculados pelo próprio CLI (não executam um comando do config).
  static const builtinGates = {'coverage', 'traceability'};

  final int version;
  final String stack;
  final List<Target> targets;
  final String language;
  final ProjectConfig project;

  /// Comandos por nome (`format`, `analyze`, `test`, `test_all`, `codegen` e
  /// gates opcionais como `custom_lint`).
  final Map<String, String> commands;
  final DodConfig dod;
  final ExecutionConfig execution;
  final int learningsWarnAfter;
  final Map<Tier, ModelMapping> models;
  final HooksConfig hooks;
  final AdaptersConfig adapters;

  bool hasTarget(Target target) => targets.contains(target);
}
