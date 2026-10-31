import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutter_sdd/src/cli/sdd_command.dart';
import 'package:flutter_sdd/src/cli/sdd_context.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:flutter_sdd/src/core/project/project_info.dart';
import 'package:flutter_sdd/src/core/project/project_loader.dart';
import 'package:flutter_sdd/src/core/scaffold/scaffold.dart';
import 'package:flutter_sdd/src/core/specs/spec_repository.dart';
import 'package:flutter_sdd/src/core/tasks/scheduler.dart';
import 'package:flutter_sdd/src/core/tasks/task_graph.dart';
import 'package:flutter_sdd/src/core/tasks/task_validator.dart';
import 'package:flutter_sdd/src/infra/exit_codes.dart';
import 'package:path/path.dart' as p;

class TasksCommand extends Command<int> {
  TasksCommand(SddContext context) {
    addSubcommand(_ValidateCommand(context));
    addSubcommand(_GraphCommand(context));
    addSubcommand(_NextCommand(context));
  }

  @override
  String get name => 'tasks';

  @override
  String get description => 'Valida, mostra e agenda as tarefas de uma spec.';
}

/// Carrega projeto + spec e valida o grafo (base comum dos subcomandos).
mixin _TaskContext on SddCommand {
  late final LoadedProject project;
  late final KitBundle bundle;
  late final SpecDir spec;

  Future<ValidationResult> loadAndValidate() async {
    project = await requireProject();
    bundle = requireBundle(project);
    spec = requireSpec();
    String? package;
    try {
      package = ProjectDetector(
        context.fs,
      ).detect(context.workingDirectory).name;
    } on ProjectDetectionException {
      package = null;
    }
    return validateTasks(
      spec,
      config: project.config,
      bundle: bundle,
      brickPlanner: (task) => package == null
          ? const BrickPlan.error('pubspec.yaml ausente')
          : planTaskBrick(
              fs: context.fs,
              bundle: bundle,
              config: project.config,
              packageName: package,
              task: task,
            ),
      exists: (rel) =>
          context.fs.typeSync(p.join(context.workingDirectory, rel)) !=
          FileSystemEntityType.notFound,
    );
  }
}

class _ValidateCommand extends SddCommand with _TaskContext {
  _ValidateCommand(super.context);

  @override
  String get name => 'validate';

  @override
  String get description =>
      'Valida schema, DAG, ondas, owns, reads, exemplar e ACs das tarefas.';

  @override
  String get invocation => 'sdd tasks validate <spec>';

  @override
  Future<int> run() async {
    final result = await loadAndValidate();
    final waves = spec.tasks.map((t) => t.wave).toSet().length;
    if (jsonOutput) {
      logger.json({
        'ok': result.ok,
        'spec': spec.id,
        'tasks': spec.tasks.length,
        'waves': waves,
        'errors': [for (final i in result.errors) i.toJson()],
        'warnings': [for (final i in result.warnings) i.toJson()],
      });
    } else {
      for (final i in result.errors) {
        logger.info('FAIL $i');
      }
      for (final i in result.warnings) {
        logger.info('WARN $i');
      }
      final warnings = result.warnings.length;
      logger.info(
        result.ok
            ? [
                'ok · ${spec.tasks.length} tarefas · $waves ondas',
                if (warnings > 0) '$warnings avisos',
              ].join(' · ')
            : '${result.errors.length} erros · $warnings avisos',
      );
    }
    return result.ok ? ExitCodes.ok : ExitCodes.failure;
  }
}

class _GraphCommand extends SddCommand with _TaskContext {
  _GraphCommand(super.context) {
    argParser.addFlag('mermaid', negatable: false, help: 'Saída em Mermaid.');
  }

  @override
  String get name => 'graph';

  @override
  String get description => 'Mostra ondas e dependências das tarefas.';

  @override
  String get invocation => 'sdd tasks graph <spec> [--mermaid]';

  @override
  Future<int> run() async {
    final result = await loadAndValidate();
    if (!result.ok) {
      logger.warn('tarefas com erros; rode sdd tasks validate ${spec.id}');
    }
    if (jsonOutput) {
      logger.json({
        'spec': spec.id,
        'tasks': [
          for (final t in spec.tasks)
            {
              'id': t.id,
              'title': t.title,
              'wave': t.wave,
              'depends_on': t.dependsOn,
              'state': spec.status.task(t.id).state.id,
            },
        ],
      });
    } else {
      context.out.write(
        argResults!['mermaid'] == true
            ? renderGraphMermaid(spec)
            : renderGraphText(spec),
      );
    }
    return ExitCodes.ok;
  }
}

class _NextCommand extends SddCommand with _TaskContext {
  _NextCommand(super.context);

  @override
  String get name => 'next';

  @override
  String get description =>
      'Lista as tarefas prontas da menor onda, com agente e tier resolvidos.';

  @override
  String get invocation => 'sdd tasks next <spec> [--json]';

  @override
  Future<int> run() async {
    final validation = await loadAndValidate();
    if (!validation.ok) {
      throw CliExit(
        ExitCodes.failure,
        'tarefas inválidas; rode sdd tasks validate ${spec.id}',
      );
    }
    final next = computeNext(spec, project.config, bundle: bundle);
    if (jsonOutput) {
      logger.json(next.toJson(spec.id));
      return ExitCodes.ok;
    }
    if (next.complete) {
      logger.info(
        'todas as tarefas concluídas; rode sdd check --spec ${spec.id}',
      );
      return ExitCodes.ok;
    }
    logger.info('onda ${next.wave} · ${next.ready.length} prontas');
    for (final r in next.ready) {
      final extra = [
        if (r.plan.attempt > 1) 'tentativa ${r.plan.attempt}',
        if (r.plan.escalated) 'escalada',
      ];
      logger.info(
        '  ${r.task.id}  ${r.agent}  ${r.task.file}'
        '${extra.isEmpty ? '' : '  (${extra.join(', ')})'}',
      );
    }
    if (next.inProgress.isNotEmpty) {
      logger.info('em andamento: ${next.inProgress.join(', ')}');
    }
    if (next.blocked.isNotEmpty) {
      logger.info(
        'bloqueadas: ${next.blocked.join(', ')} (precisam de humano)',
      );
    }
    return ExitCodes.ok;
  }
}
