import 'package:args/command_runner.dart';
import 'package:flutter_sdd/src/cli/sdd_command.dart';
import 'package:flutter_sdd/src/core/kit/template_renderer.dart';
import 'package:flutter_sdd/src/infra/exit_codes.dart';
import 'package:flutter_sdd/src/version.dart';

class NewCommand extends SddCommand {
  NewCommand(super.context);

  @override
  String get name => 'new';

  @override
  String get description =>
      'Cria specs/NNNN-slug/ com prd.md (template) e status.yaml inicial.';

  @override
  String get invocation => 'sdd new "<título>"';

  @override
  Future<int> run() async {
    final title = argResults!.rest.join(' ').trim();
    if (title.isEmpty) throw UsageException('informe o título', usage);
    final project = await requireProject();
    final bundle = requireBundle(project);

    final String id;
    try {
      id = specs.nextId(title);
    } on FormatException catch (e) {
      throw CliExit(ExitCodes.usage, e.message);
    }
    final template = bundle.templates['prd.md'];
    if (template == null) {
      throw const CliExit(ExitCodes.usage, 'template prd.md ausente no kit');
    }
    final missing = <String>[];
    final prd = renderTemplate(template, {
      ...buildRenderVars(project.config, bundle, sddVersion: sddVersion),
      'title': title,
      'spec': id,
    }, missing: missing);
    if (missing.isNotEmpty) {
      throw CliExit(
        ExitCodes.usage,
        'templates/prd.md: variáveis desconhecidas ${missing.join(', ')}',
      );
    }
    final path = specs.create(id, prd: prd);

    if (jsonOutput) {
      logger.json({'spec': id, 'path': path});
    } else {
      logger
        ..info('criado $path/ (prd.md, status.yaml)')
        ..info('próximo passo: preencha prd.md e rode /sdd-analyze $id');
    }
    return ExitCodes.ok;
  }
}
