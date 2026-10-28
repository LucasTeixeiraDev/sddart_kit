import 'package:file/file.dart';
import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/specs/spec_repository.dart';
import 'package:flutter_sdd/src/core/status/status_transitions.dart';
import 'package:flutter_sdd/src/infra/file_locker.dart';
import 'package:path/path.dart' as p;

/// Único escritor de `status.yaml`: relê sob lock, aplica e grava atomicamente.
class StatusStore {
  const StatusStore({
    required this.fs,
    required this.root,
    required this.locker,
  });

  final FileSystem fs;
  final String root;
  final FileLocker locker;

  Future<StatusSetResult> set(
    String specId,
    List<String> args,
    SddConfig config,
  ) {
    final path = p.join(root, specsDirName, specId, 'status.yaml');
    return locker.withLock(path, () async {
      final spec = SpecRepository(fs, root).load(specId);
      final result = applyStatusSet(spec, args, config);
      fs.file('$path.tmp')
        ..writeAsStringSync(result.status.serialize())
        ..renameSync(path);
      return result;
    });
  }
}
