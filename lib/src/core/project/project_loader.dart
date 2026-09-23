import 'package:file/file.dart';
import 'package:flutter_sdd/src/core/config/config_issue.dart';
import 'package:flutter_sdd/src/core/config/config_parser.dart';
import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/kit/kit_loader.dart';
import 'package:flutter_sdd/src/core/kit/kit_locator.dart';
import 'package:flutter_sdd/src/core/kit/kit_lock.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:flutter_sdd/src/core/kit/stack_definition.dart';
import 'package:flutter_sdd/src/core/project/sdd_paths.dart';
import 'package:flutter_sdd/src/core/sync/sync_planner.dart';
import 'package:path/path.dart' as p;

/// Projeto com `.sdd/` carregado e validado.
class LoadedProject {
  const LoadedProject({
    required this.root,
    required this.paths,
    required this.kit,
    required this.stack,
    required this.config,
    required this.configWarnings,
  });

  final String root;
  final SddPaths paths;
  final KitLocation kit;
  final StackDefinition stack;
  final SddConfig config;
  final List<ConfigIssue> configWarnings;

  /// Camadas na ordem de precedência crescente.
  List<KitLayerDir> get layers => [
    KitLayerDir(KitLayer.core, p.join(kit.path, 'core')),
    KitLayerDir(KitLayer.stack, kit.stackPath(stack.name)),
    KitLayerDir(KitLayer.override, paths.overrides),
  ];

  KitBundle loadBundle(FileSystem fs) => KitLoader(fs).load(layers);

  KitLock currentLock(FileSystem fs, String version) => KitLock(
    sddVersion: version,
    stack: stack.name,
    kitHash: computeKitHash(fs, kit, stack.name),
  );

  /// Planeja o sync (lança [KitException] se o kit/overrides forem inválidos).
  SyncPlan planSync(FileSystem fs, String version) =>
      SyncPlanner(fs: fs, root: root, version: version).plan(
        bundle: loadBundle(fs),
        config: config,
        lock: currentLock(fs, version),
      );
}

/// Falha ao carregar o projeto (erro de uso/config → exit 2).
class ProjectLoadException implements Exception {
  const ProjectLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<LoadedProject> loadProject({
  required FileSystem fs,
  required String root,
  required KitLocator locator,
  String? kitPath,
}) async {
  final paths = SddPaths(root);
  final configFile = fs.file(paths.config);
  if (!configFile.existsSync()) {
    throw const ProjectLoadException('.sdd/config.yaml ausente; rode sdd init');
  }
  final KitLocation kit;
  try {
    kit = await locator.locate(kitPath: kitPath);
  } on KitNotFoundException catch (e) {
    throw ProjectLoadException(e.message);
  }
  final source = configFile.readAsStringSync();
  final stackName = peekStack(source);
  final stackFile = stackName == null
      ? null
      : fs.file(kit.stackFile(stackName));
  if (stackFile == null || !stackFile.existsSync()) {
    throw ProjectLoadException(
      'stack "${stackName ?? '(kit.stack ausente)'}" não existe no kit',
    );
  }
  try {
    final stack = StackDefinition.parse(stackFile.readAsStringSync());
    final result = parseConfig(source, stackDefaults: stack.configDefaults);
    return LoadedProject(
      root: root,
      paths: paths,
      kit: kit,
      stack: stack,
      config: result.config,
      configWarnings: result.warnings,
    );
  } on FormatException catch (e) {
    throw ProjectLoadException(e.message);
  } on ConfigException catch (e) {
    throw ProjectLoadException('config inválido:\n$e');
  }
}
