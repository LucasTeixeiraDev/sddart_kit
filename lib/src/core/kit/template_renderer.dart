import 'dart:convert';

import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';

final _placeholder = RegExp(r'\{\{sdd:([a-z0-9_.]+)\}\}');

/// Substitui `{{sdd:chave}}` por [vars]. Chaves desconhecidas vão para
/// [missing] (o texto fica inalterado nesses pontos).
String renderTemplate(
  String text,
  Map<String, String> vars, {
  List<String>? missing,
}) => text.replaceAllMapped(_placeholder, (m) {
  final value = vars[m.group(1)];
  if (value == null) {
    missing?.add(m.group(1)!);
    return m.group(0)!;
  }
  return value;
});

/// Variáveis disponíveis para o conteúdo do kit.
Map<String, String> buildRenderVars(
  SddConfig config,
  KitBundle bundle, {
  required String sddVersion,
}) {
  String bullets(Iterable<String> lines) =>
      lines.isEmpty ? '- (nenhum)' : lines.map((l) => '- $l').join('\n');
  final commands = config.commands;
  return {
    'version': sddVersion,
    // Pasta de skills que todas as ferramentas configuradas leem (o Cursor
    // também lê .claude/skills/).
    'skills_dir': config.hasTarget(Target.claude)
        ? '.claude/skills'
        : '.cursor/skills',
    'stack': config.stack,
    'project.features_path': config.project.featuresPath,
    'project.test_path': config.project.testPath,
    'project.state_management': config.project.stateManagement,
    'project.error_handling': config.project.errorHandling.name,
    'execution.max_fix_attempts': '${config.execution.maxFixAttempts}',
    'execution.escalate_to': config.execution.escalateTo.name,
    'memory.learnings_warn_after': '${config.learningsWarnAfter}',
    'dod.coverage.min': '${config.dod.coverage.min}',
    for (final MapEntry(:key, :value) in commands.entries)
      'commands.$key': value,
    'gates_list': bullets(config.dod.gates.map(_gateLine(commands))),
    'dod_checklist': bullets(config.dod.checklist),
    'commands_list': bullets(bundle.commands.map(_commandLine)),
    'skills_list': bullets(
      bundle.skills.map((s) => '`${generatedName(s.name)}`: ${s.description}'),
    ),
    'agents_list': bullets(bundle.agents.map(_agentLine)),
  };
}

String Function(String) _gateLine(Map<String, String> commands) =>
    (gate) => commands.containsKey(gate)
    ? '`$gate`: `${commands[gate]}`'
    : '`$gate` (calculado pelo sdd)';

String _commandLine(KitCommand c) {
  final args = c.args == null ? '' : ' ${c.args}';
  return '`/${generatedName(c.name)}$args`: ${c.description}';
}

String _agentLine(KitAgent a) {
  final variants = a.tierVariants.isEmpty
      ? ''
      : '-<${a.tierVariants.map((t) => t.name).join('|')}>';
  return '`${generatedName(a.name)}$variants`: ${a.description}';
}

/// Renderiza corpos e arquivos `.md` de apoio de todo o bundle.
KitBundle renderBundle(KitBundle bundle, Map<String, String> vars) {
  final issues = <String>[];
  String render(String text, String source) {
    final missing = <String>[];
    final out = renderTemplate(text, vars, missing: missing);
    for (final key in missing) {
      issues.add('$source: variável {{sdd:$key}} desconhecida');
    }
    return out;
  }

  final rendered = KitBundle(
    agents: [
      for (final a in bundle.agents)
        KitAgent(
          name: a.name,
          description: render(a.description, a.sourcePath),
          body: render(a.body, a.sourcePath),
          layer: a.layer,
          sourcePath: a.sourcePath,
          tier: a.tier,
          tierVariants: a.tierVariants,
          tools: a.tools,
          readonly: a.readonly,
          skills: a.skills,
          bashAllow: a.bashAllow,
        ),
    ],
    skills: [
      for (final s in bundle.skills)
        KitSkill(
          name: s.name,
          description: render(s.description, s.sourcePath),
          body: render(s.body, s.sourcePath),
          layer: s.layer,
          sourcePath: s.sourcePath,
          files: [
            for (final f in s.files)
              if (f.relativePath.endsWith('.md'))
                SkillFile(
                  f.relativePath,
                  utf8.encode(render(utf8.decode(f.bytes), f.relativePath)),
                )
              else
                f,
          ],
        ),
    ],
    rules: [
      for (final r in bundle.rules)
        KitRule(
          name: r.name,
          description: render(r.description, r.sourcePath),
          body: render(r.body, r.sourcePath),
          layer: r.layer,
          sourcePath: r.sourcePath,
          globs: [for (final g in r.globs) render(g, r.sourcePath)],
          always: r.always,
        ),
    ],
    commands: [
      for (final c in bundle.commands)
        KitCommand(
          name: c.name,
          description: render(c.description, c.sourcePath),
          body: render(c.body, c.sourcePath),
          layer: c.layer,
          sourcePath: c.sourcePath,
          args: c.args,
        ),
    ],
    // Templates são renderizados por quem os usa (AGENTS.md, sdd new).
    templates: bundle.templates,
    bricks: bundle.bricks,
  );
  if (issues.isNotEmpty) throw KitException(issues);
  return rendered;
}
