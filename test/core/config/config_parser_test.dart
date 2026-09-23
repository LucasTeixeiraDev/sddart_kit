// Mensagens esperadas ficam inteiras para serem buscáveis.
// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter_sdd/src/core/config/config_issue.dart';
import 'package:flutter_sdd/src/core/config/config_parser.dart';
import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:test/test.dart';

const minimal = '''
kit:
  stack: flutter-clean-cubit
''';

List<String> errorsOf(String source, {Map<String, Object?>? stack}) {
  try {
    parseConfig(source, stackDefaults: stack ?? const {});
  } on ConfigException catch (e) {
    return [for (final i in e.issues) '$i'];
  }
  fail('esperava ConfigException');
}

void main() {
  group('parseConfig', () {
    test('config mínimo recebe defaults do core', () {
      final c = parseConfig(minimal).config;
      expect(c.version, 1);
      expect(c.stack, 'flutter-clean-cubit');
      expect(c.targets, [Target.claude, Target.cursor]);
      expect(c.language, 'pt-BR');
      expect(c.project.testPath, 'test');
      expect(c.project.errorHandling, ErrorHandling.exceptions);
      expect(c.commands['analyze'], contains('--format=machine'));
      expect(c.dod.gates, contains('traceability'));
      expect(c.dod.coverage.min, 80);
      expect(c.execution.maxFixAttempts, 2);
      expect(c.execution.escalateTo, Tier.deep);
      expect(c.learningsWarnAfter, 15);
      expect(c.models[Tier.deep]!.forTarget(Target.claude), 'opus');
      expect(c.hooks.formatOnEdit, isFalse);
    });

    test('config completo do brief é aceito', () {
      const source = r'''
version: 1
kit:
  stack: flutter-clean-cubit
targets: [claude]
language: pt-BR
project:
  features_path: lib/features
  test_path: test
  state_management: cubit
  error_handling: result
  generated_globs: ["**/*.g.dart"]
commands:
  format: dart format --set-exit-if-changed {files}
  analyze: flutter analyze --fatal-infos {files}
  test: flutter test {files}
  test_all: flutter test --coverage
  codegen: dart run build_runner build -d
dod:
  gates: [format, analyze, test, coverage, traceability]
  coverage:
    min: 80
    paths: ["lib/features/**/domain/**"]
  traceability:
    ac_pattern: "AC-\\d{2,}"
    test_tag_pattern: "\\[(AC-\\d{2,})\\]"
  checklist:
    - Nenhuma exception atravessa a fronteira do repository
execution:
  max_fix_attempts: 3
  escalate_to: deep
memory:
  learnings_warn_after: 10
models:
  deep: opus
  standard: sonnet
  fast: { default: haiku, cursor: claude-sonnet-5 }
''';
      final result = parseConfig(source);
      final c = result.config;
      expect(result.warnings, isEmpty);
      expect(c.targets, [Target.claude]);
      expect(c.project.errorHandling, ErrorHandling.result);
      expect(c.dod.traceability.acPattern.hasMatch('AC-02'), isTrue);
      expect(
        c.dod.traceability.testTagPattern
            .firstMatch('[AC-05] retorna Err')!
            .group(1),
        'AC-05',
      );
      expect(c.dod.checklist, hasLength(1));
      expect(c.execution.maxFixAttempts, 3);
      final fast = c.models[Tier.fast]!;
      expect(fast.forTarget(Target.claude), 'haiku');
      expect(fast.forTarget(Target.cursor), 'claude-sonnet-5');
      expect(fast.hasExplicit(Target.cursor), isTrue);
    });

    test('camadas: stack sobrescreve core, documento sobrescreve stack', () {
      final c = parseConfig(
        '$minimal\nproject:\n  test_path: spec\n',
        stackDefaults: {
          'project': {'features_path': 'lib/features', 'test_path': 'x'},
          'dod': {
            'gates': ['format'],
          },
        },
      ).config;
      expect(c.project.featuresPath, 'lib/features');
      expect(c.project.testPath, 'spec');
      expect(c.dod.gates, ['format']);
    });

    test('erro aponta caminho do campo e tipo esperado', () {
      final errors = errorsOf('$minimal\ncommands:\n  test: [a, b]\n');
      expect(
        errors,
        contains(
          'commands.test: esperado string não vazia, '
          'recebido lista',
        ),
      );
    });

    test('reporta todos os erros de uma vez', () {
      final errors = errorsOf('''
version: 2
targets: [claude, vim, claude]
execution:
  max_fix_attempts: -1
  escalate_to: huge
dod:
  coverage:
    min: 150
''');
      expect(
        errors,
        containsAll([
          'version: versão 2 não suportada (esperado 1)',
          'kit.stack: obrigatório (string)',
          'targets: valor "vim" inválido (use claude, cursor)',
          'targets: "claude" duplicado',
          'execution.max_fix_attempts: deve ser >= 0, recebido -1',
          'execution.escalate_to: valor "huge" inválido (use deep, standard, fast)',
          'dod.coverage.min: deve estar entre 0 e 100, recebido 150',
        ]),
      );
    });

    test('gate sem comando e coverage sem test_all', () {
      final errors = errorsOf(
        '$minimal\ndod:\n  gates: [format, custom_lint, coverage]\n',
        stack: {
          'commands': {'format': 'dart format {files}'},
        },
      );
      expect(
        errors,
        contains(
          'dod.gates: gate "custom_lint" não tem comando em '
          'commands.custom_lint',
        ),
      );
      // test_all vem do core, então coverage é válido aqui.
      expect(errors.where((e) => e.contains('coverage')), isEmpty);
    });

    test('regex inválida e test_tag_pattern sem grupo', () {
      final errors = errorsOf(r'''
kit: {stack: s}
dod:
  traceability:
    ac_pattern: "AC-("
    test_tag_pattern: "AC-\\d+"
''');
      expect(
        errors.any(
          (e) => e.startsWith(
            'dod.traceability.ac_pattern: '
            'regex inválida',
          ),
        ),
        isTrue,
      );
      expect(
        errors,
        contains(
          'dod.traceability.test_tag_pattern: deve ter um grupo de '
          'captura com o ID do AC',
        ),
      );
    });

    test('models: formatos inválidos', () {
      final errors = errorsOf('''
kit: {stack: s}
models:
  deep: 3
  standard: {default: sonnet, vscode: x}
  fast: {cursor: 5}
''');
      expect(
        errors,
        containsAll([
          'models.deep: esperado string ou mapa {default, claude, cursor}, recebido inteiro',
          'models.standard.vscode: chave inválida (use default, claude, cursor)',
          'models.fast.cursor: esperado string, recebido inteiro',
        ]),
      );
    });

    test('chaves desconhecidas e idioma geram avisos, não erros', () {
      final result = parseConfig('''
$minimal
language: en
extra: 1
project:
  typo_path: x
''');
      expect(
        result.warnings.map((w) => '$w'),
        containsAll([
          'extra: chave desconhecida (ignorada)',
          'project.typo_path: chave desconhecida (ignorada)',
          'language: apenas pt-BR é suportado; valor ignorado',
        ]),
      );
      expect(result.warnings.every((w) => w.isWarning), isTrue);
    });

    test('YAML inválido e raiz não-mapa', () {
      expect(errorsOf('kit: [').single, startsWith('(arquivo): YAML inválido'));
      expect(
        errorsOf('- a\n- b').single,
        '(raiz): esperado mapa, recebido lista',
      );
    });

    test('tipos errados em listas, booleanos e strings vazias', () {
      final errors = errorsOf('''
kit: {stack: ""}
targets: []
project:
  generated_globs: [1]
hooks:
  format_on_edit: sim
''');
      expect(
        errors,
        containsAll([
          'kit.stack: não pode ser vazio',
          'targets: não pode ser vazia',
          'project.generated_globs: esperado lista de strings',
          'hooks.format_on_edit: esperado booleano, recebido string',
        ]),
      );
    });
  });

  group('peekStack', () {
    test('lê kit.stack ou retorna null', () {
      expect(peekStack(minimal), 'flutter-clean-cubit');
      expect(peekStack('version: 1'), isNull);
      expect(peekStack('kit: ['), isNull);
      expect(peekStack('- a'), isNull);
    });
  });
}
