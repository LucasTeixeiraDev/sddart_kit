import 'dart:io' as io;

/// Exclusão mútua entre processos para um arquivo (ex.: `status.yaml`).
abstract interface class FileLocker {
  Future<T> withLock<T>(String path, Future<T> Function() body);
}

/// Lock do sistema operacional (fcntl/LockFileEx) num arquivo em
/// `<tmp>/sdd-locks/`, fora do repositório. Liberado também se o processo morrer.
class IoFileLocker implements FileLocker {
  const IoFileLocker();

  @override
  Future<T> withLock<T>(String path, Future<T> Function() body) async {
    final dir = io.Directory('${io.Directory.systemTemp.path}/sdd-locks')
      ..createSync(recursive: true);
    final key = io.File(path).absolute.path.hashCode.toUnsigned(32);
    final handle = await io.File(
      '${dir.path}/$key.lock',
    ).open(mode: io.FileMode.write);
    try {
      await handle.lock(io.FileLock.blockingExclusive);
      return await body();
    } finally {
      await handle.close();
    }
  }
}

/// Serializa dentro do processo (testes e FS em memória).
class InProcessFileLocker implements FileLocker {
  Future<void> _last = Future.value();

  @override
  Future<T> withLock<T>(String path, Future<T> Function() body) {
    final result = _last.then((_) => body());
    _last = result.then<void>((_) {}, onError: (_) {});
    return result;
  }
}
