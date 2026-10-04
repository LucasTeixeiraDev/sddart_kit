import 'dart:convert';

import 'package:flutter_sdd/flutter_sdd.dart';
import 'package:flutter_sdd/src/infra/process_runner.dart';
import 'package:test/test.dart';

import '../helpers/fake_process_runner.dart';
import '../helpers/test_env.dart';

/// Repete, sobre o app de referência (`dogfood_app`), o contrato do
/// orquestrador com os artefatos reais do dogfooding do M7
/// (`dogfood_run/`): gates humanos, ondas, check por tarefa, revisão em dois
/// ciclos e fechamento. Processos externos (flutter, git) são falsos.
void main() {
  const spec = '0001-saldo-da-carteira';

  test('fluxo completo do dogfooding: analyze → close', () async {
    final runner = FakeProcessRunner({
      'git diff': const ProcessOutput(0),
      'git ls-files': const ProcessOutput(0),
    });
    final cli = CliHarness(fixture: 'dogfood_app', processRunner: runner);
    Future<Map<String, Object?>> sdd(
      List<String> args, {
      int exit = ExitCodes.ok,
    }) async {
      final code = await cli.run(args);
      expect(code, exit, reason: '${args.join(' ')}\n${cli.err}');
      return args.contains('--json')
          ? jsonDecode(cli.out.toString()) as Map<String, Object?>
          : const {};
    }

    await sdd(['init', '-y']);
    await sdd(['new', 'Saldo da carteira']);
    expect(cli.read('specs/$spec/prd.md'), contains('Saldo da carteira'));

    // Artefatos produzidos pelos agentes no dogfooding.
    copyIntoMemory(
      '$repoRoot/test/fixtures/dogfood_run/specs/$spec',
      cli.fs,
      '$memProjectPath/specs/$spec',
    );

    // Gates humanos e guardas de fase.
    await sdd(['status', 'set', '1', 'phase', 'spec'], exit: ExitCodes.failure);
    await sdd(['status', 'set', '1', 'gate', 'analysis_approved']);
    await sdd(['status', 'set', '1', 'phase', 'spec']);
    await sdd(['status', 'set', '1', 'gate', 'plan_approved']);
    await sdd(['status', 'set', '1', 'phase', 'tasks']);

    final validation = await sdd(['--json', 'tasks', 'validate', '1']);
    expect(validation['ok'], isTrue);
    expect(validation['tasks'], 8);
    expect(validation['waves'], 5);
    expect(validation['warnings'], isEmpty);

    await sdd(['status', 'set', '1', 'phase', 'exec']);

    // Loop do /sdd-exec: ondas sequenciais, agente pelo tier da tarefa.
    final waves = <int>[];
    final agents = <String, String>{};
    while (true) {
      final next = await sdd(['--json', 'tasks', 'next', '1']);
      if (next['complete'] == true) break;
      waves.add(next['wave']! as int);
      final ready = (next['ready']! as List).cast<Map<String, Object?>>();
      expect(ready, isNotEmpty);
      for (final r in ready) {
        await sdd(['status', 'set', '1', '${r['id']}', 'in_progress']);
      }
      for (final r in ready) {
        final id = '${r['id']}';
        agents[id] = '${r['agent']}';
        final check = await sdd(['--json', 'check', '--task', id]);
        expect(check['ok'], isTrue, reason: '$id: $check');
        await sdd(['status', 'set', '1', id, 'done']);
      }
    }
    expect(waves, [0, 1, 2, 3, 4]);
    expect(agents, {
      'T01': 'sdd-implementer-deep',
      'T02': 'sdd-implementer-standard',
      'T03': 'sdd-implementer-deep',
      'T04': 'sdd-implementer-standard',
      'T05': 'sdd-implementer-deep',
      'T06': 'sdd-implementer-standard',
      'T07': 'sdd-implementer-fast',
      'T08': 'sdd-implementer-standard',
    });

    // Revisão em dois ciclos (o 1º gerou a T08) e fechamento.
    await sdd(['status', 'set', '1', 'phase', 'review']);
    await sdd(['status', 'set', '1', 'review', 'in_progress']);
    await sdd(['status', 'set', '1', 'review', 'changes_requested']);
    await sdd(['status', 'set', '1', 'review', 'in_progress']);
    await sdd(['status', 'set', '1', 'phase', 'done'], exit: ExitCodes.failure);
    await sdd(['status', 'set', '1', 'review', 'approved', 'blockers=0']);
    await sdd(['status', 'set', '1', 'phase', 'done']);

    final status = await sdd(['--json', 'status', '1']);
    final detail = (status['specs']! as List).single as Map<String, Object?>;
    expect(detail['phase'], 'done');
    expect(detail['counts'], containsPair('done', 8));
    expect(detail['review'], containsPair('cycles', 2));

    // Grafo e sync seguem consistentes no fim.
    await sdd(['tasks', 'graph', '1', '--mermaid']);
    expect(cli.out.toString(), contains('T02 --> T05'));
    await sdd(['sync', '--check']);
  });
}
