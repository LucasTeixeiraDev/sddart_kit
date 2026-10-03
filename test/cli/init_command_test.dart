import 'dart:convert';

import 'package:flutter_sdd/flutter_sdd.dart';
import 'package:flutter_sdd/src/core/config/config_parser.dart';
import 'package:flutter_sdd/src/core/kit/kit_lock.dart';
import 'package:test/test.dart';

import '../helpers/test_env.dart';

void main() {
  group('sdd init', () {
    test('--yes em app_cubit detecta stack e cria .sdd/', () async {
      final cli = CliHarness(fixture: 'app_cubit');
      expect(await cli.run(['init', '--yes']), ExitCodes.ok);
      expect(cli.out.toString(), contains('stack flutter-clean-cubit'));
      expect(cli.out.toString(), contains('próximo passo: sdd new'));
      expect(cli.exists('AGENTS.md'), isTrue);
      expect(cli.exists('.claude/agents/sdd-reviewer.md'), isTrue);

      final config = parseConfig(cli.read('.sdd/config.yaml')).config;
      expect(config.stack, 'flutter-clean-cubit');
      expect(config.project.featuresPath, 'lib/features');
      // custom_lint está no pubspec; dart_code_linter não.
      expect(config.dod.gates, contains('custom_lint'));
      expect(config.dod.gates, isNot(contains('dart_code_linter')));

      final lock = KitLock.parse(cli.read('.sdd/kit.lock'));
      expect(lock.sddVersion, sddVersion);
      expect(cli.exists('.sdd/memory/decisions.md'), isTrue);
      expect(cli.exists('.sdd/memory/learnings.md'), isTrue);
      expect(cli.exists('.sdd/overrides/README.md'), isTrue);
    });

    test('segunda execução exige --force e preserva memória', () async {
      final cli = CliHarness(fixture: 'app_cubit');
      await cli.run(['init', '--yes']);
      cli.fs
          .file('$memProjectPath/.sdd/memory/learnings.md')
          .writeAsStringSync('lição');

      expect(await cli.run(['init', '--yes']), ExitCodes.usage);
      expect(cli.err.toString(), contains('já existe'));

      expect(await cli.run(['init', '--yes', '--force']), ExitCodes.ok);
      expect(cli.read('.sdd/memory/learnings.md'), 'lição');
      expect(
        cli.out.toString(),
        contains('mantido   .sdd/memory/learnings.md'),
      );
    });

    test('--json produz documento estável', () async {
      final cli = CliHarness(fixture: 'app_cubit');
      expect(await cli.run(['--json', 'init']), ExitCodes.ok);
      final doc = jsonDecode(cli.out.toString()) as Map<String, Object?>;
      expect(doc['stack'], 'flutter-clean-cubit');
      expect(doc['targets'], ['claude', 'cursor']);
      expect(doc['created'], contains('.sdd/config.yaml'));
      expect(doc['notes'], isA<List<Object?>>());
    });

    test('sem stack detectado e sem --stack falha com uso', () async {
      final cli = CliHarness(fixture: 'app_plain_dart');
      expect(await cli.run(['init', '--yes']), ExitCodes.usage);
      expect(cli.err.toString(), contains('use --stack'));
    });

    test('--stack força o stack e registra avisos', () async {
      final cli = CliHarness(fixture: 'app_no_features');
      expect(
        await cli.run(['init', '--yes', '--stack', 'flutter-clean-cubit']),
        ExitCodes.ok,
      );
      expect(cli.err.toString(), contains('lib/features não existe ainda'));
      expect(cli.err.toString(), contains('dependência flutter_bloc ausente'));
    });

    test('--stack inexistente', () async {
      final cli = CliHarness(fixture: 'app_cubit');
      expect(await cli.run(['init', '--stack', 'x', '-y']), ExitCodes.usage);
      expect(cli.err.toString(), contains('disponíveis: flutter-clean-cubit'));
    });

    test('modo interativo pergunta stack e targets', () async {
      final prompter = ScriptedPrompter(targets: ['claude']);
      final cli = CliHarness(
        fixture: 'app_plain_dart',
        prompter: prompter,
        interactive: true,
      );
      expect(await cli.run(['init']), ExitCodes.ok);
      expect(prompter.asked, hasLength(3));
      expect(prompter.asked.last, contains('dart format'));
      final config = parseConfig(cli.read('.sdd/config.yaml')).config;
      expect(config.targets.map((t) => t.name), ['claude']);
    });

    test('interativo com format-on-edit gera o hook', () async {
      final cli = CliHarness(
        fixture: 'app_cubit',
        prompter: ScriptedPrompter(confirmAnswer: true),
        interactive: true,
      );
      expect(await cli.run(['init']), ExitCodes.ok);
      final config = parseConfig(cli.read('.sdd/config.yaml')).config;
      expect(config.hooks.formatOnEdit, isTrue);
      expect(cli.read('.claude/settings.json'), contains('sdd hook format'));
    });

    test('interativo sem nenhum target escolhido', () async {
      final cli = CliHarness(
        fixture: 'app_cubit',
        prompter: ScriptedPrompter(targets: []),
        interactive: true,
      );
      expect(await cli.run(['init']), ExitCodes.usage);
    });

    test('sem pubspec ou sem kit', () async {
      final noPubspec = CliHarness();
      expect(await noPubspec.run(['init', '-y']), ExitCodes.usage);
      expect(noPubspec.err.toString(), contains('pubspec.yaml não encontrado'));

      final noKit = CliHarness(fixture: 'app_cubit', environment: {});
      expect(await noKit.run(['init', '-y']), ExitCodes.usage);
      expect(noKit.err.toString(), contains('kit não encontrado'));
    });

    test('kit resolvido pela raiz do pacote', () async {
      final cli = CliHarness(
        fixture: 'app_cubit',
        environment: {},
        packageRoot: Uri.parse('file:///sdd/'),
      );
      expect(await cli.run(['init', '-y']), ExitCodes.ok);
    });
  });
}
