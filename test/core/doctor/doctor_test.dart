import 'package:file/file.dart';
import 'package:flutter_sdd/src/core/doctor/doctor.dart';
import 'package:flutter_sdd/src/core/kit/kit_locator.dart';
import 'package:flutter_sdd/src/infra/process_runner.dart';
import 'package:test/test.dart';

import '../../helpers/fake_process_runner.dart';
import '../../helpers/test_env.dart';

void main() {
  late FileSystem fs;
  late FakeProcessRunner runner;

  setUp(() {
    fs = memoryFs(fixture: 'app_cubit');
    runner = FakeProcessRunner();
  });

  Future<Map<String, DoctorCheck>> run({String? kitPath = memKitPath}) async {
    final checks = await Doctor(
      fs: fs,
      processRunner: runner,
      kitLocator: KitLocator(
        fs: fs,
        environment: const {},
        packageRoot: () async => null,
      ),
      cliVersion: '0.1.0',
    ).run(memProjectPath, kitPath: kitPath);
    return {for (final c in checks) c.name: c};
  }

  void writeSdd(String config, {String? lock}) {
    fs.file('$memProjectPath/.sdd/config.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync(config);
    if (lock != null) {
      fs.file('$memProjectPath/.sdd/kit.lock').writeAsStringSync(lock);
    }
  }

  test('ferramentas ausentes e fora de repo git', () async {
    runner.responses.addAll({
      'flutter': const ProcessOutput(ProcessOutput.notFound),
      'git rev-parse': const ProcessOutput(128),
      'dart': const ProcessOutput(0, stdout: 'Dart SDK version: 3.13.4\nx'),
      'git --version': const ProcessOutput(1),
    });
    final checks = await run();
    expect(checks['dart']!.message, 'Dart SDK version: 3.13.4');
    expect(checks['flutter']!.message, 'não encontrado no PATH');
    expect(checks['git']!.message, 'falhou (exit 1)');
    expect(checks['git repo']!.status, CheckStatus.fail);
    expect(checks['config']!.message, contains('rode sdd init'));
  });

  test('kit não encontrado', () async {
    final checks = await run(kitPath: null);
    expect(checks['kit']!.status, CheckStatus.fail);
  });

  test('stack inexistente', () async {
    writeSdd('kit: {stack: nope}');
    final checks = await run();
    expect(checks['stack']!.message, contains('"nope" não existe'));
  });

  test('config inválido e lock ausente', () async {
    writeSdd('kit: {stack: flutter-clean-cubit}\ntargets: [vim]');
    final checks = await run();
    expect(checks['stack']!.status, CheckStatus.ok);
    expect(checks['config']!.status, CheckStatus.fail);
    expect(checks['kit.lock']!.message, 'ausente; rode sdd init');
  });

  test('avisos de modelo (inherit no Cursor) e lock desatualizado', () async {
    writeSdd(
      'kit: {stack: flutter-clean-cubit}\n'
      'models: {deep: opus, standard: sonnet, fast: haiku}\n',
      lock: 'sdd_version: "0.0.1"\nstack: flutter-clean-cubit\nkit_hash: x\n',
    );
    final all = await Doctor(
      fs: fs,
      processRunner: runner,
      kitLocator: KitLocator(
        fs: fs,
        environment: const {},
        packageRoot: () async => null,
      ),
      cliVersion: '0.1.0',
    ).run(memProjectPath, kitPath: memKitPath);
    final models = all.where((c) => c.name == 'models').toList();
    expect(models, hasLength(3));
    expect(models.every((c) => c.status == CheckStatus.warn), isTrue);
    final lock = all.singleWhere((c) => c.name == 'kit.lock');
    expect(lock.status, CheckStatus.warn);
    expect(lock.toJson()['status'], 'warn');
  });

  test('dependências esperadas do stack: aviso, ou ok', () async {
    writeSdd('kit: {stack: flutter-clean-cubit}');
    var checks = await run();
    expect(checks['deps']!.status, CheckStatus.warn);
    expect(checks['deps']!.message, contains('meta'));
    final pubspec = fs.file('$memProjectPath/pubspec.yaml');
    pubspec.writeAsStringSync(
      pubspec.readAsStringSync().replaceFirst(
        'dependencies:\n',
        'dependencies:\n  meta: ^1.16.0\n',
      ),
    );
    checks = await run();
    expect(checks['deps']!.status, CheckStatus.ok);
    pubspec.deleteSync();
    checks = await run();
    expect(checks['deps']!.message, contains('pubspec.yaml não encontrado'));
  });

  test('lock ilegível e stack.yaml inválido', () async {
    writeSdd('kit: {stack: flutter-clean-cubit}', lock: 'x: [');
    expect((await run())['kit.lock']!.status, CheckStatus.fail);
    fs
        .file('$memKitPath/stacks/flutter-clean-cubit/stack.yaml')
        .writeAsStringSync('- a');
    expect((await run())['stack']!.status, CheckStatus.fail);
  });
}
