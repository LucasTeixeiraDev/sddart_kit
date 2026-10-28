import 'package:flutter_sdd/src/core/kit/kit_locator.dart';
import 'package:flutter_sdd/src/core/project/project_loader.dart';
import 'package:test/test.dart';

import '../../helpers/sample_project.dart';
import '../../helpers/test_env.dart';

void main() {
  late SampleProject p;
  setUp(() => p = SampleProject());

  Future<LoadedProject> load({String? kitPath = memKitPath}) => loadProject(
    fs: p.fs,
    root: memProjectPath,
    locator: KitLocator(
      fs: p.fs,
      environment: const {},
      packageRoot: () async => null,
    ),
    kitPath: kitPath,
  );

  Matcher failsWith(String text) => throwsA(
    isA<ProjectLoadException>().having((e) => '$e', 'msg', contains(text)),
  );

  test('carrega config, stack e camadas', () async {
    final project = await load();
    expect(project.stack.name, 'sample');
    expect(project.layers.map((l) => l.path).last, endsWith('.sdd/overrides'));
    expect(project.currentLock(p.fs, '1.0.0').stack, 'sample');
  });

  test('erros viram ProjectLoadException', () async {
    await expectLater(load(kitPath: null), failsWith('kit não encontrado'));

    p.writeConfig('targets: [vim]\n');
    await expectLater(load(), failsWith('config inválido'));

    p.write('.sdd/config.yaml', 'kit: {stack: outro}\n');
    await expectLater(load(), failsWith('"outro" não existe'));

    p.write('.sdd/config.yaml', 'version: 1\n');
    await expectLater(load(), failsWith('(kit.stack ausente)'));

    p
      ..writeConfig('')
      ..fs
          .file('$memKitPath/stacks/sample/stack.yaml')
          .writeAsStringSync('- x');
    await expectLater(load(), failsWith('stack.yaml'));

    p.fs.file('$memProjectPath/.sdd/config.yaml').deleteSync();
    await expectLater(load(), failsWith('rode sdd init'));
  });
}
