import 'package:flutter_sdd/src/core/kit/frontmatter.dart';
import 'package:test/test.dart';

void main() {
  test('separa frontmatter e corpo', () {
    final doc = parseFrontmatter('---\nname: a\nlist: [1]\n---\n\ncorpo\n');
    expect(doc.data, {
      'name': 'a',
      'list': [1],
    });
    expect(doc.body, '\ncorpo\n');
  });

  test('sem frontmatter, CRLF e frontmatter vazio', () {
    expect(parseFrontmatter('só corpo').data, isEmpty);
    expect(parseFrontmatter('---\r\na: 1\r\n---\r\nx').body, 'x');
    expect(parseFrontmatter('---\n---\nx').data, isEmpty);
  });

  test('erros', () {
    expect(() => parseFrontmatter('---\na: 1\n'), throwsFormatException);
    expect(() => parseFrontmatter('---\na: [\n---\n'), throwsFormatException);
    expect(() => parseFrontmatter('---\n- a\n---\n'), throwsFormatException);
  });
}
