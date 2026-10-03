import 'package:flutter_sdd/src/core/gates/parsers/paths.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

/// Cobertura de um arquivo no lcov.
class FileCoverage {
  const FileCoverage(this.path, this.hit, this.found);

  final String path;
  final int hit;
  final int found;

  double get percent => found == 0 ? 100 : hit * 100 / found;
}

/// Faz o parse de `lcov.info` (linhas `SF:` e `DA:`).
List<FileCoverage> parseLcov(String content, String root) {
  final result = <FileCoverage>[];
  String? file;
  var hit = 0;
  var found = 0;
  for (final raw in content.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('SF:')) {
      file = relativeToRoot(line.substring(3), root);
      hit = 0;
      found = 0;
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length < 2) continue;
      found++;
      if ((int.tryParse(parts[1]) ?? 0) > 0) hit++;
    } else if (line == 'end_of_record' && file != null) {
      result.add(FileCoverage(file, hit, found));
      file = null;
    }
  }
  return result;
}

/// Arquivos cobertos por algum dos [globs] (caminhos posix relativos).
List<FileCoverage> filterCoverage(
  List<FileCoverage> files,
  List<String> globs,
) {
  final matchers = [for (final g in globs) Glob(g, context: p.posix)];
  return [
    for (final f in files)
      if (matchers.any((m) => m.matches(f.path))) f,
  ];
}

/// Percentual agregado (linhas cobertas / linhas instrumentadas).
double totalPercent(List<FileCoverage> files) {
  final found = files.fold(0, (n, f) => n + f.found);
  final hit = files.fold(0, (n, f) => n + f.hit);
  return found == 0 ? 100 : hit * 100 / found;
}
