import 'package:file/file.dart';
import 'package:flutter_sdd/src/core/config/yaml_utils.dart';
import 'package:flutter_sdd/src/core/config/yaml_writer.dart';
import 'package:flutter_sdd/src/core/kit/kit_locator.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

/// `.sdd/kit.lock`: versão do sdd e hash do kit usados no último sync.
class KitLock {
  const KitLock({
    required this.sddVersion,
    required this.stack,
    required this.kitHash,
  });

  factory KitLock.parse(String source) {
    final Object? raw;
    try {
      raw = loadPlainYaml(source);
    } on YamlException catch (e) {
      throw FormatException('kit.lock inválido: ${e.message}');
    }
    if (raw is! Map<String, Object?> ||
        raw['sdd_version'] is! String ||
        raw['stack'] is! String ||
        raw['kit_hash'] is! String) {
      throw const FormatException(
        'kit.lock inválido: esperado sdd_version, stack e kit_hash',
      );
    }
    return KitLock(
      sddVersion: raw['sdd_version']! as String,
      stack: raw['stack']! as String,
      kitHash: raw['kit_hash']! as String,
    );
  }

  final String sddVersion;
  final String stack;
  final String kitHash;

  String serialize() {
    final body = toYaml({
      'sdd_version': sddVersion,
      'stack': stack,
      'kit_hash': kitHash,
    });
    return '# gerado por sdd — não edite\n$body';
  }
}

enum LockStatus { ok, outdated, newerThanCli, kitChanged }

class LockCheck {
  const LockCheck(this.status, this.message);

  final LockStatus status;
  final String message;

  bool get isError => status == LockStatus.newerThanCli;
}

/// Compara o lock do projeto com o sdd/kit em execução.
LockCheck checkLock(
  KitLock lock, {
  required String cliVersion,
  required String kitHash,
}) {
  final Version locked;
  final Version current;
  try {
    locked = Version.parse(lock.sddVersion);
    current = Version.parse(cliVersion);
  } on FormatException {
    return LockCheck(
      LockStatus.newerThanCli,
      'versão inválida no kit.lock: ${lock.sddVersion}',
    );
  }
  if (locked > current) {
    return LockCheck(
      LockStatus.newerThanCli,
      'kit.lock gerado com sdd ${lock.sddVersion}, mais novo que o instalado '
      '($cliVersion); atualize o sdd',
    );
  }
  if (locked < current) {
    return LockCheck(
      LockStatus.outdated,
      'kit.lock de sdd ${lock.sddVersion}, instalado $cliVersion; rode '
      'sdd sync',
    );
  }
  if (lock.kitHash != kitHash) {
    return const LockCheck(
      LockStatus.kitChanged,
      'conteúdo do kit mudou desde o último sync; rode sdd sync',
    );
  }
  return LockCheck(LockStatus.ok, 'sdd ${lock.sddVersion}');
}

/// Hash determinístico (FNV-1a 64) de `core/` + `stacks/<stack>/` do kit.
String computeKitHash(FileSystem fs, KitLocation kit, String stack) {
  final roots = [p.join(kit.path, 'core'), kit.stackPath(stack)];
  final files = <String>[
    for (final root in roots)
      if (fs.directory(root).existsSync())
        for (final e in fs.directory(root).listSync(recursive: true))
          if (e is File) e.path,
  ]..sort();
  // CLI só roda na VM (ints de 64 bits); nunca compilado para JS.
  // ignore: avoid_js_rounded_ints
  var hash = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  void add(List<int> bytes) {
    for (final b in bytes) {
      hash = (hash ^ b) * prime;
    }
  }

  for (final file in files) {
    add(p.relative(file, from: kit.path).codeUnits);
    add(const [0]);
    add(fs.file(file).readAsBytesSync());
    add(const [0]);
  }
  return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
}
