import 'package:file/file.dart';
import 'package:flutter_sdd/src/core/config/yaml_utils.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// O que o `init` precisa saber de um projeto Dart/Flutter.
class ProjectInfo {
  const ProjectInfo({
    required this.name,
    required this.isFlutter,
    required this.dependencies,
    required this.devDependencies,
    required this.existingPaths,
  });

  final String name;
  final bool isFlutter;
  final Set<String> dependencies;
  final Set<String> devDependencies;

  /// Subconjunto de `ProjectDetector.probedPaths` que existe no projeto.
  final Set<String> existingPaths;

  bool dependsOn(String package) =>
      dependencies.contains(package) || devDependencies.contains(package);
}

class ProjectDetectionException implements Exception {
  const ProjectDetectionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lê `pubspec.yaml` e caminhos conhecidos do projeto em `root`.
class ProjectDetector {
  const ProjectDetector(this.fs);

  final FileSystem fs;

  static const probedPaths = [
    'lib',
    'lib/features',
    'test',
    'analysis_options.yaml',
    '.git',
  ];

  ProjectInfo detect(String root) {
    final pubspec = fs.file(p.join(root, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      throw ProjectDetectionException(
        'pubspec.yaml não encontrado em $root (rode na raiz do app)',
      );
    }
    final Object? raw;
    try {
      raw = loadPlainYaml(pubspec.readAsStringSync());
    } on YamlException catch (e) {
      throw ProjectDetectionException('pubspec.yaml inválido: ${e.message}');
    }
    if (raw is! Map<String, Object?>) {
      throw const ProjectDetectionException('pubspec.yaml inválido');
    }
    Set<String> keys(Object? section) =>
        section is Map<String, Object?> ? section.keys.toSet() : <String>{};
    final deps = keys(raw['dependencies']);
    return ProjectInfo(
      name: raw['name'] as String? ?? p.basename(root),
      isFlutter: deps.contains('flutter'),
      dependencies: deps,
      devDependencies: keys(raw['dev_dependencies']),
      existingPaths: {
        for (final path in probedPaths)
          if (fs.typeSync(p.join(root, path)) != FileSystemEntityType.notFound)
            path,
      },
    );
  }
}
