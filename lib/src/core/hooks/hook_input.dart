import 'dart:convert';

/// Payload de hook recebido via stdin (Claude Code ou Cursor).
class HookInput {
  const HookInput(this.data);

  /// Faz o parse tolerante: entrada inválida vira payload vazio.
  factory HookInput.parse(String source) {
    try {
      final raw = jsonDecode(source);
      if (raw is Map<String, Object?>) return HookInput(raw);
    } on FormatException {
      // Sem payload utilizável.
    }
    return const HookInput({});
  }

  final Map<String, Object?> data;

  Map<String, Object?> get _toolInput =>
      data['tool_input'] is Map<String, Object?>
      ? data['tool_input']! as Map<String, Object?>
      : const {};

  String? get toolName => data['tool_name'] as String?;

  /// Comando Bash (Claude: `tool_input.command`).
  String? get command => _toolInput['command'] as String?;

  /// Arquivo editado (Claude: `tool_input.file_path`; Cursor: `file_path`).
  String? get filePath =>
      _toolInput['file_path'] as String? ?? data['file_path'] as String?;
}
