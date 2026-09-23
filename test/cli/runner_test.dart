import 'dart:convert';
import 'dart:io';

import 'package:flutter_sdd/flutter_sdd.dart';
import 'package:flutter_sdd/src/infra/process_runner.dart';
import 'package:test/test.dart';

import '../helpers/fake_process_runner.dart';
import '../helpers/test_env.dart';

void main() {
  test('versão do código bate com o pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('\nversion: $sddVersion\n'));
  });

  test('--version', () async {
    final cli = CliHarness();
    expect(await cli.run(['--version']), ExitCodes.ok);
    expect(cli.out.toString().trim(), sddVersion);
  });

  test('comando desconhecido retorna exit 2', () async {
    final cli = CliHarness();
    expect(await cli.run(['nope']), ExitCodes.usage);
    expect(cli.err.toString(), contains('Could not find a command'));
  });

  group('sdd doctor', () {
    test('projeto inicializado e ambiente ok', () async {
      final cli = CliHarness(fixture: 'app_cubit');
      await cli.run(['init', '-y']);
      expect(await cli.run(['doctor']), ExitCodes.ok);
      final out = cli.out.toString();
      expect(out, contains('OK   config    válido'));
      expect(out, contains('OK   kit.lock  sdd $sddVersion'));
      expect(out, contains('0 falhas · 0 avisos'));
    });

    test('sync pendente, sdd fora do PATH e kit inválido', () async {
      final runner = FakeProcessRunner({
        'sdd --version': const ProcessOutput(ProcessOutput.notFound),
      });
      final cli = CliHarness(fixture: 'app_cubit', processRunner: runner);
      await cli.run(['init', '-y']);
      cli.fs.file('$memProjectPath/AGENTS.md').deleteSync();
      expect(await cli.run(['doctor']), ExitCodes.ok);
      expect(cli.out.toString(), contains('WARN sync      1 mudanças'));
      expect(cli.out.toString(), contains('WARN sdd       sdd fora do PATH'));

      cli.fs.file('$memProjectPath/.sdd/overrides/agents/x.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('---\n---\n');
      expect(await cli.run(['doctor']), ExitCodes.failure);
      expect(cli.out.toString(), contains('FAIL sync      kit/overrides'));
    });

    test('--json e falhas retornam exit 1', () async {
      final runner = FakeProcessRunner({
        'flutter': const ProcessOutput(ProcessOutput.notFound),
      });
      final cli = CliHarness(fixture: 'app_cubit', processRunner: runner);
      expect(await cli.run(['--json', 'doctor']), ExitCodes.failure);
      final doc = jsonDecode(cli.out.toString()) as Map<String, Object?>;
      expect(doc['ok'], isFalse);
      final checks = (doc['checks']! as List).cast<Map<String, Object?>>();
      expect(
        checks.firstWhere((c) => c['name'] == 'flutter')['status'],
        'fail',
      );
    });
  });
}
