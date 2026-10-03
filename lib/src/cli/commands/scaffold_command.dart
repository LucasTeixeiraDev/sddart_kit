import 'package:args/command_runner.dart';
import 'package:flutter_sdd/src/cli/sdd_command.dart';
import 'package:flutter_sdd/src/core/project/project_info.dart';
import 'package:flutter_sdd/src/core/scaffold/scaffold.dart';
import 'package:flutter_sdd/src/infra/brick_generator.dart';
import 'package:flutter_sdd/src/infra/exit_codes.dart';

class ScaffoldCommand extends SddCommand {
  ScaffoldCommand(super.context) {
    argParser
      ..addMultiOption(
        'vars',
        help: 'Variáveis do brick (chave=valor; repetível).',
        splitCommas: false,
      )
      ..addOption('task', help: 'Avisa se gerar arquivos fora dos owns.')
      ..addOption('spec', help: 'Spec da --task (se ambígua).');
  }

  @override
  String get name => 'scaffold';

  @override
  String get description =>
      'Aplica um brick mason do stack (nunca sobrescreve arquivos).';

  @override
  String get invocation => 'sdd scaffold <brick> [--vars chave=valor ...]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    final project = await requireProject();
    final bundle = requireBundle(project);
    final available = bundle.bricks.map((b) => b.name).join(', ');
    if (rest.length != 1) {
      throw UsageException('informe um brick ($available)', usage);
    }
    final brick = bundle.brick(rest.single);
    if (brick == null) {
      throw CliExit(
        ExitCodes.usage,
        'brick "${rest.single}" não existe (disponíveis: $available)',
      );
    }

    final Map<String, Object?> vars;
    try {
      final package = ProjectDetector(
        context.fs,
      ).detect(context.workingDirectory).name;
      final config = project.config;
      vars = resolveBrickVars(
        brick,
        packageName: package,
        configVars: {
          'features_path': config.project.featuresPath,
          // Caminho de import (sem `lib/`): package:<pkg>/<features_import>/...
          'features_import': config.project.featuresPath.startsWith('lib/')
              ? config.project.featuresPath.substring(4)
              : config.project.featuresPath,
          'test_path': config.project.testPath,
          ...config.scaffoldVars,
        },
        cliVars: parseVarArgs(argResults!['vars'] as List<String>),
      );
    } on ScaffoldException catch (e) {
      throw CliExit(ExitCodes.usage, e.message);
    } on ProjectDetectionException catch (e) {
      throw CliExit(ExitCodes.usage, e.message);
    }

    final files = await context.brickGenerator.generate(
      brickPath: brick.path,
      targetDir: context.workingDirectory,
      vars: vars,
    );

    await _tidy(files);

    var outside = const <String>[];
    final taskId = argResults!['task'] as String?;
    if (taskId != null) {
      final specArg = argResults!['spec'] as String?;
      final spec = specArg == null
          ? specs.list().map(specs.load).where((s) => s.task(taskId) != null)
          : [specs.load(specs.resolve(specArg))];
      final task = spec.map((s) => s.task(taskId)).nonNulls.firstOrNull;
      if (task == null) {
        throw CliExit(ExitCodes.usage, 'tarefa $taskId não encontrada');
      }
      outside = outsideOwns(
        files
            .where((f) => f.status != BrickFileStatus.skipped)
            .map((f) => f.path),
        task,
      );
    }

    if (jsonOutput) {
      logger.json({
        'brick': brick.name,
        'vars': vars,
        'files': [
          for (final f in files) {'path': f.path, 'status': f.status.name},
        ],
        'outside_owns': outside,
      });
    } else {
      for (final f in files) {
        logger.info('${f.status.name.padRight(10)} ${f.path}');
      }
      for (final f in outside) {
        logger.warn('$f fora dos owns de $taskId');
      }
      final created = files
          .where((f) => f.status == BrickFileStatus.created)
          .length;
      // Conflitos (skipped) e conteúdo igual (identical) ficam como estão.
      final skipped = files
          .where(
            (f) =>
                f.status == BrickFileStatus.skipped ||
                f.status == BrickFileStatus.identical,
          )
          .length;
      logger.info('${brick.name}: $created criados · $skipped mantidos');
    }
    return ExitCodes.ok;
  }

  /// Ordena imports e formata só os `.dart` criados agora: a ordem e a quebra
  /// de linha dependem do nome do pacote e dos nomes gerados (D-031).
  Future<void> _tidy(List<BrickFile> files) async {
    final created = [
      for (final f in files)
        if (f.status == BrickFileStatus.created && f.path.endsWith('.dart'))
          f.path,
    ];
    if (created.isEmpty) return;
    for (final file in created) {
      final fix = await context.processRunner.run('dart', [
        'fix',
        '--apply',
        '--code=directives_ordering',
        file,
      ], workingDirectory: context.workingDirectory);
      if (!fix.ok) logger.detail('dart fix falhou em $file: ${fix.stderr}');
    }
    final format = await context.processRunner.run('dart', [
      'format',
      ...created,
    ], workingDirectory: context.workingDirectory);
    if (!format.ok) logger.warn('dart format falhou: ${format.stderr.trim()}');
  }
}
