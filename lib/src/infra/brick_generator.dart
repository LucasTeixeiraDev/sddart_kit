import 'dart:io' as io;

import 'package:mason/mason.dart' as mason;
import 'package:path/path.dart' as p;

enum BrickFileStatus { created, overwritten, skipped, identical }

class BrickFile {
  const BrickFile(this.path, this.status);

  /// Relativo ao diretório de destino.
  final String path;
  final BrickFileStatus status;
}

/// Geração de bricks (injetável; a real usa a API do mason).
abstract interface class BrickGenerator {
  /// Nunca sobrescreve arquivos existentes (conflitos ficam `skipped`).
  Future<List<BrickFile>> generate({
    required String brickPath,
    required String targetDir,
    required Map<String, Object?> vars,
  });
}

class MasonBrickGenerator implements BrickGenerator {
  const MasonBrickGenerator();

  @override
  Future<List<BrickFile>> generate({
    required String brickPath,
    required String targetDir,
    required Map<String, Object?> vars,
  }) async {
    final generator = await mason.MasonGenerator.fromBrick(
      mason.Brick.path(brickPath),
    );
    final files = await generator.generate(
      mason.DirectoryGeneratorTarget(io.Directory(targetDir)),
      vars: vars,
      fileConflictResolution: mason.FileConflictResolution.skip,
      logger: mason.Logger(level: mason.Level.quiet),
    );
    return [
      for (final f in files)
        BrickFile(
          p.relative(f.path, from: targetDir).replaceAll(r'\', '/'),
          switch (f.status) {
            mason.GeneratedFileStatus.created => BrickFileStatus.created,
            mason.GeneratedFileStatus.overwritten ||
            mason.GeneratedFileStatus.appended => BrickFileStatus.overwritten,
            mason.GeneratedFileStatus.skipped => BrickFileStatus.skipped,
            mason.GeneratedFileStatus.identical => BrickFileStatus.identical,
          },
        ),
    ]..sort((a, b) => a.path.compareTo(b.path));
  }
}
