import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:flutter_sdd/src/core/scaffold/scaffold.dart';
import 'package:test/test.dart';

import '../../helpers/task_builders.dart';

const brick = KitBrick(
  name: 'usecase',
  description: 'd',
  path: '/b',
  layer: KitLayer.stack,
  vars: [
    BrickVar(name: 'feature', description: 'Nome da feature'),
    BrickVar(name: 'name'),
    BrickVar(name: 'repository', defaultValue: '{feature}'),
    BrickVar(name: 'flag', type: 'boolean', defaultValue: false),
    BrickVar(name: 'count', type: 'number', defaultValue: 1),
  ],
);

Matcher fails(String text) => throwsA(
  isA<ScaffoldException>().having((e) => '$e', 'msg', contains(text)),
);

void main() {
  test('parseVarArgs', () {
    expect(parseVarArgs(['a=1', 'b = x=y']), {'a': '1', 'b': 'x=y'});
    expect(() => parseVarArgs(['semigual']), fails('chave=valor'));
    expect(() => parseVarArgs(['=x']), fails('chave=valor'));
  });

  test('precedência, referências e tipos', () {
    final vars = resolveBrickVars(
      brick,
      packageName: 'app',
      configVars: {
        'result_import': 'package:{package}/core/result.dart',
        'name': 'do-config',
      },
      cliVars: {
        'feature': 'auth',
        'name': 'login',
        'flag': 'true',
        'count': '3',
      },
    );
    expect(vars['package'], 'app');
    expect(vars['result_import'], 'package:app/core/result.dart');
    expect(vars['repository'], 'auth');
    expect(vars['name'], 'login');
    expect(vars['flag'], isTrue);
    expect(vars['count'], 3);
    // Referência desconhecida fica literal; auto-referência não entra em laço.
    final odd = resolveBrickVars(
      brick,
      packageName: 'app',
      cliVars: {'feature': '{nada}', 'name': '{name}'},
    );
    expect(odd['feature'], '{nada}');
    expect(odd['name'], '{name}');
  });

  test('variáveis faltando e tipos inválidos', () {
    expect(
      () => resolveBrickVars(brick, packageName: 'app'),
      fails('faltam variáveis feature (Nome da feature), name'),
    );
    expect(
      () => resolveBrickVars(
        brick,
        packageName: 'app',
        cliVars: {'feature': 'a', 'name': 'b', 'flag': 'talvez'},
      ),
      fails('flag: esperado true/false'),
    );
    expect(
      () => resolveBrickVars(
        brick,
        packageName: 'app',
        cliVars: {'feature': 'a', 'name': 'b', 'count': 'x'},
      ),
      fails('count: esperado número'),
    );
  });

  test('outsideOwns', () {
    expect(outsideOwns(['lib/T01.dart', 'lib/x.dart'], task('T01')), [
      'lib/x.dart',
    ]);
  });
}
