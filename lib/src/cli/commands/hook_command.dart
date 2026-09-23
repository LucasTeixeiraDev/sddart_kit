import 'package:args/command_runner.dart';
import 'package:flutter_sdd/src/cli/sdd_command.dart';
import 'package:flutter_sdd/src/cli/sdd_context.dart';
import 'package:flutter_sdd/src/core/hooks/guard_bash.dart';
import 'package:flutter_sdd/src/core/hooks/hook_input.dart';
import 'package:flutter_sdd/src/infra/exit_codes.dart';

/// Hooks chamados pelas ferramentas (payload JSON no stdin).
class HookCommand extends Command<int> {
  HookCommand(SddContext context) {
    addSubcommand(_FormatHook(context));
    addSubcommand(_GuardBashHook(context));
  }

  @override
  String get name => 'hook';

  @override
  String get description => 'Hooks usados pelos arquivos gerados (interno).';
}

/// Exit 2 bloqueia a ferramenta (Claude Code PreToolUse).
const _blockExitCode = 2;

class _FormatHook extends SddCommand {
  _FormatHook(super.context);

  @override
  String get name => 'format';

  @override
  String get description => 'Roda dart format no arquivo .dart editado.';

  @override
  Future<int> run() async {
    final path = HookInput.parse(await context.readStdin()).filePath;
    if (path != null &&
        path.endsWith('.dart') &&
        context.fs.file(path).existsSync()) {
      final result = await context.processRunner.run('dart', [
        'format',
        path,
      ], workingDirectory: context.workingDirectory);
      if (!result.ok) logger.detail(result.stderr);
    }
    // Nunca bloqueia a edição.
    return ExitCodes.ok;
  }
}

class _GuardBashHook extends SddCommand {
  _GuardBashHook(super.context) {
    argParser.addMultiOption(
      'allow',
      help: 'Prefixo de comando permitido (repetível).',
    );
  }

  @override
  String get name => 'guard-bash';

  @override
  String get description => 'Bloqueia comandos Bash fora da lista --allow.';

  @override
  Future<int> run() async {
    final input = HookInput.parse(await context.readStdin());
    if (input.toolName != null && input.toolName != 'Bash') {
      return ExitCodes.ok;
    }
    final reason = guardBash(
      input.command,
      argResults!['allow'] as List<String>,
    );
    if (reason == null) return ExitCodes.ok;
    context.err.writeln(reason);
    return _blockExitCode;
  }
}
