import 'dart:io' as io;

import 'package:flutter_sdd/src/core/specs/spec_repository.dart';
import 'package:flutter_sdd/src/core/status/spec_status.dart';
import 'package:flutter_sdd/src/core/status/status_store.dart';
import 'package:flutter_sdd/src/infra/file_locker.dart';
import 'package:test/test.dart';

import '../../helpers/task_builders.dart';
import '../../helpers/test_env.dart';

void main() {
  test('escreve atomicamente e serializa escritas concorrentes', () async {
    final fs = memoryFs(fixture: 'app_with_spec');
    final store = StatusStore(
      fs: fs,
      root: memProjectPath,
      locker: InProcessFileLocker(),
    );
    const id = '0001-login-biometria';
    await store.set(id, ['T01', 'in_progress'], testConfig());
    await store.set(id, ['T01', 'done'], testConfig());
    // Três mudanças em paralelo: nenhuma pode se perder.
    await Future.wait([
      store.set(id, ['T02', 'in_progress'], testConfig()),
      store.set(id, ['T03', 'in_progress'], testConfig()),
      store.set(id, ['review', 'pending', 'blockers=1'], testConfig()),
    ]);
    final status = SpecRepository(fs, memProjectPath).load(id).status;
    expect(status.task('T01').state, TaskState.done);
    expect(status.task('T02').state, TaskState.inProgress);
    expect(status.task('T03').state, TaskState.inProgress);
    expect(status.review.blockers, 1);
    expect(
      fs.file('$memProjectPath/specs/$id/status.yaml.tmp').existsSync(),
      isFalse,
    );
  });

  test('InProcessFileLocker continua após erro', () async {
    final locker = InProcessFileLocker();
    await expectLater(
      locker.withLock('x', () async => throw StateError('falhou')),
      throwsStateError,
    );
    expect(await locker.withLock('x', () async => 42), 42);
  });

  test('IoFileLocker executa o corpo e libera o lock', () async {
    final dir = io.Directory.systemTemp.createTempSync('sdd-lock-test');
    addTearDown(() => dir.deleteSync(recursive: true));
    const locker = IoFileLocker();
    final path = '${dir.path}/status.yaml';
    expect(await locker.withLock(path, () async => 'a'), 'a');
    expect(await locker.withLock(path, () async => 'b'), 'b');
  });
}
