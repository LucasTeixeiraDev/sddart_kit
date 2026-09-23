import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter_sdd/src/core/kit/kit_locator.dart';
import 'package:flutter_sdd/src/infra/package_root.dart';
import 'package:flutter_sdd/src/infra/process_runner.dart';
import 'package:flutter_sdd/src/infra/prompter.dart';

/// Dependências injetáveis do CLI (reais em produção, falsas nos testes).
class SddContext {
  SddContext({
    required this.fs,
    required this.processRunner,
    required this.prompter,
    required this.environment,
    required this.workingDirectory,
    required this.packageRoot,
    required this.out,
    required this.err,
    required this.interactive,
  });

  /// Contexto real do processo.
  factory SddContext.io() => SddContext(
    fs: const LocalFileSystem(),
    processRunner: const IoProcessRunner(),
    prompter: TerminalPrompter(),
    environment: io.Platform.environment,
    workingDirectory: io.Directory.current.path,
    packageRoot: resolveFlutterSddPackageRoot,
    out: io.stdout,
    err: io.stderr,
    interactive: io.stdin.hasTerminal,
  );

  final FileSystem fs;
  final ProcessRunner processRunner;
  final Prompter prompter;
  final Map<String, String> environment;
  final String workingDirectory;
  final Future<Uri?> Function() packageRoot;
  final StringSink out;
  final StringSink err;

  /// Se é possível fazer perguntas ao usuário (stdin é um terminal).
  final bool interactive;

  KitLocator get kitLocator =>
      KitLocator(fs: fs, environment: environment, packageRoot: packageRoot);
}
