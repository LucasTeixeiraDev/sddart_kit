import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/specs/spec_repository.dart';
import 'package:flutter_sdd/src/core/status/spec_status.dart';
import 'package:flutter_sdd/src/core/status/status_transitions.dart';
import 'package:flutter_sdd/src/core/tasks/task.dart';
import 'package:test/test.dart';

import '../../helpers/task_builders.dart';

final List<TaskSpec> tasks = [
  task('T01'),
  task('T02', wave: 1, deps: ['T01']),
];

StatusSetResult set(SpecStatus status, String args, {String config = ''}) =>
    applyStatusSet(
      specWith(tasks, status: status),
      args.split(' '),
      testConfig(config),
    );

Matcher fails(String text, {bool usage = false}) => throwsA(
  isA<StatusSetException>()
      .having((e) => e.message, 'message', contains(text))
      .having((e) => e.usage, 'usage', usage),
);

void main() {
  final exec = statusWith({});

  group('tarefas', () {
    test('ciclo feliz registra tier e transições', () {
      final started = set(exec, 'T01 in_progress');
      expect(started.message, 'T01: pending → in_progress (tier standard)');
      expect(started.status.task('T01').tierUsed, Tier.standard);
      final done = set(started.status, 'T01 done');
      expect(done.status.task('T01').state, TaskState.done);
      expect(done.change['to'], 'done');
    });

    test('falhas incrementam tentativas, escalam e bloqueiam', () {
      var s = exec;
      for (var i = 0; i < 2; i++) {
        s = set(s, 'T01 in_progress').status;
        s = set(s, 'T01 failed').status;
      }
      expect(s.task('T01').attempts, 2);
      final escalated = set(s, 'T01 in_progress');
      expect(escalated.message, contains('tier deep, escalada'));
      final blocked = set(escalated.status, 'T01 failed');
      expect(blocked.status.task('T01').state, TaskState.blocked);
      expect(blocked.message, contains('tentativas esgotadas'));
      // Humano libera a tarefa: in_progress a partir de blocked é aceito.
      expect(
        set(blocked.status, 'T01 in_progress').status.task('T01').state,
        TaskState.inProgress,
      );
      // Reset manual zera tentativas.
      expect(set(blocked.status, 'T01 pending').status.task('T01').attempts, 0);
    });

    test('guardas', () {
      expect(
        () => set(statusWith({}, phase: Phase.tasks), 'T01 in_progress'),
        fails('phase exec'),
      );
      expect(() => set(exec, 'T02 in_progress'), fails('não concluídas: T01'));
      expect(() => set(exec, 'T01 done'), fails('nunca foi iniciada'));
      expect(() => set(exec, 'T01 failed'), fails('não está in_progress'));
      expect(() => set(exec, 'T09 done'), fails('T09 não existe'));
      expect(() => set(exec, 'T01 zzz'), fails('inválido', usage: true));
      expect(() => set(exec, 'T01 done extra'), fails('extras', usage: true));
      final running = set(exec, 'T01 in_progress').status;
      expect(() => set(running, 'T01 in_progress'), fails('já está'));
      final done = set(running, 'T01 done').status;
      expect(() => set(done, 'T01 blocked'), fails('já está done'));
      final exhausted = statusWith({
        'T01': const TaskStatus(state: TaskState.failed, attempts: 3),
      });
      expect(() => set(exhausted, 'T01 in_progress'), fails('sem tentativas'));
    });
  });

  group('gates', () {
    test('ordem, revogação em cascata e valores', () {
      const fresh = SpecStatus(spec: '0001-x');
      expect(
        () => set(fresh, 'gate plan_approved'),
        fails('exige analysis_approved'),
      );
      final a = set(fresh, 'gate analysis_approved').status;
      final b = set(a, 'gate plan_approved true').status;
      expect(b.gate('plan_approved'), isTrue);
      final revoked = set(b, 'gate analysis_approved false').status;
      expect(revoked.gate('plan_approved'), isFalse);
      expect(() => set(fresh, 'gate nope'), fails('inválido', usage: true));
      expect(
        () => set(fresh, 'gate analysis_approved talvez'),
        fails('uso:', usage: true),
      );
    });
  });

  group('fases', () {
    test('exigem gates e done exige tarefas e revisão', () {
      const fresh = SpecStatus(spec: '0001-x');
      expect(set(fresh, 'phase analyze').status.phase, Phase.analyze);
      expect(() => set(fresh, 'phase spec'), fails('exige gate analysis'));
      expect(() => set(fresh, 'phase exec'), fails('exige gate plan'));
      expect(() => set(exec, 'phase done'), fails('não concluídas: T01, T02'));
      final allDone = statusWith({
        'T01': const TaskStatus(state: TaskState.done),
        'T02': const TaskStatus(state: TaskState.done),
      });
      expect(() => set(allDone, 'phase done'), fails('revisão não aprovada'));
      final approved = set(allDone, 'review approved').status;
      expect(set(approved, 'phase done').status.phase, Phase.done);
      expect(() => set(exec, 'phase zzz'), fails('inválida', usage: true));
      expect(() => set(exec, 'phase exec x'), fails('extras', usage: true));
    });
  });

  group('revisão', () {
    test('ciclos limitados e blockers', () {
      var s = exec;
      for (var i = 1; i <= 2; i++) {
        s = set(s, 'review in_progress').status;
        expect(s.review.cycles, i);
        s = set(s, 'review changes_requested blockers=2').status;
      }
      expect(s.review.blockers, 2);
      expect(() => set(s, 'review in_progress'), fails('máximo de 2 ciclos'));
      expect(
        set(
          s,
          'review in_progress',
          config: 'execution: {max_review_cycles: 3}',
        ).status.review.cycles,
        3,
      );
      expect(() => set(s, 'review approved'), fails('2 blockers'));
      expect(
        set(s, 'review approved blockers=0').status.review.state,
        ReviewState.approved,
      );
      expect(() => set(s, 'review x'), fails('inválido', usage: true));
      expect(
        () => set(s, 'review pending b=1'),
        fails('inválido', usage: true),
      );
    });
  });

  test('gramática', () {
    expect(() => set(exec, 'T01'), fails('uso:', usage: true));
    expect(() => set(exec, 'xyz 1'), fails('alvo "xyz"', usage: true));
  });

  test('specWith expõe SpecDir', () {
    expect(specWith(tasks), isA<SpecDir>());
  });
}
