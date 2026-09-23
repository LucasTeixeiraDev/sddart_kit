import 'dart:convert';

import 'package:flutter_sdd/flutter_sdd.dart';
import 'package:test/test.dart';

import '../helpers/test_env.dart';

void main() {
  Future<CliHarness> initialized() async {
    final cli = CliHarness(fixture: 'app_cubit');
    expect(await cli.run(['init', '-y']), ExitCodes.ok);
    return cli;
  }

  test('init já sincroniza; sync --check fica verde', () async {
    final cli = await initialized();
    expect(await cli.run(['sync', '--check']), ExitCodes.ok);
    expect(cli.out.toString(), contains('sync em dia'));
    expect(await cli.run(['sync']), ExitCodes.ok);
    expect(cli.out.toString(), contains('sync em dia'));
  });

  test('--check falha e lista mudanças quando desatualizado', () async {
    final cli = await initialized();
    cli.fs.file('$memProjectPath/.claude/agents/sdd-explorer.md').deleteSync();
    expect(await cli.run(['sync', '--check']), ExitCodes.failure);
    expect(
      cli.out.toString(),
      contains('write    .claude/agents/sdd-explorer.md'),
    );
    expect(cli.out.toString(), contains('1 mudanças pendentes'));
    // --check não escreve.
    expect(cli.exists('.claude/agents/sdd-explorer.md'), isFalse);

    expect(await cli.run(['--verbose', 'sync']), ExitCodes.ok);
    expect(cli.out.toString(), contains('sync: 1 escritos'));
    expect(cli.err.toString(), contains('.claude/agents/sdd-explorer.md'));
  });

  test('--json e conflitos retornam exit 1', () async {
    final cli = await initialized();
    cli.fs
        .file('$memProjectPath/.claude/agents/sdd-explorer.md')
        .writeAsStringSync('meu');
    expect(await cli.run(['--json', 'sync']), ExitCodes.failure);
    final doc = jsonDecode(cli.out.toString()) as Map<String, Object?>;
    expect(doc['up_to_date'], isFalse);
    expect(doc['changes'], [
      {
        'path': '.claude/agents/sdd-explorer.md',
        'action': 'conflict',
        'reason': 'arquivo do usuário sem o aviso do sdd; renomeie ou remova',
      },
    ]);
  });

  test('sem .sdd/ ou com kit/overrides inválidos: exit 2', () async {
    final none = CliHarness(fixture: 'app_cubit');
    expect(await none.run(['sync']), ExitCodes.usage);
    expect(none.err.toString(), contains('rode sdd init'));

    final cli = await initialized();
    cli.fs.file('$memProjectPath/.sdd/overrides/agents/x.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('---\n---\n');
    expect(await cli.run(['sync']), ExitCodes.usage);
    expect(cli.err.toString(), contains('kit/overrides inválidos'));
  });

  test('avisos de config são exibidos', () async {
    final cli = await initialized();
    final config = cli.fs.file('$memProjectPath/.sdd/config.yaml');
    config.writeAsStringSync('${config.readAsStringSync()}extra: 1\n');
    expect(await cli.run(['sync']), ExitCodes.ok);
    expect(cli.err.toString(), contains('extra: chave desconhecida'));
  });
}
