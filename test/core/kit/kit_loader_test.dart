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
            'bash_allow: [x]\nskills: [nope]\ntier_variants: [x]\n---\n',
      )
      ..write('.sdd/overrides/agents/Bad_Name.md', '---\n---\n')
      ..write('.sdd/overrides/agents/named.md', '---\nname: other\n---\n')
      ..write('.sdd/overrides/agents/ro.md', '---\nreadonly: sim\n---\n')
      ..write('.sdd/overrides/agents/notools.md', '---\ntools: read\n---\n');
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
    expect(bundle.agents, hasLength(6));
    expect(bundle.commands, hasLength(8));
    expect(bundle.skills, hasLength(5));
    expect(bundle.templates.keys, contains('agents-md-section.md'));
  });
}
