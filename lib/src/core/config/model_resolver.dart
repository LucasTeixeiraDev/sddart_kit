import 'package:flutter_sdd/src/core/config/sdd_config.dart';

/// Modelo resolvido para um tier numa ferramenta.
class ResolvedModel {
  const ResolvedModel(this.value, {this.warning});

  final String value;

  /// Preenchido quando o valor caiu em `inherit` por falta de mapeamento.
  final String? warning;
}

/// Aliases do Claude Code que não são identificadores válidos no Cursor.
const claudeAliases = {'opus', 'sonnet', 'haiku', 'fable'};

const inheritModel = 'inherit';

/// Traduz tier → valor do campo `model` de cada ferramenta.
///
/// Claude aceita aliases e ids completos. O Cursor só aceita ids próprios ou
/// `inherit`: sem override `cursor:` e com padrão sendo um alias do Claude, o
/// resultado é `inherit` com aviso (nunca erro).
ResolvedModel resolveModel(SddConfig config, Tier tier, Target target) {
  final mapping = config.models[tier] ?? const ModelMapping();
  final value = mapping.forTarget(target);
  if (target == Target.cursor &&
      !mapping.hasExplicit(Target.cursor) &&
      (value == null || claudeAliases.contains(value))) {
    return ResolvedModel(
      inheritModel,
      warning:
          'models.${tier.name}: sem id do Cursor (use '
          '{default: ${value ?? '<modelo>'}, cursor: <id>}); usando inherit',
    );
  }
  return ResolvedModel(value ?? inheritModel);
}

/// Avisos de modelo para todos os targets configurados.
List<String> modelWarnings(SddConfig config) => [
  for (final target in config.targets)
    for (final tier in Tier.values) ?resolveModel(config, tier, target).warning,
];
