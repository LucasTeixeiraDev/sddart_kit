import 'dart:convert';

import 'package:flutter_sdd/src/core/adapters/claude_adapter.dart';
import 'package:flutter_sdd/src/core/adapters/cursor_adapter.dart';
import 'package:flutter_sdd/src/core/adapters/generated_file.dart';
import 'package:flutter_sdd/src/core/kit/template_renderer.dart';
import 'package:test/test.dart';

import '../../helpers/golden.dart';
import '../../helpers/sample_project.dart';

Map<String, String> asText(AdapterOutput output) => {
  for (final f in output.files) f.path: utf8.decode(f.bytes),
};

AdapterOutput run(SampleProject project, {required bool cursor}) {
  final config = project.config;
  final bundle = project.bundle();
  final rendered = renderBundle(
    bundle,
    buildRenderVars(config, bundle, sddVersion: '1.2.3'),
  );
  return cursor
      ? const CursorAdapter('1.2.3').generate(rendered, config)
      : const ClaudeAdapter('1.2.3').generate(rendered, config);
}

void main() {
  test('claude: snapshot', () {
    final output = run(
      SampleProject(extraConfig: 'hooks: {format_on_edit: true}\n'),
      cursor: false,
    );
    expectGolden('claude_adapter', asText(output));
    final hooks = output.hooks.single;
    expect(hooks.path, '.claude/settings.json');
    expect(hooks.entries.keys, ['PostToolUse']);
    expect(output.warnings, isEmpty);
  });

  test(
    'cursor com claude: agentes e rules próprios; skills compartilhadas',
    () {
      final output = run(
        SampleProject(extraConfig: 'hooks: {format_on_edit: true}\n'),
        cursor: true,
      );
      expectGolden('cursor_adapter_shared', asText(output));
      // D-012: com claude como target o hook fica só em .claude/settings.json.
      expect(output.hooks.single.entries, isEmpty);
      // fast: haiku sem override cursor → inherit com aviso.
      expect(output.warnings.single, contains('models.fast'));
    },
  );

  test('cursor sozinho: gera skills, comandos e hooks próprios', () {
    final output = run(
      SampleProject(
        extraConfig: 'targets: [cursor]\nhooks: {format_on_edit: true}\n',
      ),
      cursor: true,
    );
    final files = asText(output);
    expect(files.keys, contains('.cursor/skills/sdd-writing/SKILL.md'));
    expect(files.keys, contains('.cursor/skills/sdd-writing/run.sh'));
    expect(
      files['.cursor/skills/sdd-go/SKILL.md'],
      contains('disable-model-invocation: true'),
    );
    expect(output.hooks.single.entries['afterFileEdit'], [
      {'command': 'sdd hook format'},
    ]);
  });

  test('cursor com agents: shared não gera .cursor/agents', () {
    final output = run(
      SampleProject(
        extraConfig: 'adapters: {cursor: {agents: shared, skills: own}}\n',
      ),
      cursor: true,
    );
    final paths = asText(output).keys;
    expect(paths.where((p) => p.startsWith('.cursor/agents/')), isEmpty);
    expect(paths, contains('.cursor/skills/sdd-writing/SKILL.md'));
  });

  test('marcador de arquivo gerado', () {
    expect(hasGeneratedMarker(generatedMarkdown(null, 'x', '1.0.0')), isTrue);
    expect(hasGeneratedMarker('# meu agente'), isFalse);
    expect(supportsMarker('a/b.mdc'), isTrue);
    expect(supportsMarker('a/run.sh'), isFalse);
  });
}
