import 'package:flutter_sdd/src/core/adapters/generated_file.dart';
import 'package:flutter_sdd/src/core/adapters/tool_adapter.dart';
import 'package:flutter_sdd/src/core/config/model_resolver.dart';
import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';

/// Gera `.claude/` (formatos em docs/adapters.md).
class ClaudeAdapter implements ToolAdapter {
  const ClaudeAdapter(this.version);

  final String version;

  @override
  Target get target => Target.claude;

  static const Map<AbstractTool, List<String>> _toolNames = {
    AbstractTool.read: ['Read'],
    AbstractTool.search: ['Grep', 'Glob'],
    AbstractTool.edit: ['Edit'],
    AbstractTool.write: ['Write'],
    AbstractTool.bash: ['Bash'],
  };

  @override
  AdapterOutput generate(KitBundle bundle, SddConfig config) {
    final files = <GeneratedFile>[];
    final warnings = <String>[];

    for (final agent in bundle.agents) {
      for (final (name, tier) in agentVariants(agent)) {
        final model = resolveModel(config, tier, target);
        if (model.warning != null) warnings.add(model.warning!);
        files.add(
          GeneratedFile.text(
            '.claude/agents/$name.md',
            generatedMarkdown(
              {
                'name': name,
                'description': variantDescription(agent, tier),
                'tools': [for (final t in agent.tools) ..._toolNames[t]!],
                'model': model.value,
                if (agent.skills.isNotEmpty)
                  'skills': [for (final s in agent.skills) generatedName(s)],
                if (agent.bashAllow.isNotEmpty)
                  'hooks': {
                    'PreToolUse': [
                      {
                        'matcher': 'Bash',
                        'hooks': [
                          {
                            'type': 'command',
                            'command': guardBashCommand(agent.bashAllow),
                          },
                        ],
                      },
                    ],
                  },
              },
              agent.body,
              version,
            ),
          ),
        );
      }
    }

    for (final skill in bundle.skills) {
      final name = generatedName(skill.name);
      files.addAll(
        skillFiles(
          dir: '.claude/skills/$name',
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
          dir: '.claude/skills/$name',
          frontmatter: {
            'name': name,
            'description': command.description,
            if (command.args != null) 'argument-hint': command.args,
            'disable-model-invocation': true,
          },
          body: command.body,
          files: const [],
          version: version,
        ),
      );
    }

    for (final rule in bundle.rules) {
      files.add(
        GeneratedFile.text(
          '.claude/rules/${generatedName(rule.name)}.md',
          generatedMarkdown(
            rule.always ? null : {'paths': rule.globs},
            rule.body,
            version,
          ),
        ),
      );
    }

    return AdapterOutput(
      files: files,
      warnings: warnings,
      hooks: [
        HookRegistration('.claude/settings.json', HookStyle.claudeSettings, {
          if (config.hooks.formatOnEdit)
            'PostToolUse': [
              {
                'matcher': 'Edit|Write',
                'hooks': [
                  {'type': 'command', 'command': formatHookCommand},
                ],
              },
            ],
        }),
      ],
    );
  }
}
