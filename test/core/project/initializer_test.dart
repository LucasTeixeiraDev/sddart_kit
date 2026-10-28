// Mensagens esperadas ficam inteiras para serem buscáveis.
// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter_sdd/src/core/config/config_issue.dart';
import 'package:flutter_sdd/src/core/config/config_parser.dart';
import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/kit/kit_locator.dart';
import 'package:flutter_sdd/src/core/kit/stack_definition.dart';
import 'package:flutter_sdd/src/core/project/initializer.dart';
import 'package:flutter_sdd/src/core/project/project_info.dart';
import 'package:test/test.dart';

import '../../helpers/test_env.dart';

void main() {
  final fs = memoryFs(fixture: 'app_cubit');
  const kit = KitLocation(memKitPath, KitSource.flag);
  final stack = StackDefinition.parse(
    fs.file(kit.stackFile('flutter-clean-cubit')).readAsStringSync(),
  );

  ProjectInfo info(Set<String> deps) => ProjectInfo(
    name: 'x',
    isFlutter: deps.contains('flutter'),
    dependencies: deps,
    devDependencies: const {},
    existingPaths: const {},
  );

  group('proposeConfig', () {
    test('desliga gates cujas dependências faltam e anota', () {
      final proposal = proposeConfig(
        stack: stack,
        project: info({'flutter', 'flutter_bloc', 'custom_lint'}),
        targets: [Target.claude],
        exists: (_) => true,
      );
      final gates = (proposal.config['dod']! as Map)['gates'] as List;
      expect(gates, contains('custom_lint'));
      expect(gates, isNot(contains('dart_code_linter')));
      expect(proposal.config['targets'], ['claude']);
      expect(proposal.config['kit'], {'stack': 'flutter-clean-cubit'});
      expect(
        proposal.notes,
        containsAll([
          'gate dart_code_linter desligado: dependência dart_code_linter ausente',
          'dependência bloc_test ausente (o stack flutter-clean-cubit a assume)',
        ]),
      );
    });

    test('avisa projeto sem flutter e features_path inexistente', () {
      final proposal = proposeConfig(
        stack: stack,
        project: info({}),
        targets: Target.values,
        exists: (_) => false,
      );
      expect(
        proposal.notes,
        containsAll([
          'pubspec sem dependência flutter; comandos assumem Flutter',
          'lib/features não existe ainda (project.features_path)',
        ]),
      );
    });
  });

  group('writeSddDir', () {
    Map<String, Object?> config() => proposeConfig(
      stack: stack,
      project: info({'flutter'}),
      targets: Target.values,
      exists: (_) => true,
    ).config;

    test('cria .sdd/ com config válido e preserva memória existente', () {
      fs.file('$memProjectPath/.sdd/memory/decisions.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('minhas decisões');
      final result = writeSddDir(
        fs: fs,
        root: memProjectPath,
        kit: kit,
        stack: stack,
        config: config(),
        cliVersion: '0.1.0',
      );
      expect(
        result.created,
        containsAll([
          '.sdd/config.yaml',
          '.sdd/kit.lock',
          '.sdd/memory/learnings.md',
          '.sdd/overrides/README.md',
        ]),
      );
      expect(result.skipped, ['.sdd/memory/decisions.md']);
      expect(
        fs.file('$memProjectPath/.sdd/memory/decisions.md').readAsStringSync(),
        'minhas decisões',
      );
      final text = fs
          .file('$memProjectPath/.sdd/config.yaml')
          .readAsStringSync();
      final parsed = parseConfig(text).config;
      expect(parsed.stack, 'flutter-clean-cubit');
      expect(parsed.project.errorHandling, ErrorHandling.result);
    });

    test('recusa config inválido', () {
      expect(
        () => writeSddDir(
          fs: fs,
          root: memProjectPath,
          kit: kit,
          stack: stack,
          config: {...config(), 'targets': <String>[]},
          cliVersion: '0.1.0',
        ),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
