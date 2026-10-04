import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

/// Decisão do guard de escrita: `null` = permitido; senão, o motivo.
/// [path] pode ser absoluto (relativizado a [root]) ou relativo à raiz.
String? guardWrite(String? path, List<String> allow, {required String root}) {
  if (path == null) return null;
  final relative = p.isAbsolute(path)
      ? p.relative(path, from: root).replaceAll(r'\', '/')
      : p.posix.normalize(path.replaceAll(r'\', '/'));
  final allowed =
      !relative.startsWith('../') &&
      allow.any((g) => Glob(g, context: p.posix).matches(relative));
  return allowed
      ? null
      : 'bloqueado: este agente só pode gravar ${allow.join(', ')} '
            '(tentou $relative)';
}
