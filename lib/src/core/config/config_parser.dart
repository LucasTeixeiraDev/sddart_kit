import 'package:flutter_sdd/src/core/config/config_defaults.dart';
import 'package:flutter_sdd/src/core/config/config_issue.dart';
import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/config/yaml_utils.dart';
import 'package:yaml/yaml.dart';

/// Resultado do parse: config válido + avisos não bloqueantes.
class ConfigParseResult {
  const ConfigParseResult(this.config, this.warnings);

  final SddConfig config;
  final List<ConfigIssue> warnings;
}

/// Faz o parse e valida o `config.yaml`.
///
/// Ordem de camadas: [coreConfigDefaults] → [stackDefaults] → documento.
/// Lança [ConfigException] com todos os erros encontrados.
ConfigParseResult parseConfig(
  String source, {
  Map<String, Object?> stackDefaults = const {},
}) {
  final Object? raw;
  try {
    raw = loadPlainYaml(source);
  } on YamlException catch (e) {
    throw ConfigException([ConfigIssue('(arquivo)', 'YAML inválido: $e')]);
  }
  if (raw != null && raw is! Map<String, Object?>) {
    throw ConfigException([
      ConfigIssue('(raiz)', 'esperado mapa, recebido ${_kind(raw)}'),
    ]);
  }
  final merged = deepMerge(
    deepMerge(coreConfigDefaults, stackDefaults),
    (raw as Map<String, Object?>?) ?? const {},
  );
  return _ConfigReader(merged).read();
}

/// Lê apenas `kit.stack`, necessário para carregar os defaults do stack antes
/// do parse completo. Retorna `null` se ausente ou ilegível.
String? peekStack(String source) {
  try {
    final raw = loadPlainYaml(source);
    if (raw is Map<String, Object?>) {
      final kit = raw['kit'];
      if (kit is Map<String, Object?> && kit['stack'] is String) {
        return kit['stack']! as String;
      }
    }
  } on YamlException {
    return null;
  }
  return null;
}

String _kind(Object? v) => switch (v) {
  null => 'nulo',
  String() => 'string',
  bool() => 'booleano',
  int() => 'inteiro',
  num() => 'número',
  List() => 'lista',
  Map() => 'mapa',
  _ => v.runtimeType.toString(),
};

class _ConfigReader {
  _ConfigReader(this.root);

  final Map<String, Object?> root;
  final errors = <ConfigIssue>[];
  final warnings = <ConfigIssue>[];

  static const _knownKeys = <String, Set<String>>{
    '': {
      'version',
      'kit',
      'targets',
      'language',
      'project',
      'commands',
      'dod',
      'execution',
      'memory',
      'models',
      'hooks',
      'adapters',
    },
    'kit': {'stack'},
    'adapters': {'cursor'},
    'adapters.cursor': {'skills', 'agents'},
    'project': {
      'features_path',
      'test_path',
      'state_management',
      'error_handling',
      'generated_globs',
    },
    'dod': {'gates', 'coverage', 'traceability', 'checklist'},
    'dod.coverage': {'min', 'paths'},
    'dod.traceability': {'ac_pattern', 'test_tag_pattern'},
    'execution': {'max_fix_attempts', 'escalate_to', 'max_review_cycles'},
    'memory': {'learnings_warn_after'},
    'models': {'deep', 'standard', 'fast'},
    'hooks': {'format_on_edit'},
  };

  ConfigParseResult read() {
    _checkUnknownKeys(root, '');

    final version = _int('version', min: 1);
    if (version != null && version != SddConfig.currentVersion) {
      _error(
        'version',
        'versão $version não suportada (esperado '
            '${SddConfig.currentVersion})',
      );
    }
    final stack = _string('kit.stack');
    final targets = _targets();
    final language = _string('language');
    if (language != null && language != 'pt-BR') {
      _warn('language', 'apenas pt-BR é suportado; valor ignorado');
    }
    final project = _project();
    final commands = _commands();
    final dod = _dod(commands);
    final execution = _execution();
    final learningsWarnAfter = _int('memory.learnings_warn_after', min: 1);
    final models = _models();
    final formatOnEdit = _bool('hooks.format_on_edit');
    final cursorSkills = _enum('adapters.cursor.skills', CursorSkills.values);
    final cursorAgents = _enum('adapters.cursor.agents', CursorAgents.values);

    if (errors.isNotEmpty) throw ConfigException(errors);
    return ConfigParseResult(
      SddConfig(
        version: version!,
        stack: stack!,
        targets: targets!,
        language: language!,
        project: project!,
        commands: commands!,
        dod: dod!,
        execution: execution!,
        learningsWarnAfter: learningsWarnAfter!,
        models: models!,
        hooks: HooksConfig(formatOnEdit: formatOnEdit!),
        adapters: AdaptersConfig(
          cursorSkills: cursorSkills!,
          cursorAgents: cursorAgents!,
        ),
      ),
      warnings,
    );
  }

  // ---- seções ---------------------------------------------------------------

  List<Target>? _targets() {
    final list = _stringList('targets', nonEmpty: true);
    if (list == null) return null;
    final result = <Target>[];
    for (final name in list) {
      final target = Target.tryParse(name);
      if (target == null) {
        _error('targets', 'valor "$name" inválido (use claude, cursor)');
      } else if (result.contains(target)) {
        _error('targets', '"$name" duplicado');
      } else {
        result.add(target);
      }
    }
    return result;
  }

  ProjectConfig? _project() {
    final featuresPath = _string('project.features_path');
    final testPath = _string('project.test_path');
    final stateManagement = _string('project.state_management');
    final errorHandling = _enum('project.error_handling', ErrorHandling.values);
    final globs = _stringList('project.generated_globs');
    if ([
      featuresPath,
      testPath,
      stateManagement,
      errorHandling,
      globs,
    ].contains(null)) {
      return null;
    }
    return ProjectConfig(
      featuresPath: featuresPath!,
      testPath: testPath!,
      stateManagement: stateManagement!,
      errorHandling: errorHandling!,
      generatedGlobs: globs!,
    );
  }

  Map<String, String>? _commands() {
    final map = _map('commands');
    if (map == null) return null;
    final result = <String, String>{};
    for (final MapEntry(:key, :value) in map.entries) {
      if (value is String && value.trim().isNotEmpty) {
        result[key] = value;
      } else {
        _error(
          'commands.$key',
          'esperado string não vazia, recebido ${_kind(value)}',
        );
      }
    }
    return result;
  }

  DodConfig? _dod(Map<String, String>? commands) {
    final gates = _stringList('dod.gates');
    if (gates != null && commands != null) {
      for (final gate in gates) {
        if (SddConfig.builtinGates.contains(gate)) continue;
        if (!commands.containsKey(gate)) {
          _error('dod.gates', 'gate "$gate" não tem comando em commands.$gate');
        }
      }
      if (gates.contains('coverage') && !commands.containsKey('test_all')) {
        _error('dod.gates', 'gate "coverage" exige commands.test_all');
      }
    }
    final min = _num('dod.coverage.min', min: 0, max: 100);
    final paths = _stringList('dod.coverage.paths');
    final acPattern = _regex('dod.traceability.ac_pattern');
    final tagPattern = _regex('dod.traceability.test_tag_pattern');
    if (tagPattern != null && !tagPattern.pattern.contains('(')) {
      _error(
        'dod.traceability.test_tag_pattern',
        'deve ter um grupo de captura com o ID do AC',
      );
    }
    final checklist = _stringList('dod.checklist');
    if ([gates, min, paths, acPattern, tagPattern, checklist].contains(null)) {
      return null;
    }
    return DodConfig(
      gates: gates!,
      coverage: CoverageConfig(min: min!, paths: paths!),
      traceability: TraceabilityConfig(
        acPattern: acPattern!,
        testTagPattern: tagPattern!,
      ),
      checklist: checklist!,
    );
  }

  ExecutionConfig? _execution() {
    final attempts = _int('execution.max_fix_attempts', min: 0);
    final escalateTo = _enum('execution.escalate_to', Tier.values);
    final reviewCycles = _int('execution.max_review_cycles', min: 1);
    if (attempts == null || escalateTo == null || reviewCycles == null) {
      return null;
    }
    return ExecutionConfig(
      maxFixAttempts: attempts,
      escalateTo: escalateTo,
      maxReviewCycles: reviewCycles,
    );
  }

  Map<Tier, ModelMapping>? _models() {
    final map = _map('models');
    if (map == null) return null;
    final result = <Tier, ModelMapping>{};
    for (final tier in Tier.values) {
      final path = 'models.${tier.name}';
      final value = map[tier.name];
      switch (value) {
        case String() when value.isNotEmpty:
          result[tier] = ModelMapping(defaultModel: value);
        case Map<String, Object?>():
          result[tier] = _modelMap(path, value);
        case null:
          _error(path, 'obrigatório');
        default:
          _error(
            path,
            'esperado string ou mapa {default, claude, cursor}, '
            'recebido ${_kind(value)}',
          );
      }
    }
    return result;
  }

  ModelMapping _modelMap(String path, Map<String, Object?> map) {
    String? defaultModel;
    final perTarget = <Target, String>{};
    for (final MapEntry(:key, :value) in map.entries) {
      if (value is! String || value.isEmpty) {
        _error('$path.$key', 'esperado string, recebido ${_kind(value)}');
        continue;
      }
      if (key == 'default') {
        defaultModel = value;
        continue;
      }
      final target = Target.tryParse(key);
      if (target == null) {
        _error('$path.$key', 'chave inválida (use default, claude, cursor)');
      } else {
        perTarget[target] = value;
      }
    }
    return ModelMapping(defaultModel: defaultModel, perTarget: perTarget);
  }

  // ---- leitura tipada -------------------------------------------------------

  Object? _at(String path) {
    Object? current = root;
    for (final part in path.split('.')) {
      if (current is! Map<String, Object?>) return null;
      current = current[part];
    }
    return current;
  }

  T? _typed<T>(String path, String expected) {
    final value = _at(path);
    if (value is T) return value;
    _error(
      path,
      value == null
          ? 'obrigatório ($expected)'
          : 'esperado $expected, recebido ${_kind(value)}',
    );
    return null;
  }

  String? _string(String path) {
    final value = _typed<String>(path, 'string');
    if (value != null && value.trim().isEmpty) {
      _error(path, 'não pode ser vazio');
      return null;
    }
    return value;
  }

  bool? _bool(String path) => _typed<bool>(path, 'booleano');

  Map<String, Object?>? _map(String path) =>
      _typed<Map<String, Object?>>(path, 'mapa');

  int? _int(String path, {int? min}) {
    final value = _typed<int>(path, 'inteiro');
    if (value != null && min != null && value < min) {
      _error(path, 'deve ser >= $min, recebido $value');
      return null;
    }
    return value;
  }

  num? _num(String path, {num? min, num? max}) {
    final value = _typed<num>(path, 'número');
    if (value == null) return null;
    if ((min != null && value < min) || (max != null && value > max)) {
      _error(path, 'deve estar entre $min e $max, recebido $value');
      return null;
    }
    return value;
  }

  List<String>? _stringList(String path, {bool nonEmpty = false}) {
    final value = _typed<List<Object?>>(path, 'lista de strings');
    if (value == null) return null;
    if (value.any((e) => e is! String)) {
      _error(path, 'esperado lista de strings');
      return null;
    }
    if (nonEmpty && value.isEmpty) {
      _error(path, 'não pode ser vazia');
      return null;
    }
    return value.cast<String>();
  }

  T? _enum<T extends Enum>(String path, List<T> values) {
    final value = _string(path);
    if (value == null) return null;
    final match = values.where((v) => v.name == value).firstOrNull;
    if (match == null) {
      _error(
        path,
        'valor "$value" inválido (use ${values.map((v) => v.name).join(', ')})',
      );
    }
    return match;
  }

  RegExp? _regex(String path) {
    final value = _string(path);
    if (value == null) return null;
    try {
      return RegExp(value);
    } on FormatException catch (e) {
      _error(path, 'regex inválida: ${e.message}');
      return null;
    }
  }

  void _checkUnknownKeys(Map<String, Object?> map, String prefix) {
    final known = _knownKeys[prefix];
    if (known == null) return;
    for (final MapEntry(:key, :value) in map.entries) {
      final path = prefix.isEmpty ? key : '$prefix.$key';
      if (!known.contains(key)) {
        _warn(path, 'chave desconhecida (ignorada)');
      } else if (value is Map<String, Object?>) {
        _checkUnknownKeys(value, path);
      }
    }
  }

  void _error(String path, String message) =>
      errors.add(ConfigIssue(path, message));

  void _warn(String path, String message) =>
      warnings.add(ConfigIssue(path, message, isWarning: true));
}
