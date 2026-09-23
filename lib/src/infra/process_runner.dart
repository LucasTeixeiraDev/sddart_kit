import 'dart:io';

/// Resultado de um processo externo.
class ProcessOutput {
  const ProcessOutput(this.exitCode, {this.stdout = '', this.stderr = ''});

  /// Código usado quando o executável não existe no PATH.
  static const notFound = 127;

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get ok => exitCode == 0;
}

/// Abstração injetável para executar processos.
abstract interface class ProcessRunner {
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  });
}

/// Implementação real baseada em `dart:io`.
class IoProcessRunner implements ProcessRunner {
  const IoProcessRunner();

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    try {
      final result = await Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: Platform.isWindows,
      );
      return ProcessOutput(
        result.exitCode,
        stdout: '${result.stdout}',
        stderr: '${result.stderr}',
      );
    } on ProcessException catch (e) {
      return ProcessOutput(ProcessOutput.notFound, stderr: e.message);
    }
  }
}
