// Caminhos e comandos esperados ficam inteiros para serem buscáveis.
// ignore_for_file: lines_longer_than_80_chars
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_sdd/flutter_sdd.dart';
import 'package:flutter_sdd/src/infra/brick_generator.dart';
import 'package:flutter_sdd/src/infra/process_runner.dart';
import 'package:test/test.dart';

import '../helpers/fake_process_runner.dart';
import '../helpers/test_env.dart';

/// Gerador falso: registra as variáveis e devolve arquivos fixos.
class FakeBrickGenerator implements BrickGenerator {
  FakeBrickGenerator(this.files);

  final List<BrickFile> files;
  Map<String, Object?>? vars;
  String? brickPath;

  @override
  Future<List<BrickFile>> generate({
    required String brickPath,
    required String targetDir,
    required Map<String, Object?> vars,
  }) async {
    this.brickPath = brickPath;
    this.vars = vars;
    return files;
  }
}

Future<CliHarness> project(FakeBrickGenerator generator) async {
  final runner = FakeProcessRunner();
  final cli = CliHarness(
    fixture: 'app_with_spec',
    processRunner: runner,
    brickGenerator: generator,
  );
  expect(await cli.run(['init', '-y']), ExitCodes.ok);
  return cli;
}

void main() {
  group('sdd scaffold', () {
    test('resolve variáveis automáticas e arruma só os .dart criados', () async {
      final generator = FakeBrickGenerator(const [
        BrickFile(
          'lib/features/auth/domain/failures/auth_failure.dart',
          BrickFileStatus.created,
        ),
        BrickFile('lib/features/auth/x.dart', BrickFileStatus.skipped),
        BrickFile('lib/features/auth/.gitkeep', BrickFileStatus.created),
      ]);
      final cli = await project(generator);
      cli.processRunner.calls.clear();
      expect(
        await cli.run(['scaffold', 'failure', '--vars', 'feature=auth']),
        ExitCodes.ok,
      );
      expect(generator.brickPath, endsWith('bricks/failure'));
      expect(generator.vars, containsPair('package', 'app_with_spec'));
      expect(generator.vars, containsPair('features_path', 'lib/features'));
      expect(generator.vars, containsPair('features_import', 'features'));
      expect(
        generator.vars,
        containsPair(
          'result_import',
          'package:app_with_spec/core/result/result.dart',
        ),
      );
      final calls = [
        for (final c in cli.processRunner.calls)
          [c.executable, ...c.arguments].join(' '),
      ];
      expect(calls, [
        'dart fix --apply --code=directives_ordering lib/features/auth/domain/failures/auth_failure.dart',
        'dart format lib/features/auth/domain/failures/auth_failure.dart',
      ]);
      expect(cli.out.toString(), contains('failure: 2 criados · 1 mantidos'));
    });

    test('--task avisa arquivos fora dos owns; json', () async {
      final generator = FakeBrickGenerator(const [
        BrickFile(
          'lib/features/auth/data/auth_repository_impl.dart',
          BrickFileStatus.created,
        ),
        BrickFile(
          'lib/features/auth/domain/extra.dart',
          BrickFileStatus.created,
        ),
      ]);
      final cli = await project(generator);
      cli.processRunner.responses['dart format'] = const ProcessOutput(
        1,
        stderr: 'erro',
      );
      expect(
        await cli.run([
          '--json',
          'scaffold',
          'repository',
          '--vars',
          'feature=auth',
          '--task',
          'T02',
        ]),
        ExitCodes.ok,
      );
      final doc = jsonDecode(cli.out.toString()) as Map<String, Object?>;
      expect(doc['outside_owns'], ['lib/features/auth/domain/extra.dart']);
      expect((doc['files']! as List).first, containsPair('status', 'created'));
      expect(cli.err.toString(), contains('dart format falhou'));

      expect(
        await cli.run([
          'scaffold',
          'repository',
          '--vars',
          'feature=auth',
          '--task',
          'T02',
          '--spec',
          '1',
        ]),
        ExitCodes.ok,
      );
      expect(cli.err.toString(), contains('fora dos owns de T02'));
    });

    test('erros de uso', () async {
      final cli = await project(FakeBrickGenerator(const []));
      expect(await cli.run(['scaffold']), ExitCodes.usage);
      expect(await cli.run(['scaffold', 'nope']), ExitCodes.usage);
      expect(cli.err.toString(), contains('disponíveis: cubit, datasource'));
      expect(await cli.run(['scaffold', 'usecase']), ExitCodes.usage);
      expect(cli.err.toString(), contains('faltam variáveis feature'));
      expect(
        await cli.run(['scaffold', 'failure', '--vars', 'x']),
        ExitCodes.usage,
      );
      expect(
        await cli.run([
          'scaffold',
          'failure',
          '--vars',
          'feature=a',
          '--task',
          'T99',
        ]),
        ExitCodes.usage,
      );
      cli.fs.file('$memProjectPath/pubspec.yaml').deleteSync();
      expect(
        await cli.run(['scaffold', 'failure', '--vars', 'feature=a']),
        ExitCodes.usage,
      );
    });
  });

  group('sdd import scan', () {
    test('funciona sem .sdd/; humano e json', () async {
      final cli = CliHarness();
      copyIntoMemory(
        '$repoRoot/test/fixtures/import_source',
        cli.fs,
        '$memProjectPath/origem',
      );
      expect(await cli.run(['import', 'scan', 'origem']), ExitCodes.ok);
      final out = cli.out.toString();
      expect(out, contains('(dup: .cursor/commands/deploy.md same_content)'));
      expect(
        out,
        contains(
          '2 agent · 2 skill · 4 rule · 2 command · 2 memory · 1 gerados',
        ),
      );

      expect(
        await cli.run(['--json', 'import', 'scan', 'origem']),
        ExitCodes.ok,
      );
      final doc = jsonDecode(cli.out.toString()) as Map<String, Object?>;
      expect(doc['source'], '$memProjectPath/origem');

      expect(await cli.run(['import', 'scan', 'nada']), ExitCodes.usage);
      expect(await cli.run(['import', 'scan']), ExitCodes.usage);
      cli.fs.directory('$memProjectPath/vazio').createSync();
      expect(await cli.run(['import', 'scan', 'vazio']), ExitCodes.ok);
      expect(cli.out.toString(), contains('nada encontrado'));
    });
  });

  test('mason real gera o brick failure do kit (integração)', () async {
    final dir = io.Directory.systemTemp.createTempSync('sdd-brick');
    addTearDown(() => dir.deleteSync(recursive: true));
    final files = await const MasonBrickGenerator().generate(
      brickPath: '$repoRoot/kit/stacks/flutter-clean-cubit/bricks/failure',
      targetDir: dir.path,
      vars: {'feature': 'user_profile', 'features_path': 'lib/features'},
    );
    expect(
      files.single.path,
      'lib/features/user_profile/domain/failures/user_profile_failure.dart',
    );
    expect(files.single.status, BrickFileStatus.created);
    final content = io.File(
      '${dir.path}/${files.single.path}',
    ).readAsStringSync();
    expect(content, contains('sealed class UserProfileFailure'));
    final again = await const MasonBrickGenerator().generate(
      brickPath: '$repoRoot/kit/stacks/flutter-clean-cubit/bricks/failure',
      targetDir: dir.path,
      vars: {'feature': 'user_profile', 'features_path': 'lib/features'},
    );
    expect(again.single.status, BrickFileStatus.identical);
  });
}
