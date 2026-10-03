import 'dart:convert';

import 'package:flutter_sdd/flutter_sdd.dart';
import 'package:flutter_sdd/src/infra/process_runner.dart';
import 'package:test/test.dart';

import '../helpers/fake_process_runner.dart';
import '../helpers/test_env.dart';

const spec = '0001-login-biometria';

Future<CliHarness> project() async {
  final runner = FakeProcessRunner({
    'git diff': const ProcessOutput(0),
    'git ls-files': const ProcessOutput(0),
  });
  final cli = CliHarness(fixture: 'app_with_spec', processRunner: runner);
  expect(await cli.run(['init', '-y']), ExitCodes.ok);
  return cli;
}

void main() {
  test('--task infere a spec; saída compacta; exit 0', () async {
    final cli = await project();
    expect(await cli.run(['check', '--task', 'T02']), ExitCodes.ok);
    expect(cli.out.toString(), contains('PASS owns'));
    expect(cli.out.toString(), contains('0 falhas'));
  });

  test('--task com falha de owns → exit 1 e json', () async {
    final cli = await project();
    cli.processRunner.responses['git ls-files'] = const ProcessOutput(
      0,
      stdout: 'lib/core/di/injector.dart\n',
    );
    expect(
      await cli.run(['--json', 'check', '--spec', '1', '--task', 'T02']),
      ExitCodes.failure,
    );
    final doc = jsonDecode(cli.out.toString()) as Map<String, Object?>;
    expect(doc['ok'], isFalse);
    expect(doc['task'], 'T02');
    expect(doc['spec'], spec);
  });

  test('sem --task: DoD completo na spec ativa única', () async {
    final cli = await project();
    expect(await cli.run(['check']), ExitCodes.failure);
    final out = cli.out.toString();
    expect(out, contains('FAIL coverage'));
    expect(out, contains('FAIL traceability  specs/$spec/spec.md  AC-01'));
    expect(await cli.run(['check', '--max-lines', '1']), ExitCodes.failure);
    expect(cli.out.toString(), contains('… +2 falhas'));
  });

  test('erros de uso', () async {
    final cli = await project();
    expect(await cli.run(['check', '--task', 'T99']), ExitCodes.usage);
    expect(cli.err.toString(), contains('T99 não encontrada'));
    expect(
      await cli.run(['check', '--spec', '1', '--task', 'T99']),
      ExitCodes.usage,
    );
    expect(await cli.run(['check', '--spec', '9']), ExitCodes.usage);
    expect(await cli.run(['check', '--max-lines', '0']), ExitCodes.usage);

    // A mesma tarefa em duas specs abertas exige --spec.
    const other = '$memProjectPath/specs/0002-outra';
    cli.fs.directory('$other/tasks').createSync(recursive: true);
    cli.fs
        .file('$memProjectPath/specs/$spec/tasks/T02-auth-repository-impl.md')
        .copySync('$other/tasks/T02-x.md');
    expect(await cli.run(['check', '--task', 'T02']), ExitCodes.usage);
    expect(cli.err.toString(), contains('use --spec'));

    cli.fs.file('$other/status.yaml').writeAsStringSync('ruim: [');
    expect(await cli.run(['check']), ExitCodes.usage);
  });
}
