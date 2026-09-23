import 'package:flutter_sdd/src/cli/sdd_command.dart';
import 'package:flutter_sdd/src/core/doctor/doctor.dart';
import 'package:flutter_sdd/src/infra/exit_codes.dart';
import 'package:flutter_sdd/src/version.dart';

class DoctorCommand extends SddCommand {
  DoctorCommand(super.context);

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Verifica ambiente (Flutter, Dart, git), config, kit e kit.lock.';

  @override
  Future<int> run() async {
    final checks = await Doctor(
      fs: context.fs,
      processRunner: context.processRunner,
      kitLocator: context.kitLocator,
      cliVersion: sddVersion,
    ).run(context.workingDirectory, kitPath: kitPath);

    final failed = checks.where((c) => c.status == CheckStatus.fail).length;
    final warned = checks.where((c) => c.status == CheckStatus.warn).length;
    if (jsonOutput) {
      logger.json({
        'ok': failed == 0,
        'checks': [for (final c in checks) c.toJson()],
      });
    } else {
      for (final c in checks) {
        final tag = c.status.name.toUpperCase().padRight(4);
        logger.info('$tag ${c.name.padRight(9)} ${c.message}');
      }
      logger.info('$failed falhas · $warned avisos');
    }
    return failed == 0 ? ExitCodes.ok : ExitCodes.failure;
  }
}
