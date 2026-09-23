import 'package:args/command_runner.dart';
import 'package:flutter_sdd/src/cli/sdd_context.dart';
import 'package:flutter_sdd/src/infra/logger.dart';

/// Base dos comandos: acesso ao contexto e às flags globais.
abstract class SddCommand extends Command<int> {
  SddCommand(this.context);

  final SddContext context;

  bool get jsonOutput => globalResults?['json'] == true;

  String? get kitPath => globalResults?['kit-path'] as String?;

  late final Logger logger = Logger(
    out: context.out,
    err: context.err,
    verbose: globalResults?['verbose'] == true,
    jsonMode: jsonOutput,
  );
}
