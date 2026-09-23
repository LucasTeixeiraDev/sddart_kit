import 'dart:io';

import 'package:flutter_sdd/src/core/config/config_parser.dart';
import 'package:flutter_sdd/src/core/kit/stack_definition.dart';
import 'package:flutter_sdd/src/core/project/project_info.dart';
import 'package:test/test.dart';

ProjectInfo project({
  Set<String> deps = const {},
  Set<String> paths = const {},
}) => ProjectInfo(
  name: 'x',
  isFlutter: deps.contains('flutter'),
  dependencies: deps,
  devDependencies: const {},
  existingPaths: paths,
);

void main() {
  final real = StackDefinition.parse(
    File('kit/stacks/flutter-clean-cubit/stack.yaml').readAsStringSync(),
  );

  test('stack.yaml real do flutter-clean-cubit', () {
    expect(real.name, 'flutter-clean-cubit');
    expect(real.expectedDependencies, contains('bloc_test'));
    expect(real.gateRequirements['custom_lint'], 'custom_lint');
    // Os defaults do stack precisam formar um config válido.
    final c = parseConfig(
      'kit: {stack: flutter-clean-cubit}',
      stackDefaults: real.configDefaults,
    ).config;
    expect(c.dod.gates, contains('dart_code_linter'));
    expect(c.dod.checklist, hasLength(3));
  });

  test('pontuação e qualificação', () {
    final full = real.score(
      project(deps: {'flutter', 'flutter_bloc'}, paths: {'lib/features'}),
    );
    expect(full.score, 4);
    expect(full.qualifies, isTrue);
    expect(full.matched.map((m) => m.label), contains('caminho lib/features'));

    final weak = real.score(project(deps: {'flutter'}));
    expect(weak.score, 1);
    expect(weak.qualifies, isFalse);
  });

  test('parse valida estrutura', () {
    expect(() => StackDefinition.parse('- a'), throwsFormatException);
    expect(
      () => StackDefinition.parse('description: x'),
      throwsFormatException,
    );
    expect(
      () => StackDefinition.parse('name: a\ndetect:\n  signals: [1]'),
      throwsFormatException,
    );
    expect(
      () => StackDefinition.parse('name: a\ndetect:\n  signals: [{x: 1}]'),
      throwsFormatException,
    );
    final bare = StackDefinition.parse('name: a');
    expect(bare.minScore, 1);
    expect(bare.signals, isEmpty);
    expect(bare.configDefaults, isEmpty);
  });
}
