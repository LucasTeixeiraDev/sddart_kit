import 'package:flutter_sdd/src/cli/sdd_context.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:flutter_sdd/src/core/project/project_loader.dart';
import 'package:flutter_sdd/src/core/sync/sync_planner.dart';
import 'package:flutter_sdd/src/infra/exit_codes.dart';
import 'package:flutter_sdd/src/infra/logger.dart';
import 'package:flutter_sdd/src/version.dart';

/// Executa `sync` (ou `sync --check`) e reporta. Usado por `sync` e `init`.
Future<int> runSync(
  SddContext context,
  Logger logger, {
  required bool check,
  required bool json,
  String? kitPath,
}) async {
  final SyncPlan plan;
  try {
    final project = await loadProject(
      fs: context.fs,
      root: context.workingDirectory,
      locator: context.kitLocator,
      kitPath: kitPath,
    );
    for (final w in project.configWarnings) {
      logger.warn('$w');
    }
    plan = project.planSync(context.fs, sddVersion);
  } on ProjectLoadException catch (e) {
    logger.error(e.message);
    return ExitCodes.usage;
  } on KitException catch (e) {
    logger.error('kit/overrides inválidos:\n$e');
    return ExitCodes.usage;
  }

  if (!check) applySyncPlan(context.fs, context.workingDirectory, plan);
  final conflicts = plan.of(SyncAction.conflict).toList();

  if (json) {
    logger.json({
      'check': check,
      'up_to_date': plan.upToDate,
      'changes': [for (final c in plan.changes) c.toJson()],
      'warnings': plan.warnings,
    });
  } else {
    plan.warnings.forEach(logger.warn);
    for (final c in plan.changes) {
      final line =
          '${c.action.name.padRight(8)} ${c.path}'
          '${c.reason == null ? '' : '  (${c.reason})'}';
      if (check || c.action == SyncAction.conflict) {
        logger.info(line);
      } else {
        logger.detail(line);
      }
    }
    if (plan.upToDate) {
      logger.info('sync em dia');
    } else if (check) {
      logger.info('${plan.changes.length} mudanças pendentes; rode sdd sync');
    } else {
      final writes = plan.of(SyncAction.write).length;
      final deletes = plan.of(SyncAction.delete).length;
      logger.info(
        'sync: $writes escritos · $deletes removidos · '
        '${conflicts.length} conflitos',
      );
    }
  }
  if (check) return plan.upToDate ? ExitCodes.ok : ExitCodes.failure;
  return conflicts.isEmpty ? ExitCodes.ok : ExitCodes.failure;
}
