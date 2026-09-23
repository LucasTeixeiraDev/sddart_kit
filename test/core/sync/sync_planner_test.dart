import 'dart:convert';

import 'package:flutter_sdd/src/core/kit/kit_lock.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:flutter_sdd/src/core/sync/sync_planner.dart';
import 'package:test/test.dart';

import '../../helpers/sample_project.dart';
import '../../helpers/test_env.dart';

const lock = KitLock(sddVersion: '1.0.0', stack: 'sample', kitHash: 'h');

SyncPlan plan(SampleProject p, {String version = '1.0.0'}) => SyncPlanner(
  fs: p.fs,
  root: memProjectPath,
  version: version,
).plan(bundle: p.bundle(), config: p.config, lock: lock);

SyncPlan sync(SampleProject p, {String version = '1.0.0'}) {
  final result = plan(p, version: version);
  applySyncPlan(p.fs, memProjectPath, result);
  return result;
}

List<String> paths(SyncPlan plan, SyncAction action) => [
  for (final c in plan.of(action)) c.path,
];

void main() {
  test('primeiro sync gera tudo; segundo não muda nada (idempotente)', () {
    final p = SampleProject();
    final first = sync(p);
    expect(
      paths(first, SyncAction.write),
      containsAll([
        '.claude/agents/sdd-judge.md',
        '.cursor/agents/sdd-worker-fast.md',
        '.claude/skills/sdd-go/SKILL.md',
        'AGENTS.md',
        'CLAUDE.md',
        '.sdd/generated.json',
        '.sdd/kit.lock',
      ]),
    );
    expect(first.warnings.single, contains('models.fast'));
    expect(plan(p).upToDate, isTrue);
    expect(p.read('CLAUDE.md'), '@AGENTS.md\n');
    expect(p.read('AGENTS.md'), contains('/sdd-go <spec>'));
    // Sem format_on_edit, nenhum JSON de hooks é criado.
    expect(p.exists('.claude/settings.json'), isFalse);
  });

  test('preserva conteúdo do usuário fora das áreas gerenciadas', () {
    final p = SampleProject()
      ..write('AGENTS.md', '# Projeto\n\nregras minhas\n')
      ..write('CLAUDE.md', '# Claude\n')
      ..write('.claude/agents/meu-agente.md', '---\nname: meu\n---\nmeu\n')
      ..write('.claude/skills/minha/SKILL.md', 'minha skill');
    sync(p);
    expect(p.read('AGENTS.md'), startsWith('# Projeto\n\nregras minhas\n\n'));
    expect(p.read('CLAUDE.md'), '# Claude\n\n@AGENTS.md\n');
    expect(p.read('.claude/agents/meu-agente.md'), contains('meu'));
    expect(p.exists('.claude/skills/minha/SKILL.md'), isTrue);

    // Edição do usuário fora dos marcadores sobrevive a novo sync.
    p.write('AGENTS.md', '${p.read('AGENTS.md')}\nnota final\n');
    sync(p);
    expect(p.read('AGENTS.md'), endsWith('nota final\n'));
    expect(plan(p).upToDate, isTrue);
  });

  test('remove órfãos com marcador; nunca arquivos do usuário', () {
    final p = SampleProject();
    sync(p);
    p
      ..write('.sdd/overrides/agents/worker.md', '---\ndisabled: true\n---\n')
      ..write(
        '.sdd/overrides/skills/writing/SKILL.md',
        '---\ndisabled: true\n---\n',
      )
      ..write('.claude/agents/sem-marcador.md', 'do usuário');
    // Worker usa a skill writing; remove também o agente para validar.
    final second = sync(p);
    expect(
      paths(second, SyncAction.delete),
      containsAll([
        '.claude/agents/sdd-worker-fast.md',
        '.cursor/agents/sdd-worker-deep.md',
        '.claude/skills/sdd-writing/SKILL.md',
        '.claude/skills/sdd-writing/run.sh',
      ]),
    );
    expect(p.exists('.claude/agents/sem-marcador.md'), isTrue);
    // Diretório da skill removido por inteiro; diretório gerenciado mantido.
    expect(
      p.fs.directory('$memProjectPath/.claude/skills/sdd-writing').existsSync(),
      isFalse,
    );
    expect(
      p.fs.directory('$memProjectPath/.claude/skills').existsSync(),
      isTrue,
    );
  });

  test('mudar targets remove arquivos da ferramenta retirada', () {
    final p = SampleProject();
    sync(p);
    p.writeConfig('targets: [claude]\n');
    final second = sync(p);
    expect(
      paths(second, SyncAction.delete),
      contains('.cursor/rules/sdd-domain.mdc'),
    );
    expect(
      p.fs.directory('$memProjectPath/.cursor/agents').listSync(),
      isEmpty,
    );
  });

  test('arquivo do usuário no caminho gerado vira conflito', () {
    final p = SampleProject()
      ..write('.claude/agents/sdd-judge.md', 'meu judge');
    final result = sync(p);
    final conflict = result.of(SyncAction.conflict).single;
    expect(conflict.path, '.claude/agents/sdd-judge.md');
    expect(conflict.toJson()['reason'], contains('arquivo do usuário'));
    expect(p.read('.claude/agents/sdd-judge.md'), 'meu judge');
  });

  test(
    'arquivo binário gerado alterado: sobrescreve se estiver no manifesto',
    () {
      final p = SampleProject();
      sync(p);
      p.write('.claude/skills/sdd-writing/run.sh', 'alterado');
      final result = sync(p);
      expect(paths(result, SyncAction.write), [
        '.claude/skills/sdd-writing/run.sh',
      ]);
    },
  );

  test('nova versão do sdd regrava cabeçalhos e lock', () {
    final p = SampleProject();
    sync(p);
    final result = plan(p, version: '1.1.0');
    expect(
      paths(result, SyncAction.write),
      contains('.claude/agents/sdd-judge.md'),
    );
  });

  test('marcadores quebrados no AGENTS.md viram conflito', () {
    final p = SampleProject()..write('AGENTS.md', '<!-- sdd:begin -->\nx\n');
    final result = plan(p);
    expect(paths(result, SyncAction.conflict), ['AGENTS.md']);
  });

  group('hooks', () {
    test(
      'ciclo: cria settings.json, preserva usuário e remove ao desligar',
      () {
        final p = SampleProject(extraConfig: 'hooks: {format_on_edit: true}\n');
        sync(p);
        final settings =
            jsonDecode(p.read('.claude/settings.json')) as Map<String, Object?>;
        expect(settings['hooks'], isNotNull);
        // D-012: com claude como target, não há .cursor/hooks.json.
        expect(p.exists('.cursor/hooks.json'), isFalse);
        expect(plan(p).upToDate, isTrue);

        p.writeConfig('hooks: {format_on_edit: false}\n');
        final off = sync(p);
        expect(
          paths(off, SyncAction.delete),
          contains('.claude/settings.json'),
        );
        expect(p.exists('.claude/settings.json'), isFalse);
      },
    );

    test('settings.json do usuário: merge e nunca apagado', () {
      final p = SampleProject(extraConfig: 'hooks: {format_on_edit: true}\n')
        ..write('.claude/settings.json', '{"model": "x"}');
      sync(p);
      expect(p.read('.claude/settings.json'), contains('"model": "x"'));
      p.writeConfig('');
      sync(p);
      expect(jsonDecode(p.read('.claude/settings.json')), {'model': 'x'});
      expect(plan(p).upToDate, isTrue);
    });

    test('só cursor: hooks.json próprio', () {
      final p = SampleProject(
        extraConfig: 'targets: [cursor]\nhooks: {format_on_edit: true}\n',
      );
      sync(p);
      expect(p.read('.cursor/hooks.json'), contains('"version": 1'));
      expect(p.exists('.claude/settings.json'), isFalse);
      expect(p.exists('CLAUDE.md'), isFalse);
    });

    test('JSON inválido do usuário vira conflito só se houver hooks', () {
      final p = SampleProject()..write('.claude/settings.json', '{');
      expect(plan(p).of(SyncAction.conflict), isEmpty);
      p.writeConfig('hooks: {format_on_edit: true}\n');
      expect(paths(plan(p), SyncAction.conflict), ['.claude/settings.json']);
      p.write('.claude/settings.json', '[]');
      expect(paths(plan(p), SyncAction.conflict), ['.claude/settings.json']);
    });
  });

  test('erros de kit: template ausente, variável e caminho duplicado', () {
    final p = SampleProject()
      ..write('.sdd/overrides/templates/agents-md-section.md', '{{sdd:nope}}');
    expect(() => plan(p), throwsA(isA<KitException>()));

    p.fs.file('$memKitPath/core/templates/agents-md-section.md').deleteSync();
    p.fs
        .file('$memProjectPath/.sdd/overrides/templates/agents-md-section.md')
        .deleteSync();
    expect(
      () => plan(p),
      throwsA(
        isA<KitException>().having((e) => '$e', 'msg', contains('ausente')),
      ),
    );
  });

  test('comando e skill com o mesmo nome geram conflito de caminho', () {
    final p = SampleProject()
      ..write(
        '.sdd/overrides/commands/writing.md',
        '---\ndescription: d\n---\nx\n',
      );
    expect(
      () => plan(p),
      throwsA(
        isA<KitException>().having(
          (e) => '$e',
          'msg',
          contains('mesmo arquivo'),
        ),
      ),
    );
  });
}
