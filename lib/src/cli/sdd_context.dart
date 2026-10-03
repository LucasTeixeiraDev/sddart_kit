import 'dart:convert';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter_sdd/src/core/kit/kit_locator.dart';
import 'package:flutter_sdd/src/infra/brick_generator.dart';
import 'package:flutter_sdd/src/infra/file_locker.dart';
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
    this.readStdin = _noStdin,
    FileLocker? locker,
    this.brickGenerator = const MasonBrickGenerator(),
  }) : locker = locker ?? InProcessFileLocker();

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
    readStdin: () => io.stdin.transform(utf8.decoder).join(),
    locker: const IoFileLocker(),
  );

  static Future<String> _noStdin() async => '';

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

  /// Lê todo o stdin (payload JSON dos hooks).
  final Future<String> Function() readStdin;

  /// Lock entre processos para escritas de estado (`status.yaml`).
  final FileLocker locker;

  /// Geração de bricks (mason usa dart:io; testes injetam um fake).
  final BrickGenerator brickGenerator;

  KitLocator get kitLocator =>
      KitLocator(fs: fs, environment: environment, packageRoot: packageRoot);
}
