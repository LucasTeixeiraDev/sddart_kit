import 'dart:io' as io;

import 'package:file/memory.dart';
import 'package:flutter_sdd/src/core/gates/gate_result.dart';
import 'package:flutter_sdd/src/core/gates/gate_runner.dart';
import 'package:flutter_sdd/src/core/specs/spec_repository.dart';
import 'package:flutter_sdd/src/core/status/spec_status.dart';
import 'package:flutter_sdd/src/infra/process_runner.dart';
import 'package:test/test.dart';

import '../../helpers/fake_process_runner.dart';
import '../../helpers/task_builders.dart';
import '../../helpers/test_env.dart';

const specId = '0001-login-biometria';
const t02Impl = 'lib/features/auth/data/auth_repository_impl.dart';
const t03Cubit = 'lib/features/auth/presentation/cubit/login_cubit.dart';

String realOutput(String name) => io.File(
  'test/fixtures/outputs/$name.txt',
).readAsStringSync().replaceAll('<ROOT>', memProjectPath);

void main() {
  late MemoryFileSystem fs;
  late FakeProcessRunner runner;

  setUp(() {
    fs = memoryFs(fixture: 'app_with_spec');
    runner = FakeProcessRunner({
      'git diff': const ProcessOutput(0, stdout: '$t02Impl\n'),
      'git ls-files': const ProcessOutput(0),
    });
  });

  void write(String rel, [String content = '// x']) =>
      fs.file('$memProjectPath/$rel')
        ..createSync(recursive: true)
        ..writeAsStringSync(content);

  GateRunner gates([String extra = '']) => GateRunner(
    fs: fs,
    processRunner: runner,
    root: memProjectPath,
    config: testConfig(extra),
  );

  SpecDir load({Map<String, TaskStatus> tasks = const {}}) {
    final spec = SpecRepository(fs, memProjectPath).load(specId);
    return SpecDir(
      id: spec.id,
      path: spec.path,
      tasks: spec.tasks,
      taskIssues: spec.taskIssues,
      status: statusWith(tasks),
      specMd: spec.specMd,
    );
  }

  group('modo tarefa', () {
    test('tudo verde: arquivos de owns e reporter json', () async {
      write(t02Impl);
      final spec = load();
      final report = await gates().runTask(spec, spec.task('T02')!);
      expect(report.ok, isTrue);
      expect(
        [for (final r in report.results) r.status],
        [GateStatus.pass, GateStatus.pass, GateStatus.skip, GateStatus.pass],
      );
      final format = runner.calls.firstWhere((c) => c.executable == 'dart');
      expect(format.arguments, [
        'format',
        '--output=none',
        '--set-exit-if-changed',
        t02Impl,
      ]);
      expect(format.workingDirectory, memProjectPath);
    });

    test('testes de owns rodam com --reporter json', () async {
      write('test/features/auth/domain/auth_test.dart');
      write('lib/features/auth/domain/auth_repository.dart');
      final spec = load();
      await gates().runTask(spec, spec.task('T01')!);
      final test = runner.calls.firstWhere((c) => c.executable == 'flutter');
      expect(test.arguments, [
        'test',
        '--reporter',
        'json',
        'test/features/auth/domain/auth_test.dart',
      ]);
    });

    test('sem arquivos .dart existentes: format/analyze pulados', () async {
      final spec = load();
      final report = await gates().runTask(spec, spec.task('T02')!);
      expect(report.results.first.status, GateStatus.skip);
      expect(report.results[1].note, contains('nenhum .dart'));
    });

    test('owns: fora do escopo, tolerâncias e gerados', () async {
      write(t02Impl);
      runner.responses['git diff'] = const ProcessOutput(
        0,
        stdout:
            '$t02Impl\n$t03Cubit\nlib/core/di/injector.dart\n'
            'specs/$specId/status.yaml\nlib/a.g.dart\n',
      );
      runner.responses['git ls-files'] = const ProcessOutput(
        0,
        stdout: 'lib/extra.dart\n',
      );
      // T03 (mesma onda) iniciada: seus arquivos são tolerados.
      final spec = load(
        tasks: {'T03': const TaskStatus(state: TaskState.inProgress)},
      );
      final report = await gates().runTask(spec, spec.task('T02')!);
      final owns = report.results.last;
      expect(owns.status, GateStatus.fail);
      expect(
        [for (final f in owns.failures) f.location],
        ['lib/core/di/injector.dart', 'lib/extra.dart'],
      );

      // Sem T03 iniciada, o arquivo dela também é reportado.
      final strict = await gates().runTask(load(), load().task('T02')!);
      expect([
        for (final f in strict.results.last.failures) f.location,
      ], contains(t03Cubit));
    });

    test('owns: fora de repo git ou sem commits', () async {
      final spec = load();
      runner.responses['git rev-parse'] = const ProcessOutput(128);
      var report = await gates().runTask(spec, spec.task('T02')!);
      expect(report.results.last.failures.single.message, contains('não é'));
      runner.responses
        ..remove('git rev-parse')
        ..['git diff'] = const ProcessOutput(128);
      report = await gates().runTask(spec, spec.task('T02')!);
      expect(
        report.results.last.failures.single.message,
        contains('sem commits'),
      );
    });

    test(
      'analyze com falhas reais; interferência de tarefa em andamento',
      () async {
        write(t02Impl);
        runner.responses['dart analyze'] = ProcessOutput(
          3,
          stderr:
              '${realOutput('analyze_machine')}\n'
              "ERROR|COMPILE_TIME_ERROR|URI_DOES_NOT_EXIST|$memProjectPath/$t02Impl|1|8|10|Target of URI doesn't exist: 'package:app/features/auth/presentation/cubit/login_cubit.dart'.\n",
        );
        final spec = load(
          tasks: {'T03': const TaskStatus(state: TaskState.inProgress)},
        );
        final report = await gates().runTask(spec, spec.task('T02')!);
        final analyze = report.results[1];
        expect(analyze.status, GateStatus.fail);
        expect(analyze.failures, hasLength(4));
        expect(analyze.failures.last.interferenceWith, 'T03');
        expect(analyze.failures.first.interferenceWith, isNull);
        expect(report.onlyInterference, isFalse);
      },
    );

    test('só interferência', () async {
      write(t02Impl);
      runner.responses['dart analyze'] = const ProcessOutput(
        3,
        stderr:
            'ERROR|COMPILE_TIME_ERROR|UNDEFINED_CLASS|$memProjectPath/$t03Cubit|1|1|1|x\n',
      );
      final spec = load(
        tasks: {'T03': const TaskStatus(state: TaskState.inProgress)},
      );
      final report = await gates().runTask(spec, spec.task('T02')!);
      expect(report.onlyInterference, isTrue);
    });

    test('comando inexistente, sem parse e sem comando no config', () async {
      write(t02Impl);
      runner.responses['dart format'] = const ProcessOutput(
        ProcessOutput.notFound,
      );
      runner.responses['dart analyze'] = const ProcessOutput(
        1,
        stdout: 'explodiu\n',
      );
      final spec = load();
      final report = await gates().runTask(spec, spec.task('T02')!);
      expect(
        report.results[0].failures.single.message,
        'dart não encontrado no PATH',
      );
      expect(report.results[1].failures.single.message, 'explodiu');
    });
  });

  group('modo spec', () {
    const fullLcov =
        'SF:lib/features/auth/domain/a.dart\nDA:1,1\nDA:2,1\nend_of_record\n';

    test('DoD verde: test_all com json, cobertura e rastreabilidade', () async {
      write('coverage/lcov.info', fullLcov);
      write('test/a_test.dart', "test('[AC-01] a', () {}); // [AC-02] [AC-03]");
      final report = await gates(
        'dod: {coverage: {paths: ["lib/features/**/domain/**"]}}',
      ).runSpec(load());
      expect(
        report.ok,
        isTrue,
        reason: '${[for (final r in report.results) r.toJson()]}',
      );
      final test = runner.calls.firstWhere((c) => c.executable == 'flutter');
      expect(test.arguments, ['test', '--reporter', 'json', '--coverage']);
      expect(report.results.last.note, '3 ACs');
      expect(report.results[3].note, '100.0% (mínimo 80%)');
    });

    test('falhas de format, testes, cobertura e rastreabilidade', () async {
      write(
        'coverage/lcov.info',
        '${fullLcov}SF:lib/features/auth/domain/b.dart\nDA:1,0\nDA:2,0\nDA:3,0\nend_of_record\n',
      );
      write('test/a_test.dart', "test('[AC-01] a', () {});");
      runner.responses
        ..['dart format'] = ProcessOutput(1, stdout: realOutput('format'))
        ..['flutter test'] = ProcessOutput(1, stdout: realOutput('test_json'));
      final report = await gates(
        'dod: {coverage: {paths: ["lib/**"]}}',
      ).runSpec(load());
      final byGate = {for (final r in report.results) r.gate: r};
      expect(byGate['format']!.failures.single.location, 'lib/src/ugly.dart');
      expect(byGate['test']!.failures, hasLength(3));
      expect(
        byGate['coverage']!.failures.first.message,
        'total 40.0% (mínimo 80%)',
      );
      expect(
        byGate['coverage']!.failures.last.location,
        'lib/features/auth/domain/b.dart',
      );
      expect(
        [for (final f in byGate['traceability']!.failures) f.message],
        ['AC-02 sem teste com a tag', 'AC-03 sem teste com a tag'],
      );
      expect(report.failureCount, 8);
    });

    test('sem lcov, lcov fora do escopo, sem spec, sem spec.md', () async {
      var report = await gates().runSpec(null);
      final byGate = {for (final r in report.results) r.gate: r};
      expect(byGate['coverage']!.failures.single.message, contains('ausente'));
      expect(byGate['traceability']!.status, GateStatus.skip);

      write('coverage/lcov.info', 'SF:bin/x.dart\nDA:1,1\nend_of_record\n');
      fs.file('$memProjectPath/specs/$specId/spec.md').deleteSync();
      report = await gates(
        'dod: {coverage: {paths: ["lib/**"]}}',
      ).runSpec(load());
      final again = {for (final r in report.results) r.gate: r};
      expect(again['coverage']!.status, GateStatus.skip);
      expect(again['traceability']!.failures.single.message, 'spec.md ausente');
    });

    test('spec sem ACs, gate customizado e teste sem eventos', () async {
      fs
          .file('$memProjectPath/specs/$specId/spec.md')
          .writeAsStringSync('nada');
      runner.responses
        ..['dart run custom_lint'] = const ProcessOutput(
          1,
          stdout: '  lib/a.dart:3:1 • regra • x • ERROR\n',
        )
        ..['flutter test'] = const ProcessOutput(1, stderr: 'sem flutter');
      final report = await gates(
        'commands: {custom_lint: dart run custom_lint}\n'
        'dod: {gates: [custom_lint, test, traceability]}',
      ).runSpec(load());
      final byGate = {for (final r in report.results) r.gate: r};
      expect(byGate['custom_lint']!.failures.single.location, 'lib/a.dart:3');
      expect(byGate['test']!.failures.single.message, 'sem flutter');
      expect(byGate['traceability']!.status, GateStatus.skip);
    });

    test('teste com eventos e exit != 0 sem falhas parseadas', () async {
      runner.responses['flutter test'] = const ProcessOutput(
        1,
        stdout: '{"type":"done","success":false}',
      );
      final report = await gates('dod: {gates: [test]}').runSpec(null);
      expect(
        report.results.single.failures.single.message,
        'falhou sem detalhes',
      );
    });

    test(
      'format no modo completo recebe "." e saída vazia é explicada',
      () async {
        runner.responses['dart format'] = const ProcessOutput(64);
        final report = await gates('dod: {gates: [format]}').runSpec(null);
        final format = runner.calls.single;
        expect(format.arguments.last, '.');
        expect(
          report.results.single.failures.single.message,
          'saiu com código 64 sem saída',
        );
      },
    );

    test('comando com aspas abertas', () async {
      final report = await gates(
        'commands: {format: "dart format \\"x"}\ndod: {gates: [format]}',
      ).runSpec(null);
      expect(report.results.single.failures.single.message, contains('aspas'));
    });
  });
}
