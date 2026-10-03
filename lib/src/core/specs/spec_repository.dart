import 'package:file/file.dart';
import 'package:flutter_sdd/src/core/specs/slug.dart';
import 'package:flutter_sdd/src/core/status/spec_status.dart';
import 'package:flutter_sdd/src/core/tasks/task.dart';
import 'package:path/path.dart' as p;

const specsDirName = 'specs';
final _specDirPattern = RegExp(r'^(\d{4})-[a-z0-9-]+$');

class SpecNotFoundException implements Exception {
  const SpecNotFoundException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Spec carregada do disco.
class SpecDir {
  const SpecDir({
    required this.id,
    required this.path,
    required this.tasks,
    required this.taskIssues,
    required this.status,
    this.specMd,
  });

  /// `NNNN-slug`.
  final String id;

  /// Caminho relativo à raiz (`specs/NNNN-slug`).
  final String path;
  final List<TaskSpec> tasks;

  /// Problemas de parse das tarefas (não inclui validação do grafo).
  final List<TaskIssue> taskIssues;
  final SpecStatus status;

  /// Conteúdo de `spec.md`, se existir.
  final String? specMd;

  String get statusPath => p.join(path, 'status.yaml');

  TaskSpec? task(String id) => tasks.where((t) => t.id == id).firstOrNull;
}

/// Acesso às specs de um projeto.
class SpecRepository {
  const SpecRepository(this.fs, this.root);

  final FileSystem fs;
  final String root;

  Directory get _specsDir => fs.directory(p.join(root, specsDirName));

  /// Ids das specs (`NNNN-slug`), em ordem.
  List<String> list() {
    if (!_specsDir.existsSync()) return const [];
    return [
      for (final d in _specsDir.listSync().whereType<Directory>())
        if (_specDirPattern.hasMatch(p.basename(d.path))) p.basename(d.path),
    ]..sort();
  }

  /// Aceita o id completo, `NNNN` ou o número sem zeros (`42`).
  String resolve(String arg) {
    final ids = list();
    if (ids.contains(arg)) return arg;
    final number = int.tryParse(arg);
    if (number != null) {
      final prefix = '${number.toString().padLeft(4, '0')}-';
      final matches = ids.where((id) => id.startsWith(prefix)).toList();
      if (matches.length == 1) return matches.single;
    }
    throw SpecNotFoundException(
      'spec "$arg" não encontrada em $specsDirName/'
      '${ids.isEmpty ? '' : ' (existentes: ${ids.join(', ')})'}',
    );
  }

  /// Próximo id sequencial para [title].
  String nextId(String title) {
    final slug = slugify(title);
    if (slug.isEmpty) {
      throw const FormatException('título sem caracteres válidos para o slug');
    }
    final last = list()
        .map((id) => int.parse(_specDirPattern.firstMatch(id)!.group(1)!))
        .fold(0, (a, b) => a > b ? a : b);
    return '${(last + 1).toString().padLeft(4, '0')}-$slug';
  }

  /// Carrega spec, tarefas e status. Lança [FormatException] se o
  /// `status.yaml` estiver inválido.
  SpecDir load(String id) {
    final rel = p.join(specsDirName, id);
    final dir = fs.directory(p.join(root, rel));
    if (!dir.existsSync()) throw SpecNotFoundException('spec "$id" não existe');

    final issues = <TaskIssue>[];
    final tasks = <TaskSpec>[];
    final tasksDir = fs.directory(p.join(dir.path, 'tasks'));
    if (tasksDir.existsSync()) {
      final files =
          tasksDir
              .listSync()
              .whereType<File>()
              .where((f) => p.extension(f.path) == '.md')
              .toList()
            ..sort(
              (a, b) => compareTaskIds(p.basename(a.path), p.basename(b.path)),
            );
      for (final f in files) {
        final task = parseTask(
          f.readAsStringSync(),
          p.relative(f.path, from: root),
          issues,
        );
        if (task != null) tasks.add(task);
      }
    }

    final statusFile = fs.file(p.join(dir.path, 'status.yaml'));
    final status = statusFile.existsSync()
        ? SpecStatus.parse(statusFile.readAsStringSync())
        : SpecStatus(spec: id);
    final specFile = fs.file(p.join(dir.path, 'spec.md'));
    return SpecDir(
      id: id,
      path: rel,
      tasks: tasks,
      taskIssues: issues,
      status: status,
      specMd: specFile.existsSync() ? specFile.readAsStringSync() : null,
    );
  }

  /// Cria `specs/<id>/` com `prd.md` e `status.yaml` inicial.
  String create(String id, {required String prd}) {
    final dir = fs.directory(p.join(root, specsDirName, id));
    if (dir.existsSync()) throw FormatException('spec $id já existe');
    dir.createSync(recursive: true);
    fs.file(p.join(dir.path, 'prd.md')).writeAsStringSync(prd);
    fs
        .file(p.join(dir.path, 'status.yaml'))
        .writeAsStringSync(SpecStatus(spec: id).serialize());
    return p.join(specsDirName, id);
  }
}
