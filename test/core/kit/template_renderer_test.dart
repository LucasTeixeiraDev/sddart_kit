import 'dart:convert';

import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:flutter_sdd/src/core/kit/template_renderer.dart';
import 'package:test/test.dart';

import '../../helpers/sample_project.dart';

void main() {
  test('renderTemplate substitui e reporta faltantes', () {
    final missing = <String>[];
    final out = renderTemplate('a {{sdd:x}} b {{sdd:y.z}} {{outro}}', {
      'x': '1',
    }, missing: missing);
    expect(out, 'a 1 b {{sdd:y.z}} {{outro}}');
    expect(missing, ['y.z']);
  });

  test('variáveis e renderização do bundle', () {
    final project = SampleProject();
    final bundle = project.bundle();
    final vars = buildRenderVars(project.config, bundle, sddVersion: '9.9.9');
    expect(vars['version'], '9.9.9');
    expect(vars['commands.format'], contains('dart format'));
    expect(vars['commands_list'], '- `/sdd-go <spec>`: Roda o fluxo.');
    expect(vars['agents_list'], contains('`sdd-worker-<fast|deep>`'));
    expect(vars['dod_checklist'], '- (nenhum)');
    expect(vars['gates_list'], contains('`coverage` (calculado pelo sdd)'));

    final rendered = renderBundle(bundle, vars);
    expect(rendered.agents.last.body, contains('Trabalhe em lib.'));
    final guide = rendered.skills.single.files.first;
    expect(utf8.decode(guide.bytes), contains('Guia da stack sample.'));
    // Arquivos não-markdown não são renderizados.
    expect(rendered.skills.single.files.last.relativePath, 'run.sh');
  });

  test('variável desconhecida no kit é erro', () {
    final project = SampleProject()
      ..write(
        '.sdd/overrides/rules/r.md',
        '---\ndescription: d\nalways: true\n---\n{{sdd:nope}}\n',
      );
    final bundle = project.bundle();
    expect(
      () => renderBundle(bundle, {}),
      throwsA(
        isA<KitException>().having(
          (e) => e.issues.join(),
          'issues',
          contains('{{sdd:nope}} desconhecida'),
        ),
      ),
    );
  });
}
