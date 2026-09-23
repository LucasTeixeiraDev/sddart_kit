import 'package:file/file.dart';
import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/kit/frontmatter.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:path/path.dart' as p;

/// Uma camada do kit: diretório com `agents/`, `skills/`, `rules/`,
/// `commands/` e `templates/`.
class KitLayerDir {
  const KitLayerDir(this.layer, this.path);

  final KitLayer layer;
  final String path;
}

final _namePattern = RegExp(r'^[a-z0-9][a-z0-9-]*$');
const _ignored = {'.gitkeep', '.DS_Store'};

/// Carrega e resolve as camadas: itens de mesmo nome em camadas posteriores
/// substituem os anteriores; `disabled: true` remove o item.
class KitLoader {
  KitLoader(this.fs);

  final FileSystem fs;
  final _issues = <String>[];

  KitBundle load(List<KitLayerDir> layers) {
    _issues.clear();
    final agents = <String, KitAgent>{};
    final skills = <String, KitSkill>{};
    final rules = <String, KitRule>{};
    final commands = <String, KitCommand>{};
    final templates = <String, String>{};

    for (final layer in layers) {
      _loadMarkdown(layer, 'agents', agents, _agent);
      _loadMarkdown(layer, 'rules', rules, _rule);
      _loadMarkdown(layer, 'commands', commands, _command);
      _loadSkills(layer, skills);
      _loadTemplates(layer, templates);
    }

    for (final agent in agents.values) {
      for (final skill in agent.skills) {
        if (!skills.containsKey(skill)) {
          _issues.add('${agent.sourcePath}: skill "$skill" não existe no kit');
        }
      }
    }
    if (_issues.isNotEmpty) throw KitException([..._issues]);

    List<T> sorted<T extends KitItem>(Map<String, T> m) =>
        m.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return KitBundle(
      agents: sorted(agents),
      skills: sorted(skills),
      rules: sorted(rules),
      commands: sorted(commands),
      templates: Map.fromEntries(
        templates.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      ),
    );
  }

  // ---- descoberta -----------------------------------------------------------

  void _loadMarkdown<T extends KitItem>(
    KitLayerDir layer,
    String kind,
    Map<String, T> into,
    T? Function(_Source) parse,
  ) {
    final dir = fs.directory(p.join(layer.path, kind));
    if (!dir.existsSync()) return;
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => p.extension(f.path) == '.md')
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final name = p.basenameWithoutExtension(file.path);
      final source = _read(layer, file.path, name);
      if (source == null) continue;
      if (source.data['disabled'] == true) {
        into.remove(name);
        continue;
      }
      final item = parse(source);
      if (item != null) into[name] = item;
    }
  }

  void _loadSkills(KitLayerDir layer, Map<String, KitSkill> into) {
    final dir = fs.directory(p.join(layer.path, 'skills'));
    if (!dir.existsSync()) return;
    final skillDirs = dir.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final skillDir in skillDirs) {
      final name = p.basename(skillDir.path);
      final main = p.join(skillDir.path, 'SKILL.md');
      if (!fs.file(main).existsSync()) {
        _issues.add('${skillDir.path}: SKILL.md ausente');
        continue;
      }
      final source = _read(layer, main, name);
      if (source == null) continue;
      if (source.data['disabled'] == true) {
        into.remove(name);
        continue;
      }
      final description = _requiredString(source, 'description');
      if (description == null) continue;
      final files = <SkillFile>[
        for (final f in skillDir.listSync(recursive: true).whereType<File>())
          if (f.path != main && !_ignored.contains(p.basename(f.path)))
            SkillFile(
              p.relative(f.path, from: skillDir.path),
              f.readAsBytesSync(),
            ),
      ]..sort((a, b) => a.relativePath.compareTo(b.relativePath));
      into[name] = KitSkill(
        name: name,
        description: description,
        body: source.body,
        layer: layer.layer,
        sourcePath: main,
        files: files,
      );
    }
  }

  void _loadTemplates(KitLayerDir layer, Map<String, String> into) {
    final dir = fs.directory(p.join(layer.path, 'templates'));
    if (!dir.existsSync()) return;
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (_ignored.contains(p.basename(f.path))) continue;
      into[p.relative(f.path, from: dir.path)] = f.readAsStringSync();
    }
  }

  _Source? _read(KitLayerDir layer, String path, String name) {
    if (!_namePattern.hasMatch(name)) {
      _issues.add('$path: nome "$name" inválido (use a-z, 0-9 e -)');
      return null;
    }
    try {
      final doc = parseFrontmatter(fs.file(path).readAsStringSync());
      final declared = doc.data['name'];
      if (declared != null && declared != name) {
        _issues.add('$path: name "$declared" difere do nome do arquivo');
        return null;
      }
      return _Source(layer.layer, path, name, doc.data, doc.body);
    } on FormatException catch (e) {
      _issues.add('$path: ${e.message}');
      return null;
    }
  }

  // ---- parse por tipo -------------------------------------------------------

  KitAgent? _agent(_Source s) {
    final description = _requiredString(s, 'description');
    final tier = _tier(s, s.data['tier'], 'tier');
    final variants = <Tier>[];
    for (final v in _stringList(s, 'tier_variants') ?? const <String>[]) {
      final t = _tier(s, v, 'tier_variants');
      if (t != null) variants.add(t);
    }
    final tools = <AbstractTool>[];
    final toolNames = _stringList(s, 'tools', required: true);
    for (final name in toolNames ?? const <String>[]) {
      final tool = AbstractTool.tryParse(name);
      if (tool == null) {
        _issues.add(
          '${s.path}: tool "$name" inválida '
          '(use ${AbstractTool.values.map((t) => t.name).join(', ')})',
        );
      } else {
        tools.add(tool);
      }
    }
    final readonly = s.data['readonly'] ?? false;
    if (readonly is! bool) {
      _issues.add('${s.path}: readonly deve ser booleano');
      return null;
    }
    if (readonly &&
        (tools.contains(AbstractTool.edit) ||
            tools.contains(AbstractTool.write))) {
      _issues.add('${s.path}: agente readonly não pode ter edit/write');
    }
    final bashAllow = _stringList(s, 'bash_allow') ?? const [];
    if (bashAllow.isNotEmpty && !tools.contains(AbstractTool.bash)) {
      _issues.add('${s.path}: bash_allow exige a tool bash');
    }
    final skills = _stringList(s, 'skills') ?? const [];
    if (description == null || tier == null || toolNames == null) return null;
    return KitAgent(
      name: s.name,
      description: description,
      body: s.body,
      layer: s.layer,
      sourcePath: s.path,
      tier: tier,
      tierVariants: variants,
      tools: tools,
      readonly: readonly,
      skills: skills,
      bashAllow: bashAllow,
    );
  }

  KitRule? _rule(_Source s) {
    final description = _requiredString(s, 'description');
    final globs = _stringList(s, 'globs') ?? const [];
    final always = s.data['always'] ?? false;
    if (always is! bool) {
      _issues.add('${s.path}: always deve ser booleano');
      return null;
    }
    if (!always && globs.isEmpty) {
      _issues.add('${s.path}: rule precisa de globs ou always: true');
      return null;
    }
    if (description == null) return null;
    return KitRule(
      name: s.name,
      description: description,
      body: s.body,
      layer: s.layer,
      sourcePath: s.path,
      globs: globs,
      always: always,
    );
  }

  KitCommand? _command(_Source s) {
    final description = _requiredString(s, 'description');
    final args = s.data['args'];
    if (args != null && args is! String) {
      _issues.add('${s.path}: args deve ser string');
      return null;
    }
    if (description == null) return null;
    return KitCommand(
      name: s.name,
      description: description,
      body: s.body,
      layer: s.layer,
      sourcePath: s.path,
      args: args as String?,
    );
  }

  // ---- helpers --------------------------------------------------------------

  String? _requiredString(_Source s, String key) {
    final value = s.data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    _issues.add('${s.path}: "$key" obrigatório (string)');
    return null;
  }

  List<String>? _stringList(_Source s, String key, {bool required = false}) {
    final value = s.data[key];
    if (value == null) {
      if (required) _issues.add('${s.path}: "$key" obrigatório (lista)');
      return null;
    }
    if (value is List<Object?> && value.every((e) => e is String)) {
      return value.cast<String>();
    }
    _issues.add('${s.path}: "$key" deve ser lista de strings');
    return null;
  }

  Tier? _tier(_Source s, Object? value, String key) {
    final tier = value is String ? Tier.tryParse(value) : null;
    if (tier == null) {
      _issues.add(
        '${s.path}: $key "$value" inválido (use deep, standard, fast)',
      );
    }
    return tier;
  }
}

class _Source {
  const _Source(this.layer, this.path, this.name, this.data, this.body);

  final KitLayer layer;
  final String path;
  final String name;
  final Map<String, Object?> data;
  final String body;
}
