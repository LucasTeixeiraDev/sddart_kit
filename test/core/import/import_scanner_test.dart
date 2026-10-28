import 'package:file/memory.dart';
import 'package:flutter_sdd/src/core/import/import_scanner.dart';
import 'package:test/test.dart';

import '../../helpers/test_env.dart';

const src = '/fonte';

void main() {
  late MemoryFileSystem fs;
  late ImportScan scan;

  setUp(() {
    fs = memoryFs();
    copyIntoMemory('$repoRoot/test/fixtures/import_source', fs, src);
    scan = scanImportSource(fs, src);
  });

  ImportItem item(String path) => scan.items.firstWhere((i) => i.path == path);

  test('classifica tipo, ferramenta e nome', () {
    expect(scan.items.map((i) => i.path), isNot(contains('README.md')));
    expect(scan.skippedGenerated, ['.claude/agents/sdd-explorer.md']);

    final reviewer = item('.claude/agents/code-reviewer.md');
    expect(reviewer.kind, ImportKind.agent);
    expect(reviewer.tool, ImportTool.claude);
    expect(
      reviewer.description,
      'Revisa PRs do app com foco em arquitetura e testes.',
    );

    expect(item('.cursor/rules/widgets.mdc').tool, ImportTool.cursor);
    expect(item('.cursor/rules/widgets.mdc').kind, ImportKind.rule);
    expect(item('.claude/rules/naming.md').kind, ImportKind.rule);
    expect(item('CLAUDE.md').kind, ImportKind.memory);
    expect(item('AGENTS.md').tool, ImportTool.generic);

    final skill = item('.claude/skills/api-errors/SKILL.md');
    expect(skill.name, 'api-errors');
    expect(skill.supportFiles, [
      '.claude/skills/api-errors/references/codes.md',
    ]);

    final logging = item('shared/skills/logging/SKILL.md');
    expect(logging.name, 'logging');
    expect(logging.tool, ImportTool.generic);
    expect(item('shared/rules/security.md').kind, ImportKind.rule);
  });

  test('duplicatas: mesmo nome, mesmo conteúdo e similares', () {
    expect(
      item('.claude/agents/code-reviewer.md').duplicates.single.reason,
      'same_name',
    );
    final deploy = item('.claude/commands/deploy.md').duplicates.single;
    expect(deploy.reason, 'same_content');
    expect(deploy.path, '.cursor/commands/deploy.md');
    final similar = item(
      '.claude/skills/api-errors/SKILL.md',
    ).duplicates.single;
    expect(similar.reason, 'similar');
    expect(similar.similarity, greaterThanOrEqualTo(similarityThreshold));
    expect(item('.cursor/rules/widgets.mdc').duplicates, isEmpty);
  });

  test('json com resumo', () {
    final json = scan.toJson();
    expect(json['summary'], {
      'agent': 2,
      'skill': 2,
      'rule': 4,
      'command': 2,
      'memory': 2,
    });
    final first = (json['items']! as List).first as Map;
    expect(first.keys, containsAll(['path', 'tool', 'kind', 'name', 'hash']));
    final dup = item(
      '.claude/skills/api-errors/SKILL.md',
    ).toJson()['duplicates'];
    expect((dup! as List).single, containsPair('reason', 'similar'));
  });

  test('frontmatter inválido não derruba o scan; caminho inexistente', () {
    fs.file('$src/.claude/agents/quebrado.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('---\na: [\n---\ncorpo');
    expect(
      scanImportSource(fs, src).items.map((i) => i.path),
      contains('.claude/agents/quebrado.md'),
    );
    expect(() => scanImportSource(fs, '/nada'), throwsA(isA<Exception>()));
  });
}
