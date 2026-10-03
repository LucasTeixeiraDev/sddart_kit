import 'package:collection/collection.dart';
import 'package:flutter_sdd/src/cli/sdd_command.dart';
import 'package:flutter_sdd/src/cli/sync_runner.dart';
import 'package:flutter_sdd/src/core/config/config_issue.dart';
import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/kit/kit_locator.dart';
import 'package:flutter_sdd/src/core/kit/stack_definition.dart';
import 'package:flutter_sdd/src/core/project/initializer.dart';
import 'package:flutter_sdd/src/core/project/project_info.dart';
import 'package:flutter_sdd/src/core/project/sdd_paths.dart';
import 'package:flutter_sdd/src/infra/exit_codes.dart';
import 'package:flutter_sdd/src/infra/logger.dart';
import 'package:flutter_sdd/src/version.dart';
import 'package:path/path.dart' as p;

class InitCommand extends SddCommand {
  InitCommand(super.context) {
    argParser
      ..addOption('stack', help: 'Stack pack (senão, detectado).')
      ..addFlag(
        'yes',
        abbr: 'y',
        negatable: false,
        help: 'Aceita os defaults detectados sem perguntar.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help: 'Regrava config.yaml e kit.lock (memória é preservada).',
      );
  }

  @override
  String get name => 'init';

  @override
  String get description =>
      'Detecta o projeto e cria .sdd/ (config, kit.lock, memory, overrides).';

  @override
  Future<int> run() async {
    final root = context.workingDirectory;
    final fs = context.fs;
    final paths = SddPaths(root);
    final ask =
        context.interactive && argResults!['yes'] != true && !jsonOutput;

    if (fs.file(paths.config).existsSync() && argResults!['force'] != true) {
      logger.error('.sdd/config.yaml já existe (use sdd sync, ou --force)');
      return ExitCodes.usage;
    }

    final ProjectInfo project;
    final KitLocation kit;
    try {
      project = ProjectDetector(fs).detect(root);
      kit = await context.kitLocator.locate(kitPath: kitPath);
    } on ProjectDetectionException catch (e) {
      logger.error(e.message);
      return ExitCodes.usage;
    } on KitNotFoundException catch (e) {
      logger.error(e.message);
      return ExitCodes.usage;
    }

    final stacks = [
      for (final name in context.kitLocator.stacks(kit))
        StackDefinition.parse(fs.file(kit.stackFile(name)).readAsStringSync()),
    ];
    final stack = _chooseStack(stacks, project, ask: ask);
    if (stack == null) return ExitCodes.usage;

    var targets = Target.values;
    if (ask) {
      final chosen = context.prompter.chooseAny(
        'Gerar arquivos para quais ferramentas?',
        choices: [for (final t in Target.values) t.name],
        defaultValues: [for (final t in Target.values) t.name],
      );
      if (chosen.isEmpty) {
        logger.error('escolha ao menos uma ferramenta');
        return ExitCodes.usage;
      }
      targets = [for (final c in chosen) Target.tryParse(c)!];
    }
    final formatOnEdit =
        ask &&
        context.prompter.confirm(
          'Rodar dart format automaticamente após cada edição do agente?',
          defaultValue: false,
        );

    final proposal = proposeConfig(
      stack: stack,
      project: project,
      targets: targets,
      exists: (rel) => fs.directory(p.join(root, rel)).existsSync(),
      formatOnEdit: formatOnEdit,
    );
    final InitResult result;
    try {
      result = writeSddDir(
        fs: fs,
        root: root,
        kit: kit,
        stack: stack,
        config: proposal.config,
        cliVersion: sddVersion,
      );
    } on ConfigException catch (e) {
      // Indica defaults inconsistentes no kit, não erro do usuário.
      logger.error('config gerado inválido (bug do kit):\n$e');
      return ExitCodes.usage;
    }

    Future<int> sync(Logger syncLogger) => runSync(
      context,
      syncLogger,
      check: false,
      json: false,
      kitPath: kitPath,
    );

    if (jsonOutput) {
      // O documento do init é a saída; o sync fica silencioso.
      final syncCode = await sync(
        Logger(out: StringBuffer(), err: context.err),
      );
      logger.json({
        'sync_ok': syncCode == ExitCodes.ok,
        'stack': stack.name,
        'targets': [for (final t in targets) t.name],
        'created': result.created,
        'skipped': result.skipped,
        'notes': proposal.notes,
      });
      return syncCode;
    }
    proposal.notes.forEach(logger.warn);
    final targetNames = targets.map((t) => t.name).join(', ');
    logger.info('stack ${stack.name} · targets $targetNames');
    for (final f in result.created) {
      logger.info('criado    $f');
    }
    for (final f in result.skipped) {
      logger.info('mantido   $f');
    }
    final syncCode = await sync(logger);
    if (syncCode == ExitCodes.ok) {
      logger.info('próximo passo: sdd new "<título>"');
    }
    return syncCode;
  }

  StackDefinition? _chooseStack(
    List<StackDefinition> stacks,
    ProjectInfo project, {
    required bool ask,
  }) {
    if (stacks.isEmpty) {
      logger.error('o kit não tem nenhum stack pack');
      return null;
    }
    final requested = argResults!['stack'] as String?;
    if (requested != null) {
      final match = stacks.firstWhereOrNull((s) => s.name == requested);
      if (match == null) {
        logger.error(
          'stack "$requested" não existe (disponíveis: '
          '${stacks.map((s) => s.name).join(', ')})',
        );
      }
      return match;
    }

    final ranked = stacks.map((s) => s.score(project)).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    for (final r in ranked) {
      logger.detail(
        'stack ${r.stack.name}: ${r.score} pts '
        '(${r.matched.map((m) => m.label).join(', ')})',
      );
    }
    final best = ranked.firstWhereOrNull((r) => r.qualifies)?.stack;
    if (!ask) {
      if (best == null) {
        logger.error('nenhum stack detectado; use --stack <nome>');
      }
      return best;
    }
    final name = context.prompter.chooseOne(
      'Stack pack:',
      choices: [for (final s in stacks) s.name],
      defaultValue: (best ?? stacks.first).name,
    );
    return stacks.firstWhere((s) => s.name == name);
  }
}
