import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:flutter_sdd/src/cli/commands/doctor_command.dart';
import 'package:flutter_sdd/src/cli/commands/init_command.dart';
import 'package:flutter_sdd/src/cli/sdd_context.dart';
import 'package:flutter_sdd/src/infra/exit_codes.dart';
import 'package:flutter_sdd/src/version.dart';

/// Ponto de entrada do CLI `sdd`.
class SddCommandRunner extends CommandRunner<int> {
  SddCommandRunner(this.context)
    : super('sdd', 'Spec-Driven Development para apps Flutter.') {
    argParser
      ..addFlag('json', negatable: false, help: 'Saída JSON para agentes.')
      ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Logs de debug.')
      ..addFlag('version', negatable: false, help: 'Mostra a versão.')
      ..addOption(
        'kit-path',
        valueHelp: 'dir',
        help: 'Diretório do kit (senão SDD_KIT_PATH ou o pacote).',
      );
    addCommand(InitCommand(context));
    addCommand(DoctorCommand(context));
  }

  final SddContext context;

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      return await super.run(args) ?? ExitCodes.ok;
    } on UsageException catch (e) {
      context.err
        ..writeln(e.message)
        ..writeln()
        ..writeln(e.usage);
      return ExitCodes.usage;
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults['version'] == true) {
      context.out.writeln(sddVersion);
      return ExitCodes.ok;
    }
    return await super.runCommand(topLevelResults);
  }
}
