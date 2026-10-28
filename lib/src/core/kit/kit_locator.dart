import 'package:file/file.dart';
import 'package:path/path.dart' as p;

/// De onde o kit foi resolvido.
enum KitSource { flag, env, package }

class KitLocation {
  const KitLocation(this.path, this.source);

  /// Diretório `kit/` (contém `core/` e `stacks/`).
  final String path;
  final KitSource source;

  String stackPath(String stack) => p.join(path, 'stacks', stack);

  String stackFile(String stack) => p.join(stackPath(stack), 'stack.yaml');
}

class KitNotFoundException implements Exception {
  const KitNotFoundException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Localiza o kit. Ordem: `--kit-path` > `SDD_KIT_PATH` > raiz do pacote.
class KitLocator {
  const KitLocator({
    required this.fs,
    required this.environment,
    required this.packageRoot,
  });

  static const envVar = 'SDD_KIT_PATH';

  final FileSystem fs;
  final Map<String, String> environment;

  /// Resolve a raiz do pacote `flutter_sdd` (null se indisponível, ex.: AOT).
  final Future<Uri?> Function() packageRoot;

  Future<KitLocation> locate({String? kitPath}) async {
    if (kitPath != null) return _validate(kitPath, KitSource.flag);
    final fromEnv = environment[envVar];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      return _validate(fromEnv, KitSource.env);
    }
    final root = await packageRoot();
    if (root != null) {
      return _validate(p.join(fs.path.fromUri(root), 'kit'), KitSource.package);
    }
    throw const KitNotFoundException(
      'kit não encontrado: pacote flutter_sdd não resolvível (executável '
      'compilado?). Use --kit-path ou $envVar.',
    );
  }

  KitLocation _validate(String path, KitSource source) {
    final normalized = p.normalize(fs.path.absolute(path));
    if (!fs.directory(p.join(normalized, 'core')).existsSync() ||
        !fs.directory(p.join(normalized, 'stacks')).existsSync()) {
      throw KitNotFoundException(
        'kit inválido em $normalized (origem: ${source.name}): '
        'esperado core/ e stacks/',
      );
    }
    return KitLocation(normalized, source);
  }

  /// Nomes dos stacks disponíveis no kit.
  List<String> stacks(KitLocation kit) {
    final dir = fs.directory(p.join(kit.path, 'stacks'));
    return [
      for (final e in dir.listSync().whereType<Directory>())
        if (fs.file(p.join(e.path, 'stack.yaml')).existsSync())
          p.basename(e.path),
    ]..sort();
  }
}
