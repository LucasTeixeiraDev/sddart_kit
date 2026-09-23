import 'package:flutter_sdd/src/infra/process_runner.dart';

/// Chamada registrada pelo [FakeProcessRunner].
typedef ProcessCall = ({
  String executable,
  List<String> arguments,
  String? workingDirectory,
});

/// ProcessRunner falso: respostas por prefixo de comando ("git rev-parse").
class FakeProcessRunner implements ProcessRunner {
  FakeProcessRunner([Map<String, ProcessOutput>? responses])
    : responses = responses ?? {};

  /// Chave: executável + argumentos separados por espaço (prefixo).
  final Map<String, ProcessOutput> responses;
  final calls = <ProcessCall>[];

  /// Resposta quando nenhum prefixo casa.
  ProcessOutput fallback = const ProcessOutput(0, stdout: 'ok');

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    calls.add((
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
    ));
    final line = [executable, ...arguments].join(' ');
    final match = responses.keys
        .where(line.startsWith)
        .fold<String?>(
          null,
          (best, k) => best == null || k.length > best.length ? k : best,
        );
    return match == null ? fallback : responses[match]!;
  }
}
