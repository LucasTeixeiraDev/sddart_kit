import 'package:file/memory.dart';
import 'package:flutter_sdd/src/core/config/config_parser.dart';
import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/kit/kit_loader.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:flutter_sdd/src/core/kit/stack_definition.dart';

import 'test_env.dart';

/// Projeto em memória com o kit `kit_sample` e config ajustável.
class SampleProject {
  SampleProject({String extraConfig = ''})
    : fs = memoryFs(kitFixture: 'kit_sample') {
    writeConfig(extraConfig);
  }

  final MemoryFileSystem fs;

  void writeConfig(String extra) {
    fs.file('$memProjectPath/.sdd/config.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('kit: {stack: sample}\n$extra');
  }

  StackDefinition get stack => StackDefinition.parse(
    fs.file('$memKitPath/stacks/sample/stack.yaml').readAsStringSync(),
  );

  SddConfig get config => parseConfig(
    fs.file('$memProjectPath/.sdd/config.yaml').readAsStringSync(),
    stackDefaults: stack.configDefaults,
  ).config;

  List<KitLayerDir> get layers => const [
    KitLayerDir(KitLayer.core, '$memKitPath/core'),
    KitLayerDir(KitLayer.stack, '$memKitPath/stacks/sample'),
    KitLayerDir(KitLayer.override, '$memProjectPath/.sdd/overrides'),
  ];

  KitBundle bundle() => KitLoader(fs).load(layers);

  void write(String relative, String content) {
    fs.file('$memProjectPath/$relative')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  String read(String relative) =>
      fs.file('$memProjectPath/$relative').readAsStringSync();

  bool exists(String relative) =>
      fs.file('$memProjectPath/$relative').existsSync();
}
