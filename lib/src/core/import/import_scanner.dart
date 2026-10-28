import 'dart:convert';

import 'package:file/file.dart';
import 'package:flutter_sdd/src/core/adapters/generated_file.dart';
import 'package:flutter_sdd/src/core/kit/frontmatter.dart';
import 'package:flutter_sdd/src/core/util/hash.dart';
import 'package:path/path.dart' as p;

enum ImportTool { claude, cursor, generic }

enum ImportKind { agent, skill, rule, command, memory }

/// Possível duplicata de um item (outra ferramenta, mesmo conteúdo...).
class ImportDuplicate {
  const ImportDuplicate(this.path, this.reason, [this.similarity]);

  final String path;

  /// `same_name`, `same_content` ou `similar`.
  final String reason;
  final double? similarity;

  Map<String, Object?> toJson() => {
    'path': path,
    'reason': reason,
    if (similarity != null)
      'similarity': double.parse(similarity!.toStringAsFixed(2)),
  };
}

class ImportItem {
  ImportItem({
    required this.path,
    required this.tool,
    required this.kind,
    required this.name,
    required this.bytes,
    required this.lines,
    required this.hash,
    required this.normalizedLines,
    this.description,
    this.supportFiles = const [],
  });

  /// Relativo à raiz escaneada.
  final String path;
  final ImportTool tool;
  final ImportKind kind;
  final String name;
  final String? description;
  final int bytes;
  final int lines;

  /// Hash do corpo normalizado (sem frontmatter, espaços e caixa).
  final String hash;

  /// Arquivos de apoio (skills), relativos à raiz.
  final List<String> supportFiles;
  final Set<String> normalizedLines;
  final List<ImportDuplicate> duplicates = [];

  Map<String, Object?> toJson() => {
    'path': path,
    'tool': tool.name,
    'kind': kind.name,
    'name': name,
    if (description != null) 'description': description,
    'bytes': bytes,
    'lines': lines,
    'hash': hash,
    if (supportFiles.isNotEmpty) 'support_files': supportFiles,
    if (duplicates.isNotEmpty)
      'duplicates': [for (final d in duplicates) d.toJson()],
  };
}

class ImportScan {
  const ImportScan(this.root, this.items, this.skippedGenerated);

  final String root;
  final List<ImportItem> items;

  /// Arquivos gerados pelo próprio sdd (ignorados).
  final List<String> skippedGenerated;

  Map<String, Object?> toJson() => {
    'source': root,
    'summary': {
      for (final k in ImportKind.values)
        k.name: items.where((i) => i.kind == k).length,
    },
    'items': [for (final i in items) i.toJson()],
    'skipped_generated': skippedGenerated,
  };
}

const _ignoredDirs = {'.git', '.dart_tool', 'build', 'node_modules', '.sdd'};

/// Limiar de similaridade (Jaccard de linhas normalizadas) para duplicata.
const similarityThreshold = 0.8;

/// Inventário determinístico e somente leitura de agentes, skills, rules,
/// comandos e memória (Claude, Cursor ou repositório de conteúdo).
ImportScan scanImportSource(FileSystem fs, String root) {
  final items = <ImportItem>[];
  final skipped = <String>[];
  final rootDir = fs.directory(root);
  if (!rootDir.existsSync()) {
    throw FileSystemException('caminho não existe', root);
  }

  final files = <String>[];
  void walk(Directory dir) {
    for (final e in dir.listSync()) {
      final name = p.basename(e.path);
      if (e is Directory) {
        if (!_ignoredDirs.contains(name)) walk(e);
      } else if (e is File) {
        files.add(p.relative(e.path, from: root).replaceAll(r'\', '/'));
      }
    }
  }

  walk(rootDir);
  files.sort();

  final skillDirs = {
    for (final f in files)
      if (p.posix.basename(f) == 'SKILL.md') p.posix.dirname(f),
  };

  for (final rel in files) {
    final kind = _kindOf(rel, skillDirs);
    if (kind == null) continue;
    final content = utf8.decode(
      fs.file(p.join(root, rel)).readAsBytesSync(),
      allowMalformed: true,
    );
    if (hasGeneratedMarker(content)) {
      skipped.add(rel);
      continue;
    }
    FrontmatterDoc doc;
    try {
      doc = parseFrontmatter(content);
    } on FormatException {
      doc = FrontmatterDoc(const {}, content);
    }
    final normalized = _normalizedLines(doc.body);
    final skillDir = kind == ImportKind.skill ? p.posix.dirname(rel) : null;
    items.add(
      ImportItem(
        path: rel,
        tool: _toolOf(rel, doc.data),
        kind: kind,
        name: _nameOf(rel, kind, doc.data),
        description: doc.data['description']?.toString().trim(),
        bytes: utf8.encode(content).length,
        lines: '\n'.allMatches(content).length + 1,
        hash: fnv1a64Hex(utf8.encode(normalized.join('\n'))),
        normalizedLines: normalized.toSet(),
        supportFiles: skillDir == null
            ? const []
            : [
                for (final f in files)
                  if (f != rel && p.posix.isWithin(skillDir, f)) f,
              ],
      ),
    );
  }

  _markDuplicates(items);
  return ImportScan(root, items, skipped);
}

ImportKind? _kindOf(String rel, Set<String> skillDirs) {
  final base = p.posix.basename(rel);
  final segments = p.posix.split(rel);
  if (base == 'CLAUDE.md' || base == 'AGENTS.md' || base == 'CLAUDE.local.md') {
    return ImportKind.memory;
  }
  if (base == '.cursorrules') return ImportKind.rule;
  if (base == 'SKILL.md') return ImportKind.skill;
  // Arquivos de apoio de skills não são itens próprios.
  if (skillDirs.any((d) => p.posix.isWithin(d, rel))) return null;
  final ext = p.posix.extension(rel);
  if (ext == '.mdc') return ImportKind.rule;
  if (ext != '.md') return null;
  final dirs = segments.sublist(0, segments.length - 1);
  if (dirs.contains('agents')) return ImportKind.agent;
  if (dirs.contains('commands')) return ImportKind.command;
  if (dirs.contains('rules')) return ImportKind.rule;
  return null;
}

ImportTool _toolOf(String rel, Map<String, Object?> data) {
  final segments = p.posix.split(rel);
  if (segments.contains('.claude') || segments.contains('claude')) {
    return ImportTool.claude;
  }
  if (segments.contains('.cursor') ||
      segments.contains('cursor') ||
      rel.endsWith('.mdc') ||
      rel.endsWith('.cursorrules')) {
    return ImportTool.cursor;
  }
  if (p.posix.basename(rel).startsWith('CLAUDE')) return ImportTool.claude;
  if (data.containsKey('alwaysApply') || data['globs'] is String) {
    return ImportTool.cursor;
  }
  if (data.containsKey('paths') ||
      data.containsKey('allowed-tools') ||
      data['tools'] is String) {
    return ImportTool.claude;
  }
  return ImportTool.generic;
}

String _nameOf(String rel, ImportKind kind, Map<String, Object?> data) {
  final declared = data['name'];
  if (declared is String && declared.trim().isNotEmpty) return declared.trim();
  if (kind == ImportKind.skill) return p.posix.basename(p.posix.dirname(rel));
  return p.posix.basenameWithoutExtension(rel).replaceFirst(RegExp(r'^\.'), '');
}

final _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

List<String> _normalizedLines(String body) => [
  for (final line in body.toLowerCase().split('\n'))
    if (line.replaceAll(_nonWord, ' ').trim() case final l when l.isNotEmpty) l,
];

/// Mesmo nome (mesmo tipo), mesmo conteúdo normalizado ou Jaccard de linhas
/// >= [similarityThreshold].
void _markDuplicates(List<ImportItem> items) {
  for (var i = 0; i < items.length; i++) {
    for (var j = i + 1; j < items.length; j++) {
      final a = items[i];
      final b = items[j];
      ImportDuplicate dup(ImportItem other, String reason, [double? s]) =>
          ImportDuplicate(other.path, reason, s);
      String? reason;
      double? similarity;
      if (a.hash == b.hash && a.normalizedLines.isNotEmpty) {
        reason = 'same_content';
      } else if (a.kind == b.kind &&
          a.name.toLowerCase() == b.name.toLowerCase()) {
        reason = 'same_name';
      } else {
        final union = a.normalizedLines.union(b.normalizedLines).length;
        if (union > 0) {
          final s =
              a.normalizedLines.intersection(b.normalizedLines).length / union;
          if (s >= similarityThreshold) {
            reason = 'similar';
            similarity = s;
          }
        }
      }
      if (reason != null) {
        a.duplicates.add(dup(b, reason, similarity));
        b.duplicates.add(dup(a, reason, similarity));
      }
    }
  }
}
