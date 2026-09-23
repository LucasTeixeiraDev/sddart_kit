import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Compara [files] (caminho → conteúdo) com `test/goldens/<name>.txt`.
/// Rode com `UPDATE_GOLDENS=1` para regravar.
void expectGolden(String name, Map<String, String> files) {
  final sorted = files.keys.toList()..sort();
  final actual = [
    for (final path in sorted) '=== $path ===\n${files[path]}',
  ].join('\n');
  final golden = File(p.join('test', 'goldens', '$name.txt'));
  if (Platform.environment['UPDATE_GOLDENS'] == '1' || !golden.existsSync()) {
    golden
      ..createSync(recursive: true)
      ..writeAsStringSync(actual);
    if (Platform.environment['UPDATE_GOLDENS'] != '1') {
      fail('golden $name criado; revise e rode de novo');
    }
    return;
  }
  expect(actual, golden.readAsStringSync(), reason: 'golden $name');
}
