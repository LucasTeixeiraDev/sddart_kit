import 'package:path/path.dart' as p;

/// Caminhos do `.sdd/` de um projeto.
class SddPaths {
  const SddPaths(this.root);

  final String root;

  String get dir => p.join(root, '.sdd');
  String get config => p.join(dir, 'config.yaml');
  String get kitLock => p.join(dir, 'kit.lock');
  String get overrides => p.join(dir, 'overrides');
  String get memory => p.join(dir, 'memory');
  String get decisions => p.join(memory, 'decisions.md');
  String get learnings => p.join(memory, 'learnings.md');
}
