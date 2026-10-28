import 'package:flutter_sdd/src/core/sync/managed_files.dart';
import 'package:flutter_sdd/src/core/sync/manifest.dart';
import 'package:test/test.dart';

void main() {
  group('applyManagedSection', () {
    const block = '<!-- sdd:begin -->\nS\n<!-- sdd:end -->';

    test('arquivo novo, vazio ou sem marcadores', () {
      expect(applyManagedSection(null, 'S\n'), '$block\n');
      expect(applyManagedSection('  ', 'S'), '$block\n');
      expect(
        applyManagedSection('# Meu\n\ntexto\n', 'S'),
        '# Meu\n\ntexto\n\n$block\n',
      );
    });

    test('substitui só entre marcadores', () {
      const existing =
          '# topo\n<!-- sdd:begin -->\nvelho\n<!-- sdd:end -->\nrodapé\n';
      expect(applyManagedSection(existing, 'S'), '# topo\n$block\nrodapé\n');
    });

    test('marcadores incompletos', () {
      expect(
        () => applyManagedSection('<!-- sdd:begin -->\nx', 'S'),
        throwsA(isA<ManagedSectionException>()),
      );
      expect(
        () => applyManagedSection('<!-- sdd:end -->\n<!-- sdd:begin -->', 'S'),
        throwsA(isA<ManagedSectionException>()),
      );
    });
  });

  test('ensureClaudeImport', () {
    expect(ensureClaudeImport(null), '@AGENTS.md\n');
    expect(ensureClaudeImport('# eu\n@AGENTS.md\n'), '# eu\n@AGENTS.md\n');
    expect(ensureClaudeImport('# eu\n'), '# eu\n\n@AGENTS.md\n');
  });

  test('manifesto: ida e volta, e tolerância a lixo', () {
    const m = GeneratedManifest(files: {'b', 'a'}, createdJson: {'x.json'});
    final parsed = GeneratedManifest.parse(m.serialize());
    expect(parsed.files, {'a', 'b'});
    expect(parsed.createdJson, {'x.json'});
    expect(m.serialize(), contains('"a",\n    "b"'));
    expect(GeneratedManifest.parse('{').files, isEmpty);
    expect(GeneratedManifest.parse('[]').files, isEmpty);
  });
}
