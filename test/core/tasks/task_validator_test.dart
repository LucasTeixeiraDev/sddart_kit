import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:flutter_sdd/src/core/tasks/task.dart';
import 'package:flutter_sdd/src/core/tasks/task_validator.dart';
import 'package:test/test.dart';

import '../../helpers/task_builders.dart';

ValidationResult validate(
  List<TaskSpec> tasks, {
  Set<String> existing = const {},
  String? specMd = 'AC-01 AC-02',
  String config = '',
}) => validateTasks(
  specWith(tasks, specMd: specMd),
  config: testConfig(config),
  exists: existing.contains,
  bundle: realBundle,
);

List<String> errorsOf(ValidationResult r) => [
  for (final i in r.errors) i.message,
];

void main() {
  test('DAG válido (sem erros nem avisos)', () {
    final r = validate(
      [
        task('T01', acceptance: ['AC-01']),
        task('T02', wave: 1, deps: ['T01'], reads: ['lib/T01.dart']),
        task(
          'T03',
          wave: 2,
          deps: ['T02'],
          reads: ['lib/T01.dart'],
          acceptance: ['AC-02'],
          exemplar: 'lib/ex.dart',
        ),
      ],
      existing: {'lib/ex.dart'},
    );
    expect(r.issues, isEmpty);
    expect(r.ok, isTrue);
  });

  test('ids, dependências e ondas', () {
    final r = validate([
      task('T01', acceptance: ['AC-01', 'AC-02']),
      task('T01', owns: ['lib/x.dart']),
      task('T02', deps: ['T01', 'T09']),
    ]);
    expect(
      errorsOf(r),
      containsAll([
        'id duplicado (também em specs/0001-x/tasks/T01-x.md)',
        'depends_on: T09 não existe',
        'depends_on: T01 está na onda 0 (deve ser < 0)',
      ]),
    );
  });

  test('ciclos', () {
    final r = validate([
      task('T01', wave: 1, deps: ['T02'], acceptance: ['AC-01', 'AC-02']),
      task('T02', wave: 1, deps: ['T01']),
    ]);
    expect(errorsOf(r), contains('ciclo de dependências: T01 → T02 → T01'));
    expect(findCycles({}), isEmpty);
  });

  test('owns conflitantes só na mesma onda', () {
    final r = validate([
      task('T01', owns: ['lib/a.dart'], acceptance: ['AC-01', 'AC-02']),
      task('T02', owns: ['lib/a.dart']),
      task('T03', wave: 1, deps: ['T01'], owns: ['lib/a.dart']),
    ]);
    expect(errorsOf(r), ['owns: lib/a.dart também é de T01 (onda 0)']);
  });

  test('reads, exemplar e agente', () {
    final r = validate(
      [
        task('T01', acceptance: ['AC-01', 'AC-02']),
        task(
          'T02',
          wave: 1,
          deps: ['T01'],
          reads: ['lib/T01.dart', 'lib/existe.dart', 'lib/nada.dart'],
          exemplar: 'lib/sumiu.dart',
        ),
        task('T03', wave: 1, agent: 'nope'),
        task('T04', wave: 1, agent: 'explorer', tier: Tier.fast),
      ],
      existing: {'lib/existe.dart'},
    );
    expect(errorsOf(r), [
      'reads: lib/nada.dart não existe nem é owns de uma dependência',
      'exemplar: lib/sumiu.dart não existe',
      'agent: "nope" não existe no kit',
    ]);
  });

  test('tier sem variante e escalonamento sem variante', () {
    const bundle = KitBundle(
      agents: [
        KitAgent(
          name: 'implementer',
          description: 'd',
          body: '',
          layer: KitLayer.core,
          sourcePath: 'x',
          tier: Tier.standard,
          tierVariants: [Tier.fast, Tier.standard],
          tools: [],
          readonly: false,
        ),
      ],
      skills: [],
      rules: [],
      commands: [],
      templates: {},
    );
    final r = validateTasks(
      specWith([
        task('T01', tier: Tier.deep, acceptance: ['AC-01', 'AC-02']),
      ]),
      config: testConfig(),
      exists: (_) => false,
      bundle: bundle,
    );
    expect(errorsOf(r).single, contains('tier: deep sem variante'));
    expect(r.warnings.single.message, contains('escalonamento para deep'));
  });

  test('ACs: inexistente na spec, sem tarefa e spec.md ausente', () {
    final r = validate([
      task('T01', acceptance: ['AC-01', 'AC-09']),
    ]);
    expect(errorsOf(r), ['acceptance: AC-09 não existe em spec.md']);
    expect(r.warnings.single.message, 'AC-02 sem tarefa');

    final noSpec = validate([task('T01')], specMd: null);
    expect(errorsOf(noSpec), ['spec.md ausente']);

    expect(
      specAcceptanceIds('AC-01 x AC-02 AC-01 AC-1', RegExp(r'AC-\d{2,}')),
      ['AC-01', 'AC-02'],
    );
  });

  test('nenhuma tarefa', () {
    expect(errorsOf(validate([])), contains('nenhuma tarefa em tasks/'));
  });
}
