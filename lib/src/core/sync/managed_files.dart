/// Marcadores da seção gerenciada do AGENTS.md.
const sectionBegin = '<!-- sdd:begin -->';
const sectionEnd = '<!-- sdd:end -->';

class ManagedSectionException implements Exception {
  const ManagedSectionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Substitui (ou acrescenta) a seção entre os marcadores, preservando o resto.
String applyManagedSection(String? existing, String section) {
  final block = '$sectionBegin\n${section.trim()}\n$sectionEnd';
  if (existing == null || existing.trim().isEmpty) return '$block\n';
  final begin = existing.indexOf(sectionBegin);
  final end = existing.indexOf(sectionEnd);
  if (begin == -1 && end == -1) return '${existing.trimRight()}\n\n$block\n';
  if (begin == -1 || end == -1 || end < begin) {
    throw const ManagedSectionException(
      'AGENTS.md com marcadores sdd incompletos ou fora de ordem',
    );
  }
  return existing.replaceRange(begin, end + sectionEnd.length, block);
}

const claudeImportLine = '@AGENTS.md';

/// CLAUDE.md: cria com o import, ou garante a linha no arquivo existente.
String ensureClaudeImport(String? existing) {
  if (existing == null || existing.trim().isEmpty) return '$claudeImportLine\n';
  final hasLine = existing.split('\n').any((l) => l.trim() == claudeImportLine);
  return hasLine ? existing : '${existing.trimRight()}\n\n$claudeImportLine\n';
}
