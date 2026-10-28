import 'package:flutter_sdd/src/core/gates/command_line.dart';
import 'package:test/test.dart';

void main() {
  test('tokenize respeita aspas', () {
    expect(tokenize(' dart  format "a b.dart" \'c\' x'), [
      'dart',
      'format',
      'a b.dart',
      'c',
      'x',
    ]);
    expect(tokenize('a ""'), ['a', '']);
    expect(() => tokenize('a "b'), throwsFormatException);
  });

  test('buildCommand substitui ou remove {files}', () {
    const cmd = 'dart format --set-exit-if-changed {files}';
    expect(buildCommand(cmd, files: ['lib/a.dart', 'lib/b c.dart']), [
      'dart',
      'format',
      '--set-exit-if-changed',
      'lib/a.dart',
      'lib/b c.dart',
    ]);
    expect(buildCommand(cmd), ['dart', 'format', '--set-exit-if-changed']);
    expect(() => buildCommand('{files}'), throwsFormatException);
  });

  test('withJsonReporter injeta e substitui o reporter', () {
    expect(withJsonReporter(['flutter', 'test', '--coverage']), [
      'flutter',
      'test',
      '--reporter',
      'json',
      '--coverage',
    ]);
    expect(
      withJsonReporter([
        'dart',
        'test',
        '-r',
        'expanded',
        '--reporter=compact',
        '-rx',
        'a',
      ]),
      ['dart', 'test', '--reporter', 'json', 'a'],
    );
    expect(withJsonReporter(['make', 'test']), ['make', 'test']);
  });
}
