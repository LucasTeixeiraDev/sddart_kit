import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/status/spec_status.dart';
import 'package:test/test.dart';

void main() {
  test('estado inicial serializa no formato compacto', () {
    expect(const SpecStatus(spec: '0001-x').serialize(), '''
# escrito pelo sdd — não edite; use sdd status set
spec: "0001-x"
phase: analyze
gates: {analysis_approved: false, plan_approved: false}
tasks: {}
review: {state: pending, blockers: 0, cycles: 0}
''');
  });

  test('ida e volta com tarefas em ordem natural', () {
    final status = const SpecStatus(spec: '0001-x', phase: Phase.exec)
        .withTask('T10', const TaskStatus(state: TaskState.done, attempts: 1))
        .withTask(
          'T2',
          const TaskStatus(state: TaskState.inProgress, tierUsed: Tier.deep),
        );
    final text = status.serialize();
    expect(
      text,
      contains(
        'tasks:\n  T2: {state: in_progress, attempts: 0, tier_used: deep}\n'
        '  T10: {state: done, attempts: 1}\n',
      ),
    );
    final parsed = SpecStatus.parse(text);
    expect(parsed.phase, Phase.exec);
    expect(parsed.task('T2').tierUsed, Tier.deep);
    expect(parsed.task('T10').attempts, 1);
    expect(parsed.task('T99').state, TaskState.pending);
    expect(parsed.serialize(), text);
  });

  test('formato do brief (mapas de fluxo, campos opcionais)', () {
    final s = SpecStatus.parse('''
spec: 0042-login-biometria
phase: exec
gates: { analysis_approved: true }
tasks:
  T01: { state: done, attempts: 1, tier_used: deep }
  T03: { state: in_progress }
''');
    expect(s.gate('analysis_approved'), isTrue);
    expect(s.gate('plan_approved'), isFalse);
    expect(s.task('T03').attempts, 0);
    expect(s.review.state, ReviewState.pending);
  });

  test('erros apontam o campo', () {
    void bad(String yaml, String field) => expect(
      () => SpecStatus.parse(yaml),
      throwsA(
        isA<FormatException>().having((e) => e.message, 'msg', contains(field)),
      ),
    );
    bad('spec: [', 'inválido');
    bad('- a', 'esperado mapa');
    bad('phase: exec', 'campo spec');
    bad('spec: x\nphase: nope', 'campo phase');
    bad('spec: x\nphase: exec\ngates: {a: 1}', 'campo gates');
    bad('spec: x\nphase: exec\ntasks: [1]', 'campo tasks');
    bad('spec: x\nphase: exec\ntasks: {T1: 1}', 'tasks.T1');
    bad('spec: x\nphase: exec\ntasks: {T1: {state: zzz}}', 'tasks.T1.state');
    bad(
      'spec: x\nphase: exec\ntasks: {T1: {state: done, attempts: -1}}',
      'tasks.T1.attempts',
    );
    bad(
      'spec: x\nphase: exec\ntasks: {T1: {state: done, tier_used: x}}',
      'tasks.T1.tier_used',
    );
    bad('spec: x\nphase: exec\nreview: 1', 'campo review');
    bad('spec: x\nphase: exec\nreview: {state: x}', 'review.state');
    bad('spec: x\nphase: exec\nreview: {blockers: x}', 'review.blockers');
    bad('spec: x\nphase: exec\nreview: {cycles: x}', 'review.cycles');
  });

  test('compareTaskIds', () {
    final ids = ['T10', 'T2', 'T01', 'Tx']..sort(compareTaskIds);
    expect(ids, ['T01', 'T2', 'T10', 'Tx']);
  });
}
