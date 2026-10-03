import 'package:path/path.dart' as p;

/// Caminho relativo à raiz do projeto, em estilo posix (quando possível).
String relativeToRoot(String path, String root) {
  var result = path;
  if (path.startsWith('file://')) result = Uri.parse(path).toFilePath();
  if (p.isAbsolute(result) && p.isWithin(root, result)) {
    result = p.relative(result, from: root);
  }
  return result.replaceAll(r'\', '/');
}

/// Encurta [text] para no máximo [max] caracteres.
String truncate(String text, [int max = 160]) {
  final oneLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return oneLine.length <= max ? oneLine : '${oneLine.substring(0, max - 1)}…';
}
