import 'package:flutter_sdd/src/core/kit/kit_loader.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:flutter_sdd/src/core/scaffold/brick_paths.dart';
import 'package:flutter_sdd/src/core/scaffold/scaffold.dart';
import 'package:flutter_sdd/src/core/tasks/task_validator.dart';
import 'package:test/test.dart';

import '../../helpers/task_builders.dart';
import '../../helpers/test_env.dart';

void main() {
  test('recase', () {
    expect(recase('fetchWalletBalance', 'snakeCase'), 'fetch_wallet_balance');
    expect(recase('user_profile', 'pascalCase'), 'UserProfile');
    expect(recase('user profile', 'camelCase'), 'userProfile');
    expect(recase('UserProfile', 'paramCase'), 'user-profile');
    expect(recase('aB', 'lowerCase'), 'ab');
    expect(recase('ab', 'upperCase'), 'AB');
    expect(recase('', 'camelCase'), '');
    expect(() => recase('x', 'titleCase'), throwsFormatException);
  });

  test('renderBrickPath', () {
    expect(
      renderBrickPath('{{{features_path}}}/{{feature.snakeCase()}}/a.dart', {
        'features_path': 'lib/features',
        'feature': 'userProfile',
      }),
      'lib/features/user_profile/a.dart',
    );
    expect(() => renderBrickPath('{{x}}', {}), throwsFormatException);
  });

  test('camadas: todos os bricks do stack geram uma única camada', () {
    final fs = memoryFs();
    final bundle = KitLoader(fs).load(const [
      KitLayerDir(KitLayer.core, '$memKitPath/core'),
      KitLayerDir(KitLayer.stack, '$memKitPath/stacks/flutter-clean-cubit'),
    ]);
    final layers = {for (final b in bundle.bricks) b.name: brickLayers(fs, b)};
    expect(layers, {
      'cubit-test': {'test'},
      'failure': {'domain'},
      'feature': <String>{},
      'repository-contract': {'domain'},
      'repository-impl': {'data'},
      'repository-test': {'test'},
    });
    expect(templateLayer('x/presentation/a.dart'), 'presentation');
    expect(templateLayer('lib/core/a.dart'), 'other');
    expect(isStructural('a/b/.gitkeep'), isTrue);
  });

  group('planTaskBrick', () {
    final fs = memoryFs();
    final bundle = KitLoader(fs).load(const [
      KitLayerDir(KitLayer.core, '$memKitPath/core'),
      KitLayerDir(KitLayer.stack, '$memKitPath/stacks/flutter-clean-cubit'),
    ]);
    final config = testConfig('project: {features_path: lib/features}');

    BrickPlan plan(String brick, Map<String, String> vars) => planTaskBrick(
      fs: fs,
      bundle: bundle,
      config: config,
      packageName: 'app',
      task: task('T01', brick: brick, brickVars: vars),
    );

    test('caminhos com defaults e variáveis automáticas', () {
      expect(plan('repository-impl', {'feature': 'wallet'}).paths, [
        'lib/features/wallet/data/repositories/wallet_repository_impl.dart',
      ]);
      expect(
        plan('cubit-test', {'feature': 'wallet', 'name': 'balance'}).paths,
        ['test/features/wallet/presentation/cubit/balance_cubit_test.dart'],
      );
    });

    test('erros: brick inexistente e variável faltando', () {
      expect(plan('nope', {}).error, contains('não existe no kit'));
      expect(
        plan('cubit-test', {'feature': 'x'}).error,
        startsWith('faltam variáveis name'),
      );
    });
  });
}
