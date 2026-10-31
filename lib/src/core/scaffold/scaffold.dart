import 'package:file/file.dart';
import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:flutter_sdd/src/core/scaffold/brick_paths.dart';
import 'package:flutter_sdd/src/core/tasks/task.dart';
import 'package:flutter_sdd/src/core/tasks/task_validator.dart';

class ScaffoldException implements Exception {
  const ScaffoldException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// `--vars k=v` (repetível ou separado por vírgula).
Map<String, String> parseVarArgs(Iterable<String> args) {
  final vars = <String, String>{};
  for (final arg in args) {
    final i = arg.indexOf('=');
    if (i <= 0) {
      throw ScaffoldException('--vars "$arg" inválido (use chave=valor)');
    }
    vars[arg.substring(0, i).trim()] = arg.substring(i + 1).trim();
  }
  return vars;
}

/// Variáveis finais do brick, em ordem crescente de precedência: `package`
/// (do pubspec) → defaults do `brick.yaml` → `scaffold.vars` do config →
/// `--vars`. Valores podem referenciar outras variáveis como `{nome}`
/// (ex.: default `"{feature}"`). Lança [ScaffoldException] se faltar alguma
/// obrigatória ou o tipo não converter.
Map<String, Object?> resolveBrickVars(
  KitBrick brick, {
  required String packageName,
  Map<String, String> configVars = const {},
  Map<String, String> cliVars = const {},
}) {
  final merged = <String, Object?>{
    'package': packageName,
    for (final v in brick.vars)
      if (v.defaultValue != null) v.name: v.defaultValue,
    ...configVars,
    ...cliVars,
  };
  // Referências `{var}` em valores string (até 3 níveis de indireção).
  for (var pass = 0; pass < 3; pass++) {
    for (final MapEntry(:key, :value) in merged.entries.toList()) {
      if (value is! String) continue;
      merged[key] = value.replaceAllMapped(RegExp(r'\{([a-z_]+)\}'), (m) {
        final ref = merged[m.group(1)];
        return ref is String && m.group(1) != key ? ref : m.group(0)!;
      });
    }
  }

  final missing = [
    for (final v in brick.vars)
      if (!merged.containsKey(v.name)) v,
  ];
  if (missing.isNotEmpty) {
    String describe(BrickVar v) =>
        v.description == null ? v.name : '${v.name} (${v.description})';
    final hint = missing.map((v) => '--vars ${v.name}=...').join(' ');
    throw ScaffoldException(
      'brick ${brick.name}: faltam variáveis '
      '${missing.map(describe).join(', ')}\nuse $hint',
    );
  }

  for (final v in brick.vars) {
    final value = merged[v.name];
    if (value is! String) continue;
    merged[v.name] = switch (v.type) {
      'boolean' => switch (value) {
        'true' => true,
        'false' => false,
        _ => throw ScaffoldException('${v.name}: esperado true/false'),
      },
      'number' =>
        num.tryParse(value) ??
            (throw ScaffoldException('${v.name}: esperado número')),
      _ => value,
    };
  }
  return merged;
}

/// Arquivos gerados fora dos `owns` da tarefa (para alertar o implementer).
List<String> outsideOwns(Iterable<String> generated, TaskSpec task) => [
  for (final path in generated)
    if (!task.owns.contains(path)) path,
];

/// Variáveis automáticas de todo brick, derivadas do config. `package` vem do
/// pubspec (em [resolveBrickVars]).
Map<String, String> scaffoldAutoVars(SddConfig config) => {
  'features_path': config.project.featuresPath,
  // Caminho de import (sem `lib/`): package:<pkg>/<features_import>/...
  'features_import': config.project.featuresPath.startsWith('lib/')
      ? config.project.featuresPath.substring(4)
      : config.project.featuresPath,
  'test_path': config.project.testPath,
  ...config.scaffoldVars,
};

/// Arquivos que o brick da tarefa geraria (para o `tasks validate`).
BrickPlan planTaskBrick({
  required FileSystem fs,
  required KitBundle bundle,
  required SddConfig config,
  required String packageName,
  required TaskSpec task,
}) {
  final brick = bundle.brick(task.brick!);
  if (brick == null) {
    return BrickPlan.error(
      'não existe no kit (disponíveis: '
      '${bundle.bricks.map((b) => b.name).join(', ')})',
    );
  }
  try {
    final vars = resolveBrickVars(
      brick,
      packageName: packageName,
      configVars: scaffoldAutoVars(config),
      cliVars: task.brickVars,
    );
    return BrickPlan.paths(brickOutputPaths(fs, brick, vars));
  } on ScaffoldException catch (e) {
    // O validate já prefixa "brick <nome>:"; evita repetir.
    return BrickPlan.error(
      e.message.split('\n').first.replaceFirst('brick ${brick.name}: ', ''),
    );
  } on FormatException catch (e) {
    return BrickPlan.error(e.message);
  }
}
