import 'dart:io';

import 'package:flutter_sdd/src/core/gates/parsers/analyze_parser.dart';
import 'package:flutter_sdd/src/core/gates/parsers/format_parser.dart';
import 'package:flutter_sdd/src/core/gates/parsers/generic_parser.dart';
import 'package:flutter_sdd/src/core/gates/parsers/paths.dart';
import 'package:flutter_sdd/src/core/gates/parsers/test_json_parser.dart';
import 'package:test/test.dart';

const root = '/proj/app';

/// Saídas reais capturadas do toolchain (Dart 3.13 / Flutter 3.47).
String output(String name) => File(
  'test/fixtures/outputs/$name.txt',
).readAsStringSync().replaceAll('<ROOT>', root);

void main() {
  test('analyze --format=machine (saída real)', () {
    final failures = parseAnalyzeMachine(output('analyze_machine'), root);
    const invalid =
        "lib/src/bad.dart:2 invalid_assignment: A value of type 'String' "
        "can't be assigned to a variable of type 'int'.";
    const undefined =
        'lib/src/bad.dart:3 undefined_identifier: Undefined name '
        "'undefinedThing'.";
    const unused =
        'lib/src/bad.dart:2 unused_local_variable: The value of the local '
        "variable 'x' isn't used.";
    expect(failures.map((f) => '${f.location} ${f.message}'), [
      invalid,
      undefined,
      unused,
    ]);
  });

  test('analyze machine com | escapado e linhas lixo', () {
    final f = parseAnalyzeMachine(
      'ruído\nINFO|LINT|X|$root/lib/a\\|b.dart|1|1|1|msg com \\| barra\n'
      'DEBUG|a|b|c|d|e|f|g',
      root,
    );
    expect(f.single.location, 'lib/a|b.dart:1');
    expect(f.single.message, 'x: msg com | barra');
  });

  test('flutter analyze humano (saída real)', () {
    final failures = parseAnalyzeHuman(output('analyze_human'), root);
    expect(failures, hasLength(3));
    expect(failures[1].location, 'lib/src/bad.dart:2');
    expect(failures[1].message, startsWith('invalid_assignment: A value'));
  });

  test('dart format (saída real)', () {
    final f = parseFormat(output('format'), root);
    expect(f.single.location, 'lib/src/ugly.dart');
    expect(f.single.message, 'não formatado');
  });

  test('test --reporter json (saída real): falhas e erro de carga', () {
    final run = parseTestJson(output('test_json'), root);
    expect(run.sawEvents, isTrue);
    expect(run.passed, 1);
    final byMessage = [
      for (final f in run.failures) '${f.location} ${f.message}',
    ];
    expect(byMessage, hasLength(3));
    expect(
      byMessage,
      contains(
        'test/pkg_test.dart "[AC-02] retorna Err quando usuário bloqueado"  '
        "Expected: 'Err<BlockedUserFailure>' Actual: 'Ok'",
      ),
    );
    expect(
      byMessage.any((m) => m.contains('"lança"  Bad state: quebrou aqui')),
      isTrue,
    );
    expect(
      byMessage,
      contains(
        'test/broken_test.dart falha ao carregar: test/broken_test.dart:2:38: '
        "Error: A value of type 'String' can't be assigned to a variable of "
        "type 'int'.",
      ),
    );
  });

  test('test json sem eventos ou com linhas inválidas', () {
    final run = parseTestJson('{quebrado\n[1]\nqualquer', root);
    expect(run.sawEvents, isFalse);
    expect(run.failures, isEmpty);
    final skipped = parseTestJson(
      '{"type":"testDone","testID":1,"result":"success","skipped":true}\n'
      '{"type":"testDone","testID":2,"result":"error","hidden":false}',
      root,
    );
    expect(skipped.failures.single.message, '"teste 2"  error');
  });

  test('parser genérico (custom_lint e saída sem caminho)', () {
    final lint = parseGeneric(
      '  lib/features/a.dart:12:3 • Domain não pode importar Flutter • '
      'domain_imports • ERROR\nResumo: 1 issue\n',
      root,
    );
    expect(lint.single.location, 'lib/features/a.dart:12');
    expect(lint.single.message, startsWith('3 • Domain não pode'));
    final plain = parseGeneric('\nerro 1\nerro 2\n', root);
    expect(plain.map((f) => f.message), ['erro 1', 'erro 2']);
  });

  test('paths e truncate', () {
    expect(relativeToRoot('$root/lib/a.dart', root), 'lib/a.dart');
    expect(
      relativeToRoot('file://$root/test/a_test.dart', root),
      'test/a_test.dart',
    );
    expect(relativeToRoot('/outro/x.dart', root), '/outro/x.dart');
    expect(truncate('a\n  b', 10), 'a b');
    expect(truncate('x' * 20, 10), '${'x' * 9}…');
  });
}
