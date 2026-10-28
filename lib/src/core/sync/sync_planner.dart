import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:file/file.dart';
import 'package:flutter_sdd/src/core/adapters/claude_adapter.dart';
import 'package:flutter_sdd/src/core/adapters/cursor_adapter.dart';
import 'package:flutter_sdd/src/core/adapters/generated_file.dart';
import 'package:flutter_sdd/src/core/adapters/tool_adapter.dart';
import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/kit/kit_lock.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:flutter_sdd/src/core/kit/template_renderer.dart';
import 'package:flutter_sdd/src/core/sync/json_hooks.dart';
import 'package:flutter_sdd/src/core/sync/managed_files.dart';
import 'package:flutter_sdd/src/core/sync/manifest.dart';
import 'package:path/path.dart' as p;

enum SyncAction { write, delete, conflict }

class SyncChange {
  const SyncChange(this.path, this.action, {this.bytes, this.reason});

  /// Caminho relativo à raiz do projeto.
  final String path;
  final SyncAction action;
  final List<int>? bytes;
  final String? reason;

  Map<String, Object?> toJson() => {
    'path': path,
    'action': action.name,
    if (reason != null) 'reason': reason,
  };
}

class SyncPlan {
  const SyncPlan(this.changes, this.warnings);

  final List<SyncChange> changes;
  final List<String> warnings;

  bool get upToDate => changes.isEmpty;

  Iterable<SyncChange> of(SyncAction action) =>
      changes.where((c) => c.action == action);
}

/// Diretórios onde o sync procura arquivos gerados órfãos.
const managedDirs = [
  '.sdd/templates',
  '.claude/agents',
  '.claude/skills',
  '.claude/rules',
  '.cursor/agents',
  '.cursor/skills',
  '.cursor/rules',
];

const manifestPath = '.sdd/generated.json';
const kitLockPath = '.sdd/kit.lock';
const agentsMdPath = 'AGENTS.md';
const claudeMdPath = 'CLAUDE.md';
const agentsSectionTemplate = 'agents-md-section.md';

/// Templates de fase exportados para `.sdd/templates/` (lidos pelos agentes,
/// que não têm acesso ao kit instalado). Não renderizados: são preenchidos
/// pelos agentes.
const exportedTemplates = [
  'analysis.md',
  'spec.md',
  'plan.md',
  'task.md',
  'review.md',
];

/// Calcula o que o `sdd sync` precisa escrever ou remover. Não escreve nada.
class SyncPlanner {
  const SyncPlanner({
    required this.fs,
    required this.root,
    required this.version,
  });

  final FileSystem fs;
  final String root;
  final String version;

  SyncPlan plan({
    required KitBundle bundle,
    required SddConfig config,
    required KitLock lock,
  }) {
    final vars = buildRenderVars(config, bundle, sddVersion: version);
    final rendered = renderBundle(bundle, vars);
    final changes = <SyncChange>[];
    final warnings = <String>{};
    final old = _readManifest();

    // 1. Arquivos gerados pelos adapters.
    final generated = <String, GeneratedFile>{};
    final hookRegs = <String, HookRegistration>{};
    final duplicates = <String>[];
    for (final adapter in _adapters(config)) {
      final output = adapter.generate(rendered, config);
      warnings.addAll(output.warnings);
      for (final file in output.files) {
        if (generated.containsKey(file.path)) duplicates.add(file.path);
        generated[file.path] = file;
      }
      for (final reg in output.hooks) {
        hookRegs[reg.path] = reg;
      }
    }
    for (final name in exportedTemplates) {
      final content = rendered.templates[name];
      if (content != null) {
        generated['.sdd/templates/$name'] = GeneratedFile.text(
          '.sdd/templates/$name',
          content,
        );
      }
    }
    if (duplicates.isNotEmpty) {
      throw KitException([
        for (final d in duplicates)
          'dois itens do kit geram o mesmo arquivo: $d',
      ]);
    }
    // Ferramentas fora dos targets: limpa entradas antigas do sdd.
    hookRegs
      ..putIfAbsent(
        '.claude/settings.json',
        () => const HookRegistration(
          '.claude/settings.json',
          HookStyle.claudeSettings,
          {},
        ),
      )
      ..putIfAbsent(
        '.cursor/hooks.json',
        () => const HookRegistration(
          '.cursor/hooks.json',
          HookStyle.cursorHooks,
          {},
        ),
      );

    for (final file in generated.values) {
      final change = _compareGenerated(file, old);
      if (change != null) changes.add(change);
    }

    // 2. Órfãos: gerados antes (manifesto ou marcador) e não mais desejados.
    for (final path in _orphanCandidates(old)) {
      if (generated.containsKey(path)) continue;
      final f = _file(path);
      if (!f.existsSync()) continue;
      final ours = supportsMarker(path)
          ? hasGeneratedMarker(_readText(f))
          : old.files.contains(path);
      if (ours) changes.add(SyncChange(path, SyncAction.delete));
    }

    // 3. Hooks em JSON do usuário.
    final createdJson = <String>{};
    for (final reg in hookRegs.values) {
      changes.addAll(_planHooks(reg, old, createdJson));
    }

    // 4. AGENTS.md e CLAUDE.md.
    final template = rendered.templates[agentsSectionTemplate];
    if (template == null) {
      throw const KitException([
        'template $agentsSectionTemplate ausente no kit',
      ]);
    }
    final missing = <String>[];
    final section = renderTemplate(template, {
      ...vars,
      'notice': generatedNotice(version),
    }, missing: missing);
    if (missing.isNotEmpty) {
      throw KitException([
        for (final m in missing)
          'templates/$agentsSectionTemplate: variável {{sdd:$m}} desconhecida',
      ]);
    }
    final agentsFile = _file(agentsMdPath);
    try {
      _addIfChanged(
        changes,
        agentsMdPath,
        applyManagedSection(
          agentsFile.existsSync() ? _readText(agentsFile) : null,
          section,
        ),
      );
    } on ManagedSectionException catch (e) {
      changes.add(
        SyncChange(agentsMdPath, SyncAction.conflict, reason: e.message),
      );
    }
    if (config.hasTarget(Target.claude)) {
      final claudeFile = _file(claudeMdPath);
      _addIfChanged(
        changes,
        claudeMdPath,
        ensureClaudeImport(
          claudeFile.existsSync() ? _readText(claudeFile) : null,
        ),
      );
    }

    // 5. Estado interno: manifesto e kit.lock.
    _addIfChanged(
      changes,
      manifestPath,
      GeneratedManifest(
        files: generated.keys.toSet(),
        createdJson: createdJson,
      ).serialize(),
    );
    _addIfChanged(changes, kitLockPath, lock.serialize());

    changes.sort((a, b) => a.path.compareTo(b.path));
    return SyncPlan(changes, warnings.toList()..sort());
  }

  List<ToolAdapter> _adapters(SddConfig config) => [
    for (final target in config.targets)
      switch (target) {
        Target.claude => ClaudeAdapter(version),
        Target.cursor => CursorAdapter(version),
      },
  ];

  SyncChange? _compareGenerated(GeneratedFile file, GeneratedManifest old) {
    final f = _file(file.path);
    if (!f.existsSync()) {
      return SyncChange(file.path, SyncAction.write, bytes: file.bytes);
    }
    final current = f.readAsBytesSync();
    if (const ListEquality<int>().equals(current, file.bytes)) return null;
    final ours = supportsMarker(file.path)
        ? hasGeneratedMarker(utf8.decode(current, allowMalformed: true))
        : old.files.contains(file.path);
    return ours
        ? SyncChange(file.path, SyncAction.write, bytes: file.bytes)
        : SyncChange(
            file.path,
            SyncAction.conflict,
            reason: 'arquivo do usuário sem o aviso do sdd; renomeie ou remova',
          );
  }

  Set<String> _orphanCandidates(GeneratedManifest old) {
    final candidates = <String>{...old.files};
    for (final dir in managedDirs) {
      final d = fs.directory(p.join(root, dir));
      if (!d.existsSync()) continue;
      for (final f in d.listSync(recursive: true).whereType<File>()) {
        candidates.add(p.relative(f.path, from: root));
      }
    }
    return candidates;
  }

  List<SyncChange> _planHooks(
    HookRegistration reg,
    GeneratedManifest old,
    Set<String> createdJson,
  ) {
    final f = _file(reg.path);
    Map<String, Object?>? existing;
    if (f.existsSync()) {
      try {
        final decoded = jsonDecode(_readText(f));
        if (decoded is! Map<String, Object?>) throw const FormatException();
        existing = decoded;
      } on FormatException {
        return [
          if (reg.entries.isNotEmpty)
            SyncChange(
              reg.path,
              SyncAction.conflict,
              reason: 'JSON inválido; corrija para o sdd registrar hooks',
            ),
        ];
      }
    }
    final merged = mergeHooks(existing ?? const {}, reg);
    final empty = isEffectivelyEmpty(merged, reg.style);
    if (existing == null) {
      if (empty) return const [];
      createdJson.add(reg.path);
      return [SyncChange(reg.path, SyncAction.write, bytes: _json(merged))];
    }
    final wasCreated = old.createdJson.contains(reg.path);
    if (empty && wasCreated) return [SyncChange(reg.path, SyncAction.delete)];
    if (wasCreated) createdJson.add(reg.path);
    if (const DeepCollectionEquality().equals(existing, merged)) {
      return const [];
    }
    return [SyncChange(reg.path, SyncAction.write, bytes: _json(merged))];
  }

  void _addIfChanged(List<SyncChange> changes, String path, String content) {
    final f = _file(path);
    if (f.existsSync() && _readText(f) == content) return;
    changes.add(
      SyncChange(path, SyncAction.write, bytes: utf8.encode(content)),
    );
  }

  GeneratedManifest _readManifest() {
    final f = _file(manifestPath);
    return f.existsSync()
        ? GeneratedManifest.parse(_readText(f))
        : const GeneratedManifest();
  }

  File _file(String relative) => fs.file(p.join(root, relative));

  String _readText(File f) =>
      utf8.decode(f.readAsBytesSync(), allowMalformed: true);

  List<int> _json(Map<String, Object?> doc) =>
      utf8.encode('${const JsonEncoder.withIndent('  ').convert(doc)}\n');
}

/// Aplica o plano (exceto conflitos) e remove diretórios que ficaram vazios.
void applySyncPlan(FileSystem fs, String root, SyncPlan plan) {
  for (final change in plan.changes) {
    final file = fs.file(p.join(root, change.path));
    switch (change.action) {
      case SyncAction.write:
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(change.bytes!);
      case SyncAction.delete:
        file.deleteSync();
        _pruneEmptyDirs(fs, root, file.parent);
      case SyncAction.conflict:
        break;
    }
  }
}

void _pruneEmptyDirs(FileSystem fs, String root, Directory dir) {
  final stops = {
    p.normalize(root),
    for (final d in managedDirs) p.normalize(p.join(root, d)),
  };
  var current = dir;
  while (!stops.contains(p.normalize(current.path)) &&
      current.existsSync() &&
      current.listSync().isEmpty) {
    current.deleteSync();
    current = current.parent;
  }
}
