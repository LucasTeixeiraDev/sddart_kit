import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/tasks/task.dart';
import 'package:test/test.dart';

import '../../helpers/task_builders.dart';

(TaskSpec?, List<TaskIssue>) parse(String md, {String file = 'T01-a.md'}) {
  final issues = <TaskIssue>[];
  return (parseTask(md, 'specs/0001-x/tasks/$file', issues), issues);
}

List<String> errors(List<TaskIssue> issues) => [
  for (final i in issues.where((i) => !i.isWarning)) i.message,
];

void main() {
  test('tarefa válida com campos opcionais', () {
    final (t, issues) = parse(
      taskMd(
        extra:
            'depends_on: []\nreads: [lib/b.dart]\nexemplar: ./lib/c.dart\n'
            'brick: repository\nacceptance: [AC-01]\n',
      ),
    );
    expect(issues, isEmpty);
    expect(t!.id, 'T01');
    expect(t.tier, Tier.standard);
    expect(t.exemplar, 'lib/c.dart');
    expect(t.brick, 'repository');
    expect(t.acceptance, ['AC-01']);
    expect(t.file, 'specs/0001-x/tasks/T01-a.md');
  });

  test('brick_vars', () {
    final (t, issues) = parse(
      taskMd(extra: 'brick: failure\nbrick_vars: {feature: wallet, n: 2}\n'),
    );
    expect(issues, isEmpty);
    expect(t!.brickVars, {'feature': 'wallet', 'n': '2'});
    expect(
      errors(parse(taskMd(extra: 'brick_vars: {feature: x}\n')).$2),
      contains('brick_vars exige brick'),
    );
    expect(
      errors(parse(taskMd(extra: 'brick: f\nbrick_vars: [1]\n')).$2),
      contains('brick_vars: esperado mapa de valores simples'),
    );
  });

  test('sem frontmatter ou id inválido', () {
    expect(errors(parse('## Objetivo').$2), ['frontmatter ausente']);
    expect(errors(parse('---\na: [\n---\n').$2).single, contains('inválido'));
    final (t, issues) = parse(taskMd(id: 'X1'));
    expect(t, isNull);
    expect(errors(issues).single, contains('id: esperado formato T01'));
  });

  test('erros de campos e seções', () {
    final (t, issues) = parse(
      '---\nid: T02\nwave: -1\ntier: huge\nagent: sdd-Impl\nowns: []\n'
      'depends_on: [X]\nreads: [../fora.dart]\nexemplar: /abs.dart\n'
      'acceptance: 3\nextra: 1\n---\n## Objetivo\n',
    );
    expect(t, isNull);
    final errs = errors(issues);
    expect(
      errs,
      containsAll([
        'nome do arquivo deve começar com "T02-"',
        'title: esperado string',
        'wave: esperado inteiro >= 0',
        'tier: "huge" inválido (use deep, standard, fast)',
        'agent: nome canônico inválido (sem prefixo sdd-)',
        'depends_on: "X" não é um id de tarefa',
        'owns: obrigatório (>= 1 item)',
        'reads: caminho "../fora.dart" deve ser relativo à raiz, sem ".."',
        'exemplar: caminho deve ser relativo à raiz, sem ".."',
        'acceptance: esperado lista de strings',
        'corpo sem a seção "## Detalhes"',
        'corpo sem a seção "## Pronto da tarefa"',
      ]),
    );
    final warnings = issues.where((i) => i.isWarning).map((i) => i.message);
    expect(warnings, contains('extra: chave desconhecida'));
    expect(warnings.any((w) => w.contains('sdd check --task T02')), isTrue);
    expect(issues.first.toJson()['file'], 'specs/0001-x/tasks/T01-a.md');
    expect('${issues.first}', contains('T02'));
  });
}
