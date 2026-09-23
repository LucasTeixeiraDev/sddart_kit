/// Operadores de shell que permitiriam encadear comandos não permitidos.
final _chaining = RegExp(r'[;&|`<>\n]|\$\(');

/// Decisão do guard: `null` = permitido; senão, o motivo do bloqueio.
String? guardBash(String? command, List<String> allow) {
  if (command == null) return null;
  final cmd = command.trim();
  if (_chaining.hasMatch(cmd)) {
    return 'bloqueado: encadeamento/redirecionamento não permitido '
        '(use um comando por vez)';
  }
  final allowed = allow.any((a) => cmd == a || cmd.startsWith('$a '));
  return allowed
      ? null
      : 'bloqueado: este agente só pode rodar ${allow.join(', ')}';
}
