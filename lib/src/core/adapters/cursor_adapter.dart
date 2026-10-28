import 'package:flutter_sdd/src/core/adapters/generated_file.dart';
import 'package:flutter_sdd/src/core/adapters/tool_adapter.dart';
import 'package:flutter_sdd/src/core/config/model_resolver.dart';
import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';

/// Gera `.cursor/` (formatos em docs/adapters.md).
///
/// O Cursor lê `.claude/skills/`, `.claude/agents/` e os hooks de
/// `.claude/settings.json`; quando claude também é target, evita duplicar
/// conforme `adapters.cursor` e D-012.
class CursorAdapter implements ToolAdapter {
  const CursorAdapter(this.version);

  final String version;

  @override
  Target get target => Target.cursor;

  @override
  AdapterOutput generate(KitBundle bundle, SddConfig config) {
    final files = <GeneratedFile>[];
    final warnings = <String>{};
    final withClaude = config.hasTarget(Target.claude);

    final ownAgents =
        !withClaude || config.adapters.cursorAgents == CursorAgents.own;
    if (ownAgents) {
      for (final agent in bundle.agents) {
        for (final (name, tier) in agentVariants(agent)) {
          final model = resolveModel(config, tier, target);
          if (model.warning != null) warnings.add(model.warning!);
          files.add(
            GeneratedFile.text(
              '.cursor/agents/$name.md',
              generatedMarkdown(
                {
                  'name': name,
                  'description': variantDescription(agent, tier),
                  'model': model.value,
                  'readonly': agent.readonly,
                },
                agent.body,
                version,
              ),
            ),
          );
        }
      }
    }

    final ownSkills =
        !withClaude || config.adapters.cursorSkills == CursorSkills.own;
    if (ownSkills) {
      for (final skill in bundle.skills) {
        final name = generatedName(skill.name);
        files.addAll(
          skillFiles(
            dir: '.cursor/skills/$name',
            frontmatter: {'name': name, 'description': skill.description},
            body: skill.body,
            files: skill.files,
            version: version,
          ),
        );
      }
      for (final command in bundle.commands) {
        final name = generatedName(command.name);
        files.addAll(
          skillFiles(
            dir: '.cursor/skills/$name',
            frontmatter: {
              'name': name,
              'description': command.description,
              'disable-model-invocation': true,
            },
            body: command.body,
            files: const [],
            version: version,
          ),
        );
      }
    }

    for (final rule in bundle.rules) {
      files.add(
        GeneratedFile.text(
          '.cursor/rules/${generatedName(rule.name)}.mdc',
          generatedMarkdown(
            {
              'description': rule.description,
              if (rule.globs.isNotEmpty) 'globs': rule.globs.join(', '),
              'alwaysApply': rule.always,
            },
            rule.body,
            version,
          ),
        ),
      );
    }

    return AdapterOutput(
      files: files,
      warnings: warnings.toList(),
      hooks: [
        HookRegistration('.cursor/hooks.json', HookStyle.cursorHooks, {
          // D-012: com claude como target, o Cursor já executa o hook de
          // .claude/settings.json.
          if (config.hooks.formatOnEdit && !withClaude)
            'afterFileEdit': [
              {'command': formatHookCommand},
            ],
        }),
      ],
    );
  }
}
