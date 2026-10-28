import 'dart:convert';

import 'package:flutter_sdd/src/core/adapters/generated_file.dart';
import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';

/// Estratégia de tradução do kit canônico para uma ferramenta.
abstract interface class ToolAdapter {
  Target get target;

  /// [bundle] já renderizado.
  AdapterOutput generate(KitBundle bundle, SddConfig config);
}

/// Comando do hook de format-on-edit (implementado pelo próprio CLI).
const formatHookCommand = 'sdd hook format';

/// Prefixo que identifica entradas de hook do sdd em arquivos do usuário.
const sddHookPrefix = 'sdd hook ';

String guardWriteCommand(List<String> allow) =>
    'sdd hook guard-write ${allow.map((a) => "--allow '$a'").join(' ')}';

String guardBashCommand(List<String> allow) =>
    'sdd hook guard-bash ${allow.map((a) => "--allow '$a'").join(' ')}';

/// Variantes geradas de um agente: `(nome gerado, tier)`.
List<(String, Tier)> agentVariants(KitAgent agent) => agent.tierVariants.isEmpty
    ? [(generatedName(agent.name), agent.tier)]
    : [
        for (final tier in agent.tierVariants)
          ('${generatedName(agent.name)}-${tier.name}', tier),
      ];

String variantDescription(KitAgent agent, Tier tier) =>
    agent.tierVariants.isEmpty
    ? agent.description
    : '${agent.description} (tier ${tier.name})';

/// Arquivos de uma skill (ou comando como skill) em [dir].
List<GeneratedFile> skillFiles({
  required String dir,
  required Map<String, Object?> frontmatter,
  required String body,
  required List<SkillFile> files,
  required String version,
}) => [
  GeneratedFile.text(
    '$dir/SKILL.md',
    generatedMarkdown(frontmatter, body, version),
  ),
  for (final f in files)
    if (supportsMarker(f.relativePath))
      GeneratedFile.text(
        '$dir/${f.relativePath}',
        generatedMarkdown(null, utf8.decode(f.bytes), version),
      )
    else
      GeneratedFile.binary('$dir/${f.relativePath}', f.bytes),
];
