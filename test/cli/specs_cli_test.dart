import 'dart:convert';

import 'package:flutter_sdd/flutter_sdd.dart';
import 'package:test/test.dart';

import '../helpers/test_env.dart';

const spec = '0001-login-biometria';

Future<CliHarness> project({String fixture = 'app_with_spec'}) async {
  final cli = CliHarness(fixture: fixture);
  expect(await cli.run(['init', '-y']), ExitCodes.ok);
  return cli;
}

Map<String, Object?> json(CliHarness cli) =>
    jsonDecode(cli.out.toString()) as Map<String, Object?>;

void main() {
  group('sdd new', () {
    test('cria spec numerada com prd do template', () async {
      final cli = await project(fixture: 'app_cubit');
      expect(await cli.run(['new', 'Login', 'com', 'Biometria']), ExitCodes.ok);
      expect(
        cli.out.toString(),
        contains('criado specs/0001-login-com-biometria/'),
      );
      expect(
        cli.read('specs/0001-login-com-biometria/prd.md'),
        startsWith('# PRD · Login com Biometria\n'),
      );
      expect(
        cli.read('specs/0001-login-com-biometria/status.yaml'),
        contains('phase: analyze'),
      );
      expect(await cli.run(['--json', 'new', 'Outra feature']), ExitCodes.ok);
      expect(json(cli), {
        'spec': '0002-outra-feature',
        'path': 'specs/0002-outra-feature',
      });
    });

    test('erros de uso', () async {
      final cli = await project(fixture: 'app_cubit');
      expect(await cli.run(['new']), ExitCodes.usage);
      expect(await cli.run(['new', '!!!']), ExitCodes.usage);
      expect(cli.err.toString(), contains('slug'));
      final noInit = CliHarness(fixture: 'app_cubit');
      expect(await noInit.run(['new', 'x']), ExitCodes.usage);
      expect(noInit.err.toString(), contains('rode sdd init'));
    });
  });

  group('sdd tasks', () {
    test('validate ok, com avisos e com erros', () async {
      final cli = await project();
      expect(await cli.run(['tasks', 'validate', spec]), ExitCodes.ok);
      expect(cli.out.toString(), contains('ok · 4 tarefas · 3 ondas'));

      // T04 com owns de T02 na mesma onda → erro; AC-03 sem tarefa → aviso.
      final t03 = cli.fs.file(
        '$memProjectPath/specs/$spec/tasks/T03-login-cubit.md',
      );
      t03.writeAsStringSync(
        t03
            .readAsStringSync()
            .replaceFirst(
              'lib/features/auth/presentation/cubit/login_cubit.dart',
              'lib/features/auth/data/auth_repository_impl.dart',
            )
            .replaceFirst('acceptance: [AC-01, AC-03]', 'acceptance: [AC-01]'),
      );
      expect(await cli.run(['tasks', 'validate', '1']), ExitCodes.failure);
      final out = cli.out.toString();
      expect(
        out,
        contains('FAIL T03  specs/$spec/tasks/T03-login-cubit.md  owns:'),
      );
      expect(out, contains('WARN specs/$spec/spec.md  AC-03 sem tarefa'));
      expect(out, contains('1 erros · 1 avisos'));

      expect(
        await cli.run(['--json', 'tasks', 'validate', '1']),
        ExitCodes.failure,
      );
      final doc = json(cli);
      expect(doc['ok'], isFalse);
      expect((doc['errors']! as List).single, containsPair('task', 'T03'));
    });

    test('graph em texto, mermaid e json', () async {
      final cli = await project();
      expect(await cli.run(['tasks', 'graph', spec]), ExitCodes.ok);
      expect(
        cli.out.toString(),
        contains('onda 2\n  T04 [pending] Tarefa T04 ← T02, T03'),
      );
      expect(
        await cli.run(['tasks', 'graph', spec, '--mermaid']),
        ExitCodes.ok,
      );
      expect(cli.out.toString(), contains('T03 --> T04'));
      expect(await cli.run(['--json', 'tasks', 'graph', spec]), ExitCodes.ok);
      expect(json(cli)['tasks']! as List, hasLength(4));
    });

    test('next acompanha o fluxo de ondas', () async {
      final cli = await project();
      expect(await cli.run(['--json', 'tasks', 'next', spec]), ExitCodes.ok);
      final doc = json(cli);
      expect(doc['wave'], 0);
      expect(
        (doc['ready']! as List).single,
        containsPair('agent', 'sdd-implementer-deep'),
      );

      await cli.run(['status', 'set', spec, 'T01', 'in_progress']);
      await cli.run(['status', 'set', spec, 'T01', 'done']);
      expect(await cli.run(['tasks', 'next', spec]), ExitCodes.ok);
      expect(cli.out.toString(), contains('onda 1 · 2 prontas'));
      expect(cli.out.toString(), contains('T03  sdd-implementer-fast'));

      await cli.run(['status', 'set', spec, 'T02', 'in_progress']);
      await cli.run(['status', 'set', spec, 'T02', 'failed']);
      await cli.run(['status', 'set', spec, 'T03', 'in_progress']);
      expect(await cli.run(['tasks', 'next', spec]), ExitCodes.ok);
      expect(cli.out.toString(), contains('T02  sdd-implementer-standard'));
      expect(cli.out.toString(), contains('(tentativa 2)'));
      expect(cli.out.toString(), contains('em andamento: T03'));

      await cli.run(['status', 'set', spec, 'T03', 'blocked']);
      expect(await cli.run(['tasks', 'next', spec]), ExitCodes.ok);
      expect(cli.out.toString(), contains('bloqueadas: T03'));

      for (final t in ['T02', 'T03', 'T04']) {
        await cli.run(['status', 'set', spec, t, 'in_progress']);
        await cli.run(['status', 'set', spec, t, 'done']);
      }
      expect(await cli.run(['tasks', 'next', spec]), ExitCodes.ok);
      expect(cli.out.toString(), contains('todas as tarefas concluídas'));
    });

    test('next recusa tarefas inválidas; spec inexistente', () async {
      final cli = await project();
      cli.fs.file('$memProjectPath/specs/$spec/spec.md').deleteSync();
      expect(await cli.run(['tasks', 'next', spec]), ExitCodes.failure);
      expect(cli.err.toString(), contains('rode sdd tasks validate'));
      expect(await cli.run(['tasks', 'graph', spec]), ExitCodes.ok);
      expect(cli.err.toString(), contains('tarefas com erros'));
      expect(await cli.run(['tasks', 'next', '9']), ExitCodes.usage);
      expect(await cli.run(['tasks', 'next']), ExitCodes.usage);
    });
  });

  group('sdd status', () {
    test('lista, detalhe e json', () async {
      final cli = await project();
      await cli.run(['new', 'Outra']);
      expect(await cli.run(['status']), ExitCodes.ok);
      final out = cli.out.toString();
      expect(out, contains('$spec  exec     tarefas 0/4  (análise ✓ plano ✓)'));
      expect(out, contains('0002-outra  analyze  sem tarefas'));

      await cli.run(['status', 'set', spec, 'T01', 'in_progress']);
      expect(await cli.run(['status', '1']), ExitCodes.ok);
      expect(cli.out.toString(), contains('onda 0: T01 in_progress'));

      expect(await cli.run(['--json', 'status', spec]), ExitCodes.ok);
      final doc = json(cli);
      final specs = doc['specs']! as List;
      expect((specs.single as Map)['counts'], containsPair('in_progress', 1));
      expect(doc['learnings'], {'pending': 0, 'limit': 15});
    });

    test('specs concluídas somem da lista; aviso de learnings', () async {
      final cli = await project(fixture: 'app_cubit');
      expect(await cli.run(['status']), ExitCodes.ok);
      expect(cli.out.toString(), contains('nenhuma spec aberta'));
      cli.fs
          .file('$memProjectPath/.sdd/memory/learnings.md')
          .writeAsStringSync(List.filled(16, '- lição').join('\n'));
      expect(await cli.run(['status']), ExitCodes.ok);
      expect(cli.err.toString(), contains('learnings.md com 16 lições'));
      expect(await cli.run(['status', 'a', 'b']), ExitCodes.usage);
    });

    test(
      'set: json, exit 1 em transição inválida, exit 2 em gramática',
      () async {
        final cli = await project();
        expect(
          await cli.run([
            '--json',
            'status',
            'set',
            spec,
            'T01',
            'in_progress',
          ]),
          ExitCodes.ok,
        );
        expect(json(cli), containsPair('tier_used', 'deep'));
        expect(
          await cli.run(['status', 'set', spec, 'T02', 'in_progress']),
          ExitCodes.failure,
        );
        expect(cli.err.toString(), contains('não concluídas: T01'));
        expect(
          await cli.run(['status', 'set', spec, 'T01', 'zzz']),
          ExitCodes.usage,
        );
        expect(await cli.run(['status', 'set']), ExitCodes.usage);
        expect(
          await cli.run(['status', 'set', '9', 'T01', 'done']),
          ExitCodes.usage,
        );
        cli.fs
            .file('$memProjectPath/specs/$spec/status.yaml')
            .writeAsStringSync('quebrado: [');
        expect(
          await cli.run(['status', 'set', spec, 'T01', 'done']),
          ExitCodes.usage,
        );
        expect(await cli.run(['status', spec]), ExitCodes.usage);
      },
    );
  });
}
