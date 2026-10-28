import 'package:args/command_runner.dart';
import 'package:flutter_sdd/src/cli/sdd_command.dart';
import 'package:flutter_sdd/src/core/specs/spec_repository.dart';
import 'package:flutter_sdd/src/core/status/spec_status.dart';
import 'package:flutter_sdd/src/core/status/status_store.dart';
import 'package:flutter_sdd/src/core/status/status_summary.dart';
import 'package:flutter_sdd/src/core/status/status_transitions.dart';
import 'package:flutter_sdd/src/infra/exit_codes.dart';

/// `sdd status [<spec>]` e `sdd status set <spec> <alvo> <valor>`.
///
/// `set` é tratado aqui (e não como subcomando) para que `sdd status <spec>`
/// continue funcionando.
class StatusCommand extends SddCommand {
  StatusCommand(super.context);

  @override
  String get name => 'status';

  @override
  String get description =>
      'Resumo do progresso; "set" é a única forma de mudar status.yaml.';

  @override
  String get invocation =>
      'sdd status [<spec>]\n       sdd status set <spec> <alvo> <valor>';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isNotEmpty && rest.first == 'set') {
      return await _set(rest.skip(1).toList());
    }
    if (rest.length > 1) throw UsageException('argumentos demais', usage);
    final project = await requireProject();

    final learnings = context.fs.file(project.paths.learnings);
    final pending = learnings.existsSync()
        ? countLearnings(learnings.readAsStringSync())
        : 0;
    final limit = project.config.learningsWarnAfter;
    final learningsWarning = pending > limit
        ? 'learnings.md com $pending lições (limite $limit); promova-as no '
              '/sdd-close'
        : null;

    final List<SpecDir> shown;
    try {
      shown = rest.isEmpty
          ? specs
                .list()
                .map(specs.load)
                .where((s) => s.status.phase != Phase.done)
                .toList()
          : [specs.load(specs.resolve(rest.single))];
    } on SpecNotFoundException catch (e) {
      throw CliExit(ExitCodes.usage, e.message);
    } on FormatException catch (e) {
      throw CliExit(ExitCodes.usage, e.message);
    }

    if (jsonOutput) {
      logger.json({
        'specs': [for (final s in shown) specJson(s)],
        'learnings': {'pending': pending, 'limit': limit},
      });
      return ExitCodes.ok;
    }
    if (learningsWarning != null) logger.warn(learningsWarning);
    if (rest.isNotEmpty) {
      logger.info(specDetail(shown.single));
    } else if (shown.isEmpty) {
      logger.info('nenhuma spec aberta; crie com sdd new "<título>"');
    } else {
      shown.map(summaryLine).forEach(logger.info);
    }
    return ExitCodes.ok;
  }

  Future<int> _set(List<String> args) async {
    if (args.isEmpty) throw UsageException(statusSetUsage, usage);
    final project = await requireProject();
    final String id;
    try {
      id = specs.resolve(args.first);
    } on SpecNotFoundException catch (e) {
      throw CliExit(ExitCodes.usage, e.message);
    }
    try {
      final result = await StatusStore(
        fs: context.fs,
        root: context.workingDirectory,
        locker: context.locker,
      ).set(id, args.skip(1).toList(), project.config);
      if (jsonOutput) {
        logger.json({'spec': id, ...result.change});
      } else {
        logger.info(result.message);
      }
      return ExitCodes.ok;
    } on StatusSetException catch (e) {
      throw CliExit(e.usage ? ExitCodes.usage : ExitCodes.failure, e.message);
    } on FormatException catch (e) {
      throw CliExit(ExitCodes.usage, e.message);
    }
  }
}
