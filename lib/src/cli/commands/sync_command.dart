import 'package:flutter_sdd/src/cli/sdd_command.dart';
import 'package:flutter_sdd/src/cli/sync_runner.dart';

class SyncCommand extends SddCommand {
  SyncCommand(super.context) {
    argParser.addFlag(
      'check',
      negatable: false,
      help: 'Não escreve; falha se algo estiver desatualizado (CI).',
    );
  }

  @override
  String get name => 'sync';

  @override
  String get description =>
      'Gera .claude/, .cursor/, AGENTS.md e CLAUDE.md a partir do kit.';

  @override
  Future<int> run() => runSync(
    context,
    logger,
    check: argResults!['check'] == true,
    json: jsonOutput,
    kitPath: kitPath,
  );
}
