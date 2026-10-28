import 'package:flutter_sdd/flutter_sdd.dart';
import 'package:flutter_sdd/src/core/hooks/guard_bash.dart';
import 'package:flutter_sdd/src/core/hooks/guard_write.dart';
import 'package:flutter_sdd/src/core/hooks/hook_input.dart';
import 'package:test/test.dart';

import '../helpers/fake_process_runner.dart';
import '../helpers/test_env.dart';

Future<(int, String, FakeProcessRunner)> runHook(
  List<String> args,
  String stdin,
) async {
  final runner = FakeProcessRunner();
  final err = StringBuffer();
  final fs = memoryFs(fixture: 'app_cubit');
  final code = await SddCommandRunner(
    SddContext(
      fs: fs,
      processRunner: runner,
      prompter: ScriptedPrompter(),
      environment: const {},
      workingDirectory: memProjectPath,
      packageRoot: () async => null,
      out: StringBuffer(),
      err: err,
      interactive: false,
      readStdin: () async => stdin,
    ),
  ).run(['hook', ...args]);
  return (code, err.toString(), runner);
}

void main() {
  group('guardBash', () {
    const allow = ['sdd check', 'git diff'];
    test('permite prefixos exatos', () {
      expect(guardBash('sdd check --spec 0001 --json', allow), isNull);
      expect(guardBash('git diff', allow), isNull);
      expect(guardBash(null, allow), isNull);
    });
    test('bloqueia outros comandos e encadeamentos', () {
      expect(guardBash('git diffx', allow), contains('só pode rodar'));
      expect(guardBash('rm -rf /', allow), contains('só pode rodar'));
      expect(guardBash('git diff; rm x', allow), contains('encadeamento'));
      expect(guardBash(r'git diff $(rm x)', allow), contains('encadeamento'));
      expect(guardBash('git diff > out', allow), contains('encadeamento'));
    });
  });

  test('HookInput: formatos do Claude e do Cursor e lixo', () {
    expect(
      HookInput.parse('{"tool_input":{"file_path":"a.dart"}}').filePath,
      'a.dart',
    );
    expect(HookInput.parse('{"file_path":"b.dart"}').filePath, 'b.dart');
    expect(HookInput.parse('não é json').filePath, isNull);
    expect(HookInput.parse('[1]').toolName, isNull);
  });

  test('guard-bash: exit 2 com motivo no stderr', () async {
    final (code, err, _) = await runHook([
      'guard-bash',
      '--allow',
      'git diff',
    ], '{"tool_name":"Bash","tool_input":{"command":"rm x"}}');
    expect(code, 2);
    expect(err, contains('bloqueado'));

    final (ok, _, _) = await runHook([
      'guard-bash',
      '--allow',
      'git diff',
    ], '{"tool_name":"Bash","tool_input":{"command":"git diff HEAD"}}');
    expect(ok, ExitCodes.ok);

    final (other, _, _) = await runHook([
      'guard-bash',
      '--allow',
      'git diff',
    ], '{"tool_name":"Read","tool_input":{}}');
    expect(other, ExitCodes.ok);
  });

  group('guardWrite', () {
    const allow = ['specs/*/review.md'];
    test('permite só os globs, relativos à raiz', () {
      expect(
        guardWrite('/r/specs/0001-x/review.md', allow, root: '/r'),
        isNull,
      );
      expect(guardWrite('specs/0002-y/review.md', allow, root: '/r'), isNull);
      expect(guardWrite(null, allow, root: '/r'), isNull);
      expect(
        guardWrite('/r/lib/a.dart', allow, root: '/r'),
        contains('só pode gravar specs/*/review.md (tentou lib/a.dart)'),
      );
      expect(
        guardWrite('/fora/specs/1/review.md', allow, root: '/r'),
        isNotNull,
      );
    });
  });

  test('guard-write: usa o cwd do payload e bloqueia com exit 2', () async {
    final (code, err, _) = await runHook([
      'guard-write',
      '--allow',
      'specs/*/review.md',
    ], '{"cwd":"/proj","tool_input":{"file_path":"/proj/lib/x.dart"}}');
    expect(code, 2);
    expect(err, contains('tentou lib/x.dart'));
    final (ok, _, _) = await runHook(
      ['guard-write', '--allow', 'specs/*/review.md'],
      '{"cwd":"/proj","tool_input":{"file_path":"/proj/specs/0001-a/review.md"}}',
    );
    expect(ok, ExitCodes.ok);
  });

  test('format: roda dart format só em .dart existente', () async {
    final (code, _, runner) = await runHook(
      ['format'],
      '{"tool_input":{"file_path":"$memProjectPath/lib/features/profile/profile.dart"}}',
    );
    expect(code, ExitCodes.ok);
    expect(runner.calls.single.arguments, [
      'format',
      '$memProjectPath/lib/features/profile/profile.dart',
    ]);

    final (_, _, none) = await runHook([
      'format',
    ], '{"file_path":"$memProjectPath/pubspec.yaml"}');
    expect(none.calls, isEmpty);
  });
}
