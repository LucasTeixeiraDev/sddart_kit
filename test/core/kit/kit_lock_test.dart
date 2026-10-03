import 'package:flutter_sdd/src/core/kit/kit_locator.dart';
import 'package:flutter_sdd/src/core/kit/kit_lock.dart';
import 'package:test/test.dart';

import '../../helpers/test_env.dart';

void main() {
  const lock = KitLock(sddVersion: '0.2.0', stack: 's', kitHash: 'abc');

  test('serialize/parse ida e volta', () {
    final parsed = KitLock.parse(lock.serialize());
    expect(parsed.sddVersion, '0.2.0');
    expect(parsed.stack, 's');
    expect(parsed.kitHash, 'abc');
  });

  test('parse rejeita conteúdo inválido', () {
    expect(() => KitLock.parse('a: ['), throwsFormatException);
    expect(() => KitLock.parse('sdd_version: 1'), throwsFormatException);
  });

  group('checkLock', () {
    LockStatus status(String cli, {String hash = 'abc'}) =>
        checkLock(lock, cliVersion: cli, kitHash: hash).status;

    test('mesma versão e hash', () => expect(status('0.2.0'), LockStatus.ok));
    test('CLI mais novo', () => expect(status('0.3.0'), LockStatus.outdated));
    test('lock mais novo que o CLI', () {
      final check = checkLock(lock, cliVersion: '0.1.9', kitHash: 'abc');
      expect(check.status, LockStatus.newerThanCli);
      expect(check.isError, isTrue);
    });
    test('kit alterado', () {
      expect(status('0.2.0', hash: 'zzz'), LockStatus.kitChanged);
    });
    test('versão inválida no lock', () {
      final bad = checkLock(
        const KitLock(sddVersion: 'x', stack: 's', kitHash: 'abc'),
        cliVersion: '0.2.0',
        kitHash: 'abc',
      );
      expect(bad.isError, isTrue);
    });
  });

  test('computeKitHash é determinístico e sensível a conteúdo', () {
    final fs = memoryFs();
    const kit = KitLocation(memKitPath, KitSource.flag);
    final a = computeKitHash(fs, kit, 'flutter-clean-cubit');
    expect(computeKitHash(fs, kit, 'flutter-clean-cubit'), a);
    expect(a, matches(RegExp(r'^[0-9a-f]{16}$')));
    // Conteúdos variados cobrem hashes com o bit mais alto ligado.
    final seen = <String>{a};
    for (var i = 0; i < 20; i++) {
      fs.file('$memKitPath/core/agents/novo.md').writeAsStringSync('x$i');
      final h = computeKitHash(fs, kit, 'flutter-clean-cubit');
      expect(h, matches(RegExp(r'^[0-9a-f]{16}$')));
      seen.add(h);
    }
    expect(seen, hasLength(21));
  });
}
