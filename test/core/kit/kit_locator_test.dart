import 'package:file/memory.dart';
import 'package:flutter_sdd/src/core/kit/kit_locator.dart';
import 'package:test/test.dart';

import '../../helpers/test_env.dart';

void main() {
  late MemoryFileSystem fs;

  setUp(() {
    fs = memoryFs();
    // Um segundo kit válido para diferenciar as origens.
    fs.directory('/other/kit/core').createSync(recursive: true);
    fs.directory('/other/kit/stacks').createSync(recursive: true);
    fs.directory('/pkg/kit').createSync(recursive: true);
  });

  KitLocator locator({Map<String, String> env = const {}, Uri? root}) =>
      KitLocator(fs: fs, environment: env, packageRoot: () async => root);

  test('--kit-path tem precedência sobre env e pacote', () async {
    final kit = await locator(
      env: {'SDD_KIT_PATH': '/other/kit'},
      root: Uri.parse('file:///sdd/'),
    ).locate(kitPath: memKitPath);
    expect(kit.path, memKitPath);
    expect(kit.source, KitSource.flag);
  });

  test('SDD_KIT_PATH tem precedência sobre o pacote', () async {
    final kit = await locator(
      env: {'SDD_KIT_PATH': '/other/kit'},
      root: Uri.parse('file:///sdd/'),
    ).locate();
    expect(kit.path, '/other/kit');
    expect(kit.source, KitSource.env);
  });

  test('raiz do pacote + kit/', () async {
    final kit = await locator(root: Uri.parse('file:///sdd/')).locate();
    expect(kit.path, memKitPath);
    expect(kit.source, KitSource.package);
    expect(kit.stackFile('x'), '/sdd/kit/stacks/x/stack.yaml');
  });

  test('env vazia é ignorada', () async {
    final kit = await locator(
      env: {'SDD_KIT_PATH': ''},
      root: Uri.parse('file:///sdd/'),
    ).locate();
    expect(kit.source, KitSource.package);
  });

  test('sem pacote resolvível (AOT) orienta a usar --kit-path', () {
    expect(
      locator().locate(),
      throwsA(
        isA<KitNotFoundException>().having(
          (e) => e.message,
          'message',
          contains('SDD_KIT_PATH'),
        ),
      ),
    );
  });

  test('kit sem core/ e stacks/ é inválido', () {
    expect(
      locator(root: Uri.parse('file:///pkg/')).locate(),
      throwsA(
        isA<KitNotFoundException>().having(
          (e) => '$e',
          'toString',
          contains('esperado core/ e stacks/'),
        ),
      ),
    );
  });

  test('lista stacks com stack.yaml', () async {
    fs.directory('$memKitPath/stacks/sem-yaml').createSync();
    final l = locator();
    final kit = await l.locate(kitPath: memKitPath);
    expect(l.stacks(kit), ['flutter-clean-cubit']);
  });
}
