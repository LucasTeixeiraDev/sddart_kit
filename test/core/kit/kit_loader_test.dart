import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/kit/kit_loader.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:test/test.dart';

import '../../helpers/sample_project.dart';
import '../../helpers/test_env.dart';

List<String> issuesOf(SampleProject project) {
  try {
    project.bundle();
  } on KitException catch (e) {
    return e.issues;
  }
  fail('esperava KitException');
}

void main() {
  test('carrega o kit de exemplo', () {
    final bundle = SampleProject().bundle();
    expect(bundle.agents.map((a) => a.name), ['judge', 'worker']);
    final worker = bundle.agents.last;
    expect(worker.tier, Tier.standard);
    expect(worker.tierVariants, [Tier.fast, Tier.deep]);
    expect(worker.skills, ['writing']);
    expect(worker.layer, KitLayer.core);
    final judge = bundle.agents.first;
    expect(judge.readonly, isTrue);
    expect(judge.bashAllow, ['sdd check']);
    expect(judge.writeAllow, ['specs/*/review.md']);
    expect(bundle.skills.single.files.map((f) => f.relativePath), [
      'references/guide.md',
      'run.sh',
    ]);
    expect(bundle.rules.map((r) => r.name), ['always', 'domain']);
    expect(bundle.rules.first.always, isTrue);
    expect(bundle.commands.single.args, '<spec>');
    expect(bundle.templates.keys, ['agents-md-section.md']);
  });

  test('override substitui item e disabled remove', () {
    final project = SampleProject()
      ..write(
        '.sdd/overrides/rules/domain.md',
        '---\ndescription: Minha regra.\nglobs: [lib/**]\n---\nOutra.\n',
      )
      ..write('.sdd/overrides/commands/go.md', '---\ndisabled: true\n---\n')
      ..write(
        '.sdd/overrides/skills/writing/SKILL.md',
        '---\ndescription: Minha skill.\n---\nX\n',
      )
      ..write('.sdd/overrides/templates/extra.md', 'x');
    final bundle = project.bundle();
    final domain = bundle.rules.firstWhere((r) => r.name == 'domain');
    expect(domain.description, 'Minha regra.');
    expect(domain.layer, KitLayer.override);
    expect(bundle.commands, isEmpty);
    // Skill sobrescrita não herda arquivos de apoio do kit.
    expect(bundle.skills.single.files, isEmpty);
    expect(bundle.templates.keys, contains('extra.md'));
  });

  test('camada inexistente é ignorada', () {
    final bundle = KitLoader(
      SampleProject().fs,
    ).load(const [KitLayerDir(KitLayer.core, '/nada')]);
    expect(bundle.agents, isEmpty);
  });

  test('valida agentes', () {
    final project = SampleProject()
      ..write(
        '.sdd/overrides/agents/bad.md',
        '---\ntier: huge\ntools: [read, fly, write]\nreadonly: true\n'
            'write_allow: [x]\n'
            'bash_allow: [x]\nskills: [nope]\ntier_variants: [x]\n---\n',
      )
      ..write('.sdd/overrides/agents/Bad_Name.md', '---\n---\n')
      ..write('.sdd/overrides/agents/named.md', '---\nname: other\n---\n')
      ..write('.sdd/overrides/agents/ro.md', '---\nreadonly: sim\n---\n')
      ..write('.sdd/overrides/agents/notools.md', '---\ntools: read\n---\n')
      ..write(
        '.sdd/overrides/agents/rw.md',
        '---\ndescription: d\ntier: fast\ntools: [read]\n'
            'write_allow: [x]\n---\n',
      );
    final issues = issuesOf(project).join('\n');
    expect(issues, contains('"description" obrigatório'));
    expect(issues, contains('tier "huge" inválido'));
    expect(issues, contains('tier_variants "x" inválido'));
    expect(issues, contains('tool "fly" inválida'));
    expect(issues, contains('agente readonly não pode ter edit/write'));
    expect(issues, contains('bash_allow exige a tool bash'));
    expect(issues, contains('nome "Bad_Name" inválido'));
    expect(issues, contains('name "other" difere do nome do arquivo'));
    expect(issues, contains('readonly deve ser booleano'));
    expect(issues, contains('"tools" deve ser lista de strings'));
    expect(issues, contains('write_allow só faz sentido em agente readonly'));
  });

  test('valida skill que referencia inexistente', () {
    final project = SampleProject()
      ..write(
        '.sdd/overrides/agents/x.md',
        '---\ndescription: d\ntier: fast\ntools: [read]\nskills: [nope]\n---\n',
      );
    const path = '$memProjectPath/.sdd/overrides/agents/x.md';
    expect(issuesOf(project), ['$path: skill "nope" não existe no kit']);
  });

  test('valida rules, commands e skills', () {
    final project = SampleProject()
      ..write('.sdd/overrides/rules/r1.md', '---\ndescription: d\n---\n')
      ..write(
        '.sdd/overrides/rules/r2.md',
        '---\ndescription: d\nalways: sim\n---\n',
      )
      ..write('.sdd/overrides/rules/r3.md', '---\nalways: true\n---\n')
      ..write('.sdd/overrides/commands/c1.md', '---\nargs: 3\n---\n')
      ..write('.sdd/overrides/commands/c2.md', 'sem frontmatter')
      ..write('.sdd/overrides/skills/s1/other.md', 'x')
      ..write('.sdd/overrides/skills/s2/SKILL.md', '---\na: [\n---\n');
    final issues = issuesOf(project).join('\n');
    expect(issues, contains('rule precisa de globs ou always: true'));
    expect(issues, contains('always deve ser booleano'));
    expect(issues, contains('args deve ser string'));
    expect(issues, contains('c2.md: "description" obrigatório'));
    expect(issues, contains('s1: SKILL.md ausente'));
    expect(issues, contains('s2/SKILL.md: frontmatter inválido'));
  });

  test('kit real do pacote carrega sem erros', () {
    final fs = memoryFs();
    final bundle = KitLoader(fs).load(const [
      KitLayerDir(KitLayer.core, '$memKitPath/core'),
      KitLayerDir(KitLayer.stack, '$memKitPath/stacks/flutter-clean-cubit'),
    ]);
    expect(bundle.agents, hasLength(7));
    expect(bundle.commands, hasLength(8));
    expect(bundle.skills, hasLength(11));
    expect(bundle.rules, hasLength(5));
    expect(bundle.bricks.map((b) => b.name), [
      'cubit',
      'datasource',
      'failure',
      'feature',
      'repository',
      'usecase',
    ]);
    expect(bundle.templates.keys, contains('agents-md-section.md'));
    // D-019: o stack estende agentes do core sem copiá-los.
    final implementer = bundle.agents.firstWhere(
      (a) => a.name == 'implementer',
    );
    expect(implementer.skills, ['result-failure', 'bloc-testing']);
    expect(implementer.tierVariants, hasLength(3));
    expect(implementer.body, contains('## Stack flutter-clean-cubit'));
    expect(implementer.layer, KitLayer.stack);
    final usecase = bundle.brick('usecase')!;
    final repository = usecase.vars.firstWhere((v) => v.name == 'repository');
    expect(repository.defaultValue, '{feature}');
    expect(usecase.vars.firstWhere((v) => v.name == 'name').required, isTrue);
    expect(bundle.brick('nope'), isNull);
  });

  group('extensão de agentes', () {
    test('acrescenta skills e corpo; repetida em várias camadas', () {
      final project = SampleProject()
        ..write(
          '.sdd/overrides/agents/judge.md',
          '---\nextend: true\nskills: [writing]\n---\nRegra extra.\n',
        )
        ..write('.sdd/overrides/agents/worker.md', '---\nextend: true\n---\n');
      final bundle = project.bundle();
      final judge = bundle.agents.first;
      expect(judge.skills, ['writing']);
      expect(judge.body, 'Revise.\n\nRegra extra.\n');
      expect(judge.readonly, isTrue);
      expect(judge.bashAllow, ['sdd check']);
      // Extensão vazia não altera o corpo nem duplica skills.
      final worker = bundle.agents.last;
      expect(worker.body, contains('Trabalhe'));
      expect(worker.skills, ['writing']);
    });

    test('erros: sem base, fora de agentes, campos não permitidos', () {
      final project = SampleProject()
        ..write('.sdd/overrides/agents/novo.md', '---\nextend: true\n---\n')
        ..write('.sdd/overrides/rules/domain.md', '---\nextend: true\n---\n')
        ..write(
          '.sdd/overrides/agents/judge.md',
          '---\nextend: true\ntier: fast\n---\n',
        );
      final issues = issuesOf(project).join('\n');
      expect(issues, contains('extend sem "novo" em camada anterior'));
      expect(issues, contains('extend só é suportado em agentes'));
      expect(
        issues,
        contains('extensão só aceita skills e corpo (remova tier)'),
      );
    });
  });

  test('bricks: validação', () {
    final project = SampleProject()
      ..write('.sdd/overrides/bricks/sem-yaml/__brick__/a.txt', 'x')
      ..write('.sdd/overrides/bricks/sem-dir/brick.yaml', 'name: sem-dir')
      ..write('.sdd/overrides/bricks/ruim/brick.yaml', 'name: [')
      ..write('.sdd/overrides/bricks/ruim/__brick__/a.txt', 'x')
      ..write('.sdd/overrides/bricks/outro/brick.yaml', 'name: x')
      ..write('.sdd/overrides/bricks/outro/__brick__/a.txt', 'x')
      ..write('.sdd/overrides/bricks/vars/brick.yaml', 'name: vars\nvars: [1]')
      ..write('.sdd/overrides/bricks/vars/__brick__/a.txt', 'x');
    final issues = issuesOf(project).join('\n');
    expect(issues, contains('sem-yaml: brick.yaml ausente'));
    expect(issues, contains('sem-dir: __brick__/ ausente'));
    expect(issues, contains('ruim/brick.yaml: YAML inválido'));
    expect(issues, contains('outro/brick.yaml: "name" deve ser "outro"'));
    expect(issues, contains('"vars" deve ser mapa'));
  });

  test('brick válido de override com vars simples e tipadas', () {
    final project = SampleProject()
      ..write(
        '.sdd/overrides/bricks/meu/brick.yaml',
        'name: meu\ndescription: d\nvars:\n  a: x\n'
            '  b: {type: boolean, default: false, description: B}\n',
      )
      ..write('.sdd/overrides/bricks/meu/__brick__/a.txt', 'x');
    final brick = project.bundle().brick('meu')!;
    expect(brick.layer, KitLayer.override);
    expect(brick.vars.first.type, 'string');
    expect(brick.vars.first.required, isTrue);
    expect(brick.vars.last.type, 'boolean');
    expect(brick.vars.last.defaultValue, false);
  });
}
