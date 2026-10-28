import 'package:args/command_runner.dart';
import 'package:flutter_sdd/src/cli/sdd_command.dart';
import 'package:flutter_sdd/src/core/gates/gate_runner.dart';
import 'package:flutter_sdd/src/core/gates/report_format.dart';
import 'package:flutter_sdd/src/core/specs/spec_repository.dart';
import 'package:flutter_sdd/src/core/status/spec_status.dart';
import 'package:flutter_sdd/src/infra/exit_codes.dart';

class CheckCommand extends SddCommand {
  CheckCommand(super.context) {
    argParser
      ..addOption('spec', help: 'Spec (id, NNNN ou número).')
      ..addOption('task', help: 'Tarefa: gates escopados aos arquivos de owns.')
      ..addOption(
        'max-lines',
        defaultsTo: '20',
        help: 'Máximo de falhas exibidas por gate.',
      );
  }

  @override
  String get name => 'check';

  @override
  String get description =>
      'Roda os gates (format, analyze, test, owns, cobertura, '
      'rastreabilidade) e mostra só as falhas.';

  @override
  Future<int> run() async {
    final maxLines = int.tryParse(argResults!['max-lines'] as String);
    if (maxLines == null || maxLines < 1) {
      throw UsageException('--max-lines deve ser inteiro >= 1', usage);
    }
    final project = await requireProject();
    final runner = GateRunner(
      fs: context.fs,
      processRunner: context.processRunner,
      root: context.workingDirectory,
      config: project.config,
    );
    final taskId = argResults!['task'] as String?;
    final specArg = argResults!['spec'] as String?;

    final report = taskId == null
        ? await runner.runSpec(_specFor(specArg))
        : await () {
            final spec = _specForTask(taskId, specArg);
            final task = spec.task(taskId)!;
            return runner.runTask(spec, task);
          }();

    if (jsonOutput) {
      logger.json(reportJson(report, maxLines: maxLines));
    } else {
      context.out.write(formatReport(report, maxLines: maxLines));
    }
    return report.ok ? ExitCodes.ok : ExitCodes.failure;
  }

  SpecDir _load(String id) {
    try {
      return specs.load(id);
    } on FormatException catch (e) {
      throw CliExit(ExitCodes.usage, e.message);
    }
  }

  String _resolve(String arg) {
    try {
      return specs.resolve(arg);
    } on SpecNotFoundException catch (e) {
      throw CliExit(ExitCodes.usage, e.message);
    }
  }

  /// `--spec`, ou a única spec em exec/review; senão `null`.
  SpecDir? _specFor(String? arg) {
    if (arg != null) return _load(_resolve(arg));
    final active = [
      for (final id in specs.list())
        if (const {Phase.exec, Phase.review}.contains(_load(id).status.phase))
          id,
    ];
    if (active.length == 1) return _load(active.single);
    logger.detail('nenhuma spec ativa única; rastreabilidade será pulada');
    return null;
  }

  /// Spec que contém [taskId]: `--spec`, ou a única spec aberta com a tarefa.
  SpecDir _specForTask(String taskId, String? arg) {
    final candidates = arg != null
        ? [_load(_resolve(arg))]
        : [
            for (final id in specs.list())
              if (_load(id) case final s
                  when s.status.phase != Phase.done && s.task(taskId) != null)
                s,
          ];
    if (arg != null && candidates.single.task(taskId) == null) {
      throw CliExit(
        ExitCodes.usage,
        'tarefa $taskId não existe em ${candidates.single.id}',
      );
    }
    if (candidates.isEmpty) {
      throw CliExit(ExitCodes.usage, 'tarefa $taskId não encontrada');
    }
    if (candidates.length > 1) {
      throw CliExit(
        ExitCodes.usage,
        '$taskId existe em várias specs '
        '(${candidates.map((s) => s.id).join(', ')}); use --spec',
      );
    }
    return candidates.single;
  }
}
