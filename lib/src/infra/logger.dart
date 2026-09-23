import 'dart:convert';

/// Saída do CLI: curta por padrão, detalhes só com `--verbose`.
///
/// Em modo JSON, mensagens humanas vão para stderr e apenas o documento
/// final ([json]) vai para stdout.
class Logger {
  Logger({
    required StringSink out,
    required StringSink err,
    this.verbose = false,
    this.jsonMode = false,
  }) : _out = out,
       _err = err;

  final StringSink _out;
  final StringSink _err;
  final bool verbose;
  final bool jsonMode;

  StringSink get _human => jsonMode ? _err : _out;

  void info(String message) => _human.writeln(message);

  void warn(String message) => _err.writeln('WARN $message');

  void error(String message) => _err.writeln('ERRO $message');

  void detail(String message) {
    if (verbose) _err.writeln(message);
  }

  void json(Object? document) =>
      _out.writeln(const JsonEncoder.withIndent('  ').convert(document));
}
