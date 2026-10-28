import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/kit/frontmatter.dart';
import 'package:path/path.dart' as p;

/// Tarefa de `specs/<id>/tasks/Txx-*.md`.
class TaskSpec {
  const TaskSpec({
    required this.id,
    required this.title,
    required this.wave,
    required this.tier,
    required this.agent,
    required this.owns,
    required this.file,
    this.dependsOn = const [],
    this.reads = const [],
    this.exemplar,
    this.brick,
    this.acceptance = const [],
    this.body = '',
  });

  final String id;
  final String title;
  final int wave;
  final List<String> dependsOn;
  final Tier tier;

  /// Nome canônico do agente (sem prefixo `sdd-`).
  final String agent;
  final List<String> owns;
  final List<String> reads;
  final String? exemplar;
  final String? brick;
  final List<String> acceptance;
  final String body;

  /// Caminho do arquivo, relativo à raiz do projeto.
  final String file;
}

/// Problema de validação de tarefas.
class TaskIssue {
  const TaskIssue(this.message, {this.task, this.file, this.isWarning = false});

  final String message;
  final String? task;
  final String? file;
  final bool isWarning;

  Map<String, Object?> toJson() => {
    if (task != null) 'task': task,
    if (file != null) 'file': file,
    'message': message,
  };

  @override
  String toString() => [?task, ?file, message].join('  ');
}

final taskIdPattern = RegExp(r'^T\d+$');
final _taskFilePattern = RegExp(r'^(T\d+)(-.+)?\.md$');
final _agentPattern = RegExp(r'^[a-z0-9][a-z0-9-]*$');

const _knownKeys = {
  'id',
  'title',
  'wave',
  'depends_on',
  'tier',
  'agent',
  'owns',
  'reads',
  'exemplar',
  'brick',
  'acceptance',
};

const requiredSections = ['## Objetivo', '## Detalhes', '## Pronto da tarefa'];

/// Faz o parse de uma tarefa; problemas vão para [issues].
/// Retorna `null` se a tarefa for inutilizável.
TaskSpec? parseTask(String source, String file, List<TaskIssue> issues) {
  void error(String msg, {String? task}) =>
      issues.add(TaskIssue(msg, task: task, file: file));
  void warn(String msg, {String? task}) =>
      issues.add(TaskIssue(msg, task: task, file: file, isWarning: true));

  final FrontmatterDoc doc;
  try {
    doc = parseFrontmatter(source);
  } on FormatException catch (e) {
    error(e.message);
    return null;
  }
  final data = doc.data;
  if (data.isEmpty) {
    error('frontmatter ausente');
    return null;
  }

  final id = data['id'];
  if (id is! String || !taskIdPattern.hasMatch(id)) {
    error('id: esperado formato T01, recebido ${id ?? '(ausente)'}');
    return null;
  }
  final fileMatch = _taskFilePattern.firstMatch(p.basename(file));
  if (fileMatch == null || fileMatch.group(1) != id) {
    error('nome do arquivo deve começar com "$id-"', task: id);
  }
  for (final key in data.keys) {
    if (!_knownKeys.contains(key)) warn('$key: chave desconhecida', task: id);
  }

  String? string(String key, {bool required = false}) {
    final v = data[key];
    if (v == null && !required) return null;
    if (v is String && v.trim().isNotEmpty) return v.trim();
    error('$key: esperado string', task: id);
    return null;
  }

  List<String>? list(String key, {bool nonEmpty = false}) {
    final v = data[key] ?? const <Object?>[];
    if (v is! List<Object?> || v.any((e) => e is! String)) {
      error('$key: esperado lista de strings', task: id);
      return null;
    }
    if (nonEmpty && v.isEmpty) {
      error('$key: obrigatório (>= 1 item)', task: id);
      return null;
    }
    return v.cast<String>();
  }

  List<String>? paths(String key, {bool nonEmpty = false}) {
    final values = list(key, nonEmpty: nonEmpty);
    if (values == null) return null;
    final result = <String>[];
    for (final raw in values) {
      final path = _projectPath(raw);
      if (path == null) {
        error(
          '$key: caminho "$raw" deve ser relativo à raiz, sem ".."',
          task: id,
        );
      } else {
        result.add(path);
      }
    }
    return result;
  }

  final title = string('title', required: true);
  final wave = data['wave'];
  if (wave is! int || wave < 0) error('wave: esperado inteiro >= 0', task: id);
  final tierRaw = string('tier', required: true);
  final tier = tierRaw == null ? null : Tier.tryParse(tierRaw);
  if (tierRaw != null && tier == null) {
    error('tier: "$tierRaw" inválido (use deep, standard, fast)', task: id);
  }
  final agent = string('agent', required: true);
  if (agent != null && !_agentPattern.hasMatch(agent)) {
    error('agent: nome canônico inválido (sem prefixo sdd-)', task: id);
  }
  final dependsOn = list('depends_on');
  for (final dep in dependsOn ?? const <String>[]) {
    if (!taskIdPattern.hasMatch(dep)) {
      error('depends_on: "$dep" não é um id de tarefa', task: id);
    }
  }
  final owns = paths('owns', nonEmpty: true);
  final reads = paths('reads');
  final exemplarRaw = string('exemplar');
  final exemplar = exemplarRaw == null ? null : _projectPath(exemplarRaw);
  if (exemplarRaw != null && exemplar == null) {
    error('exemplar: caminho deve ser relativo à raiz, sem ".."', task: id);
  }
  final brick = string('brick');
  final acceptance = list('acceptance');

  for (final section in requiredSections) {
    if (!RegExp(
      '^${RegExp.escape(section)}\\s*\$',
      multiLine: true,
    ).hasMatch(doc.body)) {
      error('corpo sem a seção "$section"', task: id);
    }
  }
  if (!doc.body.contains('sdd check --task')) {
    warn('"Pronto da tarefa" deveria exigir sdd check --task $id', task: id);
  }

  if (title == null ||
      wave is! int ||
      wave < 0 ||
      tier == null ||
      agent == null ||
      owns == null ||
      dependsOn == null ||
      reads == null ||
      acceptance == null) {
    return null;
  }
  return TaskSpec(
    id: id,
    title: title,
    wave: wave,
    tier: tier,
    agent: agent,
    owns: owns,
    reads: reads,
    dependsOn: dependsOn,
    exemplar: exemplar,
    brick: brick,
    acceptance: acceptance,
    body: doc.body,
    file: file,
  );
}

/// Normaliza um caminho do projeto; `null` se absoluto ou com `..`.
String? _projectPath(String raw) {
  final normalized = p.posix.normalize(raw.replaceAll(r'\', '/'));
  if (p.posix.isAbsolute(normalized) ||
      normalized == '..' ||
      normalized.startsWith('../')) {
    return null;
  }
  return normalized;
}
