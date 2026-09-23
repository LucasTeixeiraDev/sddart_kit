import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_sdd/flutter_sdd.dart';
import 'package:flutter_sdd/src/infra/prompter.dart';
import 'package:path/path.dart' as p;

import 'fake_process_runner.dart';

/// Raiz do repositório (testes rodam com cwd na raiz do pacote).
final String repoRoot = io.Directory.current.path;

/// Caminho do kit dentro do [MemoryFileSystem] dos testes.
const memKitPath = '/sdd/kit';

/// Diretório do projeto de teste dentro do [MemoryFileSystem].
const memProjectPath = '/work/app';

/// Copia um diretório do disco real para o [fs] em memória.
void copyIntoMemory(String from, FileSystem fs, String to) {
  for (final entity in io.Directory(from).listSync(recursive: true)) {
    if (entity is! io.File) continue;
    final target = fs.file(p.join(to, p.relative(entity.path, from: from)));
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(entity.readAsBytesSync());
  }
}

/// FileSystem em memória com o kit (real ou uma fixture de kit) e,
/// opcionalmente, uma fixture de projeto.
MemoryFileSystem memoryFs({String? fixture, String? kitFixture}) {
  final fs = MemoryFileSystem();
  copyIntoMemory(
    kitFixture == null
        ? p.join(repoRoot, 'kit')
        : p.join(repoRoot, 'test', 'fixtures', kitFixture),
    fs,
    memKitPath,
  );
  fs.directory(memProjectPath).createSync(recursive: true);
  if (fixture != null) {
    copyIntoMemory(
      p.join(repoRoot, 'test', 'fixtures', fixture),
      fs,
      memProjectPath,
    );
  }
  fs.currentDirectory = memProjectPath;
  return fs;
}

/// Prompter roteirizado: devolve respostas fixas e registra as perguntas.
class ScriptedPrompter implements Prompter {
  ScriptedPrompter({this.stack, this.targets});

  final String? stack;
  final List<String>? targets;
  final asked = <String>[];

  @override
  bool confirm(String message, {bool defaultValue = true}) {
    asked.add(message);
    return defaultValue;
  }

  @override
  String chooseOne(
    String message, {
    required List<String> choices,
    String? defaultValue,
  }) {
    asked.add(message);
    return stack ?? defaultValue ?? choices.first;
  }

  @override
  List<String> chooseAny(
    String message, {
    required List<String> choices,
    List<String>? defaultValues,
  }) {
    asked.add(message);
    return targets ?? defaultValues ?? choices;
  }
}

/// Harness do CLI em memória.
class CliHarness {
  CliHarness({
    FileSystem? fs,
    String? fixture,
    FakeProcessRunner? processRunner,
    ScriptedPrompter? prompter,
    Map<String, String>? environment,
    this.interactive = false,
    this.packageRoot,
  }) : fs = fs ?? memoryFs(fixture: fixture),
       processRunner = processRunner ?? FakeProcessRunner(),
       prompter = prompter ?? ScriptedPrompter(),
       environment = environment ?? {'SDD_KIT_PATH': memKitPath};

  final FileSystem fs;
  final FakeProcessRunner processRunner;
  final ScriptedPrompter prompter;
  final Map<String, String> environment;
  final bool interactive;
  final Uri? packageRoot;
  final out = StringBuffer();
  final err = StringBuffer();

  Future<int> run(List<String> args) {
    out.clear();
    err.clear();
    return SddCommandRunner(
      SddContext(
        fs: fs,
        processRunner: processRunner,
        prompter: prompter,
        environment: environment,
        workingDirectory: memProjectPath,
        packageRoot: () async => packageRoot,
        out: out,
        err: err,
        interactive: interactive,
      ),
    ).run(args);
  }

  String read(String relative) =>
      fs.file(p.join(memProjectPath, relative)).readAsStringSync();

  bool exists(String relative) =>
      fs.file(p.join(memProjectPath, relative)).existsSync();
}
