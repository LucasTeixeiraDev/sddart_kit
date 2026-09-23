import 'package:file/file.dart';
import 'package:flutter_sdd/src/core/config/config_defaults.dart';
import 'package:flutter_sdd/src/core/config/config_parser.dart';
import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/config/yaml_utils.dart';
import 'package:flutter_sdd/src/core/config/yaml_writer.dart';
import 'package:flutter_sdd/src/core/kit/kit_locator.dart';
import 'package:flutter_sdd/src/core/kit/kit_lock.dart';
import 'package:flutter_sdd/src/core/kit/stack_definition.dart';
import 'package:flutter_sdd/src/core/project/project_info.dart';
import 'package:flutter_sdd/src/core/project/sdd_paths.dart';
import 'package:path/path.dart' as p;

/// Config proposto pelo `init` + observações da detecção.
class InitProposal {
  const InitProposal(this.config, this.notes);

  final Map<String, Object?> config;
  final List<String> notes;
}

/// Monta o config inicial a partir de core + stack + detecção.
InitProposal proposeConfig({
  required StackDefinition stack,
  required ProjectInfo project,
  required List<Target> targets,
  required bool Function(String relativePath) exists,
}) {
  final notes = <String>[];
  final merged = deepMerge(coreConfigDefaults, stack.configDefaults);

  final dod = {...merged['dod']! as Map<String, Object?>};
  final gates = [...(dod['gates']! as List<Object?>).cast<String>()];
  for (final MapEntry(key: gate, value: package)
      in stack.gateRequirements.entries) {
    if (gates.contains(gate) && !project.dependsOn(package)) {
      gates.remove(gate);
      notes.add('gate $gate desligado: dependência $package ausente');
    }
  }
  dod['gates'] = gates;

  if (!project.isFlutter) {
    notes.add('pubspec sem dependência flutter; comandos assumem Flutter');
  }
  for (final dep in stack.expectedDependencies) {
    if (!project.dependsOn(dep)) {
      notes.add('dependência $dep ausente (o stack ${stack.name} a assume)');
    }
  }
  final projectSection = merged['project']! as Map<String, Object?>;
  final featuresPath = projectSection['features_path']! as String;
  if (!exists(featuresPath)) {
    notes.add('$featuresPath não existe ainda (project.features_path)');
  }

  // Ordem estável e legível das seções.
  final config = <String, Object?>{
    'version': SddConfig.currentVersion,
    'kit': {'stack': stack.name},
    'targets': [for (final t in targets) t.name],
    'language': merged['language'],
    'project': projectSection,
    'commands': merged['commands'],
    'dod': dod,
    'execution': merged['execution'],
    'memory': merged['memory'],
    'models': merged['models'],
    'hooks': merged['hooks'],
  };
  return InitProposal(config, notes);
}

/// Resultado da escrita do `.sdd/`.
class InitResult {
  const InitResult(this.created, this.skipped);

  final List<String> created;

  /// Arquivos que já existiam e foram preservados.
  final List<String> skipped;
}

/// Escreve `.sdd/` no projeto. Nunca sobrescreve memória nem overrides.
InitResult writeSddDir({
  required FileSystem fs,
  required String root,
  required KitLocation kit,
  required StackDefinition stack,
  required Map<String, Object?> config,
  required String cliVersion,
}) {
  final paths = SddPaths(root);
  final configText =
      '# Config do sdd. Referência: README do flutter_sdd.\n'
      '${toYaml(config)}';
  // Garante que o que escrevemos é válido (lança ConfigException se não).
  parseConfig(configText, stackDefaults: stack.configDefaults);

  final created = <String>[];
  final skipped = <String>[];
  void write(String path, String content, {bool overwrite = false}) {
    final file = fs.file(path);
    if (file.existsSync() && !overwrite) {
      skipped.add(p.relative(path, from: root));
      return;
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    created.add(p.relative(path, from: root));
  }

  String template(String relative) => fs
      .file(p.join(kit.path, 'core', 'templates', relative))
      .readAsStringSync();

  write(paths.config, configText, overwrite: true);
  write(
    paths.kitLock,
    KitLock(
      sddVersion: cliVersion,
      stack: stack.name,
      kitHash: computeKitHash(fs, kit, stack.name),
    ).serialize(),
    overwrite: true,
  );
  write(paths.decisions, template('memory/decisions.md'));
  write(paths.learnings, template('memory/learnings.md'));
  write(p.join(paths.overrides, 'README.md'), template('overrides-readme.md'));
  return InitResult(created, skipped);
}
