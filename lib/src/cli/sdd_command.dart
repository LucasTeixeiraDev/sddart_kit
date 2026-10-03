import 'package:args/command_runner.dart';
import 'package:flutter_sdd/src/cli/sdd_context.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:flutter_sdd/src/core/project/project_loader.dart';
import 'package:flutter_sdd/src/core/specs/spec_repository.dart';
import 'package:flutter_sdd/src/infra/exit_codes.dart';
import 'package:flutter_sdd/src/infra/logger.dart';

/// Encerra o comando com [code]; [message] vai para stderr como erro.
class CliExit implements Exception {
  const CliExit(this.code, [this.message]);

  final int code;
  final String? message;
}

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

  SpecRepository get specs =>
      SpecRepository(context.fs, context.workingDirectory);

  /// Projeto carregado; falhas viram exit 2.
  Future<LoadedProject> requireProject() async {
    try {
      final project = await loadProject(
        fs: context.fs,
        root: context.workingDirectory,
        locator: context.kitLocator,
        kitPath: kitPath,
      );
      for (final w in project.configWarnings) {
        logger.detail('WARN $w');
      }
      return project;
    } on ProjectLoadException catch (e) {
      throw CliExit(ExitCodes.usage, e.message);
    }
  }

  /// Kit resolvido; falhas viram exit 2.
  KitBundle requireBundle(LoadedProject project) {
    try {
      return project.loadBundle(context.fs);
    } on KitException catch (e) {
      throw CliExit(ExitCodes.usage, 'kit/overrides inválidos:\n$e');
    }
  }

  /// Spec do argumento posicional [index]; falhas viram exit 2.
  SpecDir requireSpec([int index = 0]) {
    final rest = argResults!.rest;
    if (rest.length <= index) throw UsageException('informe a spec', usage);
    try {
      return specs.load(specs.resolve(rest[index]));
    } on SpecNotFoundException catch (e) {
      throw CliExit(ExitCodes.usage, e.message);
    } on FormatException catch (e) {
      throw CliExit(ExitCodes.usage, e.message);
    }
  }
}
