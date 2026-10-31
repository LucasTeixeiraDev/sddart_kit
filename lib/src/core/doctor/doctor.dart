import 'package:file/file.dart';
import 'package:flutter_sdd/src/core/config/config_issue.dart';
import 'package:flutter_sdd/src/core/config/config_parser.dart';
import 'package:flutter_sdd/src/core/config/model_resolver.dart';
import 'package:flutter_sdd/src/core/kit/kit_locator.dart';
import 'package:flutter_sdd/src/core/kit/kit_lock.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:flutter_sdd/src/core/kit/stack_definition.dart';
import 'package:flutter_sdd/src/core/project/project_info.dart';
import 'package:flutter_sdd/src/core/project/project_loader.dart';
import 'package:flutter_sdd/src/core/project/sdd_paths.dart';
import 'package:flutter_sdd/src/infra/process_runner.dart';

enum CheckStatus { ok, warn, fail }

class DoctorCheck {
  const DoctorCheck(this.name, this.status, this.message);

  final String name;
  final CheckStatus status;
  final String message;

  Map<String, Object?> toJson() => {
    'name': name,
    'status': status.name,
    'message': message,
  };
}

/// Verificações de ambiente e projeto do `sdd doctor`.
class Doctor {
  const Doctor({
    required this.fs,
    required this.processRunner,
    required this.kitLocator,
    required this.cliVersion,
  });

  final FileSystem fs;
  final ProcessRunner processRunner;
  final KitLocator kitLocator;
  final String cliVersion;

  Future<List<DoctorCheck>> run(String root, {String? kitPath}) async {
    final checks = <DoctorCheck>[
      await _tool('dart', ['--version']),
      await _tool('flutter', ['--version']),
      await _tool('git', ['--version']),
      await _gitRepo(root),
    ];

    KitLocation? kit;
    try {
      kit = await kitLocator.locate(kitPath: kitPath);
      checks.add(
        DoctorCheck('kit', CheckStatus.ok, '${kit.path} (${kit.source.name})'),
      );
    } on KitNotFoundException catch (e) {
      checks.add(DoctorCheck('kit', CheckStatus.fail, e.message));
    }

    final paths = SddPaths(root);
    final configFile = fs.file(paths.config);
    if (!configFile.existsSync()) {
      checks.add(
        const DoctorCheck(
          'config',
          CheckStatus.fail,
          '.sdd/config.yaml ausente; rode sdd init',
        ),
      );
      return checks;
    }
    if (kit == null) return checks;

    final source = configFile.readAsStringSync();
    final stackName = peekStack(source);
    final stackFile = stackName == null
        ? null
        : fs.file(kit.stackFile(stackName));
    if (stackFile == null || !stackFile.existsSync()) {
      checks.add(
        DoctorCheck(
          'stack',
          CheckStatus.fail,
          'stack "${stackName ?? '(kit.stack ausente)'}" não existe no kit',
        ),
      );
      return checks;
    }
    final StackDefinition stack;
    try {
      stack = StackDefinition.parse(stackFile.readAsStringSync());
    } on FormatException catch (e) {
      checks.add(DoctorCheck('stack', CheckStatus.fail, e.message));
      return checks;
    }
    checks
      ..add(DoctorCheck('stack', CheckStatus.ok, stack.name))
      ..addAll(_expectedDependencies(root, stack));

    try {
      final result = parseConfig(source, stackDefaults: stack.configDefaults);
      checks
        ..add(const DoctorCheck('config', CheckStatus.ok, 'válido'))
        ..addAll([
          for (final w in result.warnings)
            DoctorCheck('config', CheckStatus.warn, '$w'),
          for (final w in modelWarnings(result.config))
            DoctorCheck('models', CheckStatus.warn, w),
        ]);
    } on ConfigException catch (e) {
      checks.addAll([
        for (final issue in e.issues)
          DoctorCheck('config', CheckStatus.fail, '$issue'),
      ]);
    }

    checks
      ..add(_lock(paths, kit, stack.name))
      ..add(await _sdd());
    if (checks.every((c) => c.status != CheckStatus.fail)) {
      checks.add(await _sync(root, kitPath));
    }
    return checks;
  }

  /// Hooks gerados (format, guard do reviewer) chamam `sdd` pelo PATH.
  Future<DoctorCheck> _sdd() async {
    final result = await processRunner.run('sdd', ['--version']);
    return result.ok
        ? DoctorCheck('sdd', CheckStatus.ok, result.stdout.trim())
        : const DoctorCheck(
            'sdd',
            CheckStatus.warn,
            'sdd fora do PATH; hooks gerados não vão rodar '
                '(dart pub global activate)',
          );
  }

  Future<DoctorCheck> _sync(String root, String? kitPath) async {
    try {
      final project = await loadProject(
        fs: fs,
        root: root,
        locator: kitLocator,
        kitPath: kitPath,
      );
      final plan = project.planSync(fs, cliVersion);
      return plan.upToDate
          ? const DoctorCheck('sync', CheckStatus.ok, 'em dia')
          : DoctorCheck(
              'sync',
              CheckStatus.warn,
              '${plan.changes.length} mudanças pendentes; rode sdd sync',
            );
    } on KitException catch (e) {
      return DoctorCheck('sync', CheckStatus.fail, 'kit/overrides: $e');
    } on ProjectLoadException catch (e) {
      return DoctorCheck('sync', CheckStatus.fail, e.message);
    }
  }

  /// Dependências que o stack assume: só aviso, nunca falha.
  List<DoctorCheck> _expectedDependencies(String root, StackDefinition stack) {
    final ProjectInfo project;
    try {
      project = ProjectDetector(fs).detect(root);
    } on ProjectDetectionException catch (e) {
      return [DoctorCheck('deps', CheckStatus.warn, e.message)];
    }
    final missing = [
      for (final dep in stack.expectedDependencies)
        if (!project.dependsOn(dep)) dep,
    ];
    return [
      if (missing.isEmpty)
        const DoctorCheck('deps', CheckStatus.ok, 'dependências do stack ok')
      else
        DoctorCheck(
          'deps',
          CheckStatus.warn,
          '${missing.join(', ')} ausente(s) no pubspec '
              '(o stack ${stack.name} as assume)',
        ),
    ];
  }

  DoctorCheck _lock(SddPaths paths, KitLocation kit, String stack) {
    final file = fs.file(paths.kitLock);
    if (!file.existsSync()) {
      return const DoctorCheck(
        'kit.lock',
        CheckStatus.fail,
        'ausente; rode sdd init',
      );
    }
    try {
      final check = checkLock(
        KitLock.parse(file.readAsStringSync()),
        cliVersion: cliVersion,
        kitHash: computeKitHash(fs, kit, stack),
      );
      final status = switch (check.status) {
        LockStatus.ok => CheckStatus.ok,
        LockStatus.newerThanCli => CheckStatus.fail,
        LockStatus.outdated || LockStatus.kitChanged => CheckStatus.warn,
      };
      return DoctorCheck('kit.lock', status, check.message);
    } on FormatException catch (e) {
      return DoctorCheck('kit.lock', CheckStatus.fail, e.message);
    }
  }

  Future<DoctorCheck> _tool(String executable, List<String> args) async {
    final result = await processRunner.run(executable, args);
    if (!result.ok) {
      return DoctorCheck(
        executable,
        CheckStatus.fail,
        result.exitCode == ProcessOutput.notFound
            ? 'não encontrado no PATH'
            : 'falhou (exit ${result.exitCode})',
      );
    }
    final output = '${result.stdout}\n${result.stderr}'.trim();
    return DoctorCheck(executable, CheckStatus.ok, output.split('\n').first);
  }

  Future<DoctorCheck> _gitRepo(String root) async {
    final result = await processRunner.run('git', [
      'rev-parse',
      '--is-inside-work-tree',
    ], workingDirectory: root);
    return result.ok
        ? const DoctorCheck('git repo', CheckStatus.ok, 'sim')
        : const DoctorCheck(
            'git repo',
            CheckStatus.fail,
            'não é um repositório git (necessário para sdd check --task)',
          );
  }
}
