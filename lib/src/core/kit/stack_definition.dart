import 'package:flutter_sdd/src/core/config/yaml_utils.dart';
import 'package:flutter_sdd/src/core/project/project_info.dart';

/// Sinal de detecção de um stack pack.
sealed class DetectionSignal {
  const DetectionSignal(this.score);

  final int score;

  bool matches(ProjectInfo project);

  String get label;
}

class DependencySignal extends DetectionSignal {
  const DependencySignal(this.package, super.score);

  final String package;

  @override
  bool matches(ProjectInfo project) => project.dependsOn(package);

  @override
  String get label => 'dependência $package';
}

class PathSignal extends DetectionSignal {
  const PathSignal(this.path, super.score);

  final String path;

  @override
  bool matches(ProjectInfo project) => project.existingPaths.contains(path);

  @override
  String get label => 'caminho $path';
}

/// Metadados de `kit/stacks/<nome>/stack.yaml`.
class StackDefinition {
  const StackDefinition({
    required this.name,
    required this.description,
    required this.configDefaults,
    required this.signals,
    required this.minScore,
    required this.expectedDependencies,
    this.gateRequirements = const {},
  });

  /// Faz o parse de um `stack.yaml`. Lança [FormatException] se inválido.
  factory StackDefinition.parse(String source) {
    final raw = loadPlainYaml(source);
    if (raw is! Map<String, Object?>) {
      throw const FormatException('stack.yaml: esperado mapa na raiz');
    }
    final name = raw['name'];
    if (name is! String || name.isEmpty) {
      throw const FormatException('stack.yaml: "name" obrigatório');
    }
    final detect = raw['detect'] as Map<String, Object?>? ?? const {};
    final signals = <DetectionSignal>[];
    for (final (i, item)
        in ((detect['signals'] as List<Object?>?) ?? const []).indexed) {
      if (item is! Map<String, Object?>) {
        throw FormatException('stack.yaml: detect.signals[$i] deve ser mapa');
      }
      final score = item['score'] as int? ?? 1;
      signals.add(switch (item) {
        {'dependency': final String p} => DependencySignal(p, score),
        {'path': final String p} => PathSignal(p, score),
        _ => throw FormatException(
          'stack.yaml: detect.signals[$i] precisa de "dependency" ou "path"',
        ),
      });
    }
    return StackDefinition(
      name: name,
      description: raw['description'] as String? ?? '',
      configDefaults:
          raw['config_defaults'] as Map<String, Object?>? ?? const {},
      signals: signals,
      minScore: detect['min_score'] as int? ?? 1,
      expectedDependencies: [
        ...((raw['expected_dependencies'] as List<Object?>?) ?? const [])
            .cast<String>(),
      ],
      gateRequirements: {
        for (final MapEntry(:key, :value)
            in ((raw['gate_requirements'] as Map<String, Object?>?) ??
                    const <String, Object?>{})
                .entries)
          key: '$value',
      },
    );
  }

  final String name;
  final String description;
  final Map<String, Object?> configDefaults;
  final List<DetectionSignal> signals;
  final int minScore;

  /// Dependências que o conteúdo do stack assume (avisar se ausentes).
  final List<String> expectedDependencies;

  /// Gate → dependência exigida no projeto para o gate entrar no config.
  final Map<String, String> gateRequirements;

  /// Pontuação de aderência do projeto a este stack.
  StackScore score(ProjectInfo project) {
    final matched = signals.where((s) => s.matches(project)).toList();
    return StackScore(
      this,
      matched.fold(0, (sum, s) => sum + s.score),
      matched,
    );
  }
}

class StackScore {
  const StackScore(this.stack, this.score, this.matched);

  final StackDefinition stack;
  final int score;
  final List<DetectionSignal> matched;

  bool get qualifies => score >= stack.minScore;
}
