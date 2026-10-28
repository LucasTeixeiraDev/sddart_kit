import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/status/spec_status.dart';
import 'package:flutter_sdd/src/core/tasks/scheduler.dart';
import 'package:test/test.dart';

import '../../helpers/task_builders.dart';

void main() {
  group('executionFor (max_fix_attempts 2, escalate_to deep)', () {
    final exec = testConfig().execution;
    ExecutionPlan plan(int failures, {Tier tier = Tier.standard}) =>
        executionFor(
          task('T01', tier: tier),
          TaskStatus(attempts: failures),
          exec,
        );

    test('tentativas no tier da tarefa, depois escalada, depois esgotada', () {
      expect(plan(0).tier, Tier.standard);
      expect(plan(0).attempt, 1);
      expect(plan(1).tier, Tier.standard);
      expect(plan(2).tier, Tier.deep);
      expect(plan(2).escalated, isTrue);
      expect(plan(3).exhausted, isTrue);
    });

    test('tarefa já deep não escala', () {
      expect(plan(2, tier: Tier.deep).exhausted, isTrue);
    });
  });

  test('resolveAgentName', () {
    expect(
      resolveAgentName('implementer', Tier.fast, realBundle),
      'sdd-implementer-fast',
    );
    expect(resolveAgentName('explorer', Tier.deep, realBundle), 'sdd-explorer');
    expect(resolveAgentName('x', Tier.deep, null), 'sdd-x');
  });

  group('computeNext', () {
    final tasks = [
      task('T01'),
      task('T02', wave: 1, deps: ['T01'], tier: Tier.fast),
      task('T03', wave: 1, deps: ['T01']),
      task('T04', wave: 1, deps: ['T01']),
      task('T05', wave: 2, deps: ['T02']),
    ];

    test('início: só a onda 0', () {
      final next = computeNext(
        specWith(tasks),
        testConfig(),
        bundle: realBundle,
      );
      expect(next.wave, 0);
      expect(next.ready.single.agent, 'sdd-implementer-standard');
      expect(next.remaining, 5);
      expect(next.complete, isFalse);
    });

    test('onda 1 com andamento, retentativa e esgotada', () {
      final status = statusWith({
        'T01': const TaskStatus(state: TaskState.done),
        'T02': const TaskStatus(state: TaskState.failed, attempts: 2),
        'T03': const TaskStatus(state: TaskState.inProgress),
        'T04': const TaskStatus(state: TaskState.failed, attempts: 3),
      });
      final next = computeNext(
        specWith(tasks, status: status),
        testConfig(),
        bundle: realBundle,
      );
      expect(next.wave, 1);
      final t02 = next.ready.single;
      expect(t02.task.id, 'T02');
      expect(t02.agent, 'sdd-implementer-deep');
      expect(t02.toJson()['escalated'], isTrue);
      expect(t02.toJson()['attempt'], 3);
      expect(next.inProgress, ['T03']);
      expect(next.blocked, ['T04']);
      final json = next.toJson('0001-x');
      expect(json['wave'], 1);
      expect(json['remaining'], 4);
    });

    test('bloqueada explicitamente e tudo concluído', () {
      final blocked = computeNext(
        specWith(
          [task('T01')],
          status: statusWith({
            'T01': const TaskStatus(state: TaskState.blocked),
          }),
        ),
        testConfig(),
      );
      expect(blocked.blocked, ['T01']);
      expect(blocked.ready, isEmpty);

      final done = computeNext(
        specWith(
          [task('T01')],
          status: statusWith({'T01': const TaskStatus(state: TaskState.done)}),
        ),
        testConfig(),
      );
      expect(done.complete, isTrue);
      expect(done.wave, isNull);
      expect(done.toJson('x')['complete'], isTrue);
    });
  });
}
