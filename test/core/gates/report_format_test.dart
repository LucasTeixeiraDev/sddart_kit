import 'package:flutter_sdd/src/core/gates/gate_result.dart';
import 'package:flutter_sdd/src/core/gates/report_format.dart';
import 'package:test/test.dart';

void main() {
  final report = CheckReport(
    mode: 'task',
    spec: '0042-login',
    task: 'T03',
    results: [
      const GateResult.pass('format'),
      GateResult.fail('analyze', const [
        GateFailure('avoid_dynamic_calls: x', location: 'lib/a.dart:42'),
        GateFailure('b', location: 'lib/b.dart:1', interferenceWith: 'T04'),
        GateFailure('c'),
      ]),
      const GateResult.skip('test', 'nenhum *_test.dart em owns'),
      GateResult.fail('owns', const [
        GateFailure('alterado fora de owns', location: 'lib/core/di.dart'),
      ]),
    ],
  );

  test('saída humana compacta e truncada', () {
    expect(formatReport(report, maxLines: 2), '''
FAIL analyze   lib/a.dart:42  avoid_dynamic_calls: x
INTF analyze   lib/b.dart:1  b  (T04 em andamento)
     analyze   … +1 falhas
FAIL owns      lib/core/di.dart  alterado fora de owns
PASS format
SKIP test      nenhum *_test.dart em owns
4 falhas · 1 gates ok
''');
  });

  test('só interferência é sinalizado', () {
    final intf = CheckReport(
      mode: 'task',
      results: [
        GateResult.fail('test', const [
          GateFailure('x', interferenceWith: 'T04'),
        ]),
      ],
    );
    expect(formatReport(intf), contains('só interferência'));
    expect(reportJson(intf)['interference'], isTrue);
    expect(
      GateResult.fail('x', const []).failures.single.message,
      contains('sem detalhes'),
    );
  });

  test('json estável com truncamento', () {
    final json = reportJson(report, maxLines: 2);
    expect(json['ok'], isFalse);
    expect(json['failures'], 4);
    expect(json['interference'], isFalse);
    final gates = json['gates']! as List;
    final analyze = gates[1] as Map;
    expect(analyze['status'], 'fail');
    expect(analyze['failures'], hasLength(2));
    expect(analyze['truncated'], 1);
    expect((analyze['failures'] as List)[1], {
      'location': 'lib/b.dart:1',
      'message': 'b',
      'interference_with': 'T04',
    });
    expect(gates[2], {
      'gate': 'test',
      'status': 'skip',
      'note': 'nenhum *_test.dart em owns',
    });
  });
}
