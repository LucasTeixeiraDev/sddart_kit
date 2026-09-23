import 'package:flutter_sdd/src/core/config/config_parser.dart';
import 'package:flutter_sdd/src/core/config/model_resolver.dart';
import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:test/test.dart';

SddConfig configWith(String models, {String targets = '[claude, cursor]'}) =>
    parseConfig('''
kit: {stack: s}
targets: $targets
models:
$models
''').config;

void main() {
  test('claude usa alias do padrão', () {
    final c = configWith('  deep: opus\n  standard: sonnet\n  fast: haiku');
    final r = resolveModel(c, Tier.deep, Target.claude);
    expect(r.value, 'opus');
    expect(r.warning, isNull);
  });

  test('cursor sem override e padrão alias do Claude → inherit com aviso', () {
    final c = configWith('  deep: opus\n  standard: sonnet\n  fast: haiku');
    final r = resolveModel(c, Tier.deep, Target.cursor);
    expect(r.value, inheritModel);
    expect(r.warning, contains('models.deep'));
    expect(modelWarnings(c), hasLength(3));
  });

  test('cursor com override explícito usa o id', () {
    final c = configWith('''
  deep: {default: opus, cursor: claude-opus-5-5}
  standard: {default: sonnet, cursor: claude-sonnet-5}
  fast: {default: haiku, cursor: claude-sonnet-5}''');
    expect(resolveModel(c, Tier.deep, Target.cursor).value, 'claude-opus-5-5');
    expect(modelWarnings(c), isEmpty);
  });

  test('padrão que não é alias do Claude vale para o cursor', () {
    final c = configWith('''
  deep: claude-opus-5-5
  standard: {cursor: claude-sonnet-5}
  fast: {claude: haiku}''');
    expect(resolveModel(c, Tier.deep, Target.cursor).value, 'claude-opus-5-5');
    expect(resolveModel(c, Tier.standard, Target.claude).value, inheritModel);
    final fast = resolveModel(c, Tier.fast, Target.cursor);
    expect(fast.value, inheritModel);
    expect(fast.warning, contains('<modelo>'));
  });

  test('sem cursor nos targets, nenhum aviso', () {
    final c = configWith(
      '  deep: opus\n  standard: sonnet\n  fast: haiku',
      targets: '[claude]',
    );
    expect(modelWarnings(c), isEmpty);
  });
}
