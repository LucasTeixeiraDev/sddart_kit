import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutter_sdd/src/cli/sdd_command.dart';
import 'package:flutter_sdd/src/cli/sdd_context.dart';
import 'package:flutter_sdd/src/core/import/import_scanner.dart';
import 'package:flutter_sdd/src/infra/exit_codes.dart';
import 'package:path/path.dart' as p;

class ImportCommand extends Command<int> {
  ImportCommand(SddContext context) {
    addSubcommand(_ScanCommand(context));
  }

  @override
  String get name => 'import';

  @override
  String get description =>
      'Importação de skills/rules/agentes existentes (use /sdd-import).';
}

class _ScanCommand extends SddCommand {
  _ScanCommand(super.context);

  @override
  String get name => 'scan';

  @override
  String get description =>
      'Inventário somente leitura de agentes, skills, rules, comandos e '
      'memória (Claude e Cursor), com duplicatas prováveis.';

  @override
  String get invocation => 'sdd import scan <caminho> [--json]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) throw UsageException('informe o caminho', usage);
    final root = p.normalize(p.join(context.workingDirectory, rest.single));
    final ImportScan scan;
    try {
      scan = scanImportSource(context.fs, root);
    } on FileSystemException catch (e) {
      throw CliExit(ExitCodes.usage, '${e.message}: ${e.path}');
    }

    if (jsonOutput) {
      logger.json(scan.toJson());
      return ExitCodes.ok;
    }
    for (final i in scan.items) {
      final dupList = i.duplicates.map((d) => '${d.path} ${d.reason}');
      final dups = dupList.isEmpty ? '' : '  (dup: ${dupList.join('; ')})';
      logger.info(
        '${i.kind.name.padRight(8)} ${i.tool.name.padRight(8)} '
        '${i.name.padRight(24)} ${i.path}$dups',
      );
    }
    final summary = [
      for (final k in ImportKind.values)
        if (scan.items.where((i) => i.kind == k).length case final n when n > 0)
          '$n ${k.name}',
      if (scan.skippedGenerated.isNotEmpty)
        '${scan.skippedGenerated.length} gerados pelo sdd ignorados',
    ];
    logger.info(summary.isEmpty ? 'nada encontrado' : summary.join(' · '));
    return ExitCodes.ok;
  }
}
