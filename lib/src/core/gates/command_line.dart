/// Placeholder de arquivos nos comandos do config.
const filesPlaceholder = '{files}';

/// Divide uma linha de comando em argumentos (aspas simples e duplas).
List<String> tokenize(String command) {
  final args = <String>[];
  final current = StringBuffer();
  String? quote;
  var hasToken = false;
  for (final char in command.split('')) {
    if (quote != null) {
      if (char == quote) {
        quote = null;
      } else {
        current.write(char);
      }
    } else if (char == '"' || char == "'") {
      quote = char;
      hasToken = true;
    } else if (char.trim().isEmpty) {
      if (hasToken) {
        args.add(current.toString());
        current.clear();
        hasToken = false;
      }
    } else {
      current.write(char);
      hasToken = true;
    }
  }
  if (quote != null) {
    throw FormatException('aspas não fechadas em: $command');
  }
  if (hasToken) args.add(current.toString());
  return args;
}

/// Comando pronto para executar: [files] substituem `{files}`
/// (`null` = modo completo, placeholder removido).
List<String> buildCommand(String command, {List<String>? files}) {
  final result = <String>[];
  for (final arg in tokenize(command)) {
    if (arg == filesPlaceholder) {
      result.addAll(files ?? const []);
    } else {
      result.add(arg);
    }
  }
  if (result.isEmpty) throw FormatException('comando vazio: "$command"');
  return result;
}

/// Garante `--reporter json` em `flutter test`/`dart test`.
List<String> withJsonReporter(List<String> args) {
  final isTest =
      args.length >= 2 &&
      (args[0] == 'flutter' || args[0] == 'dart') &&
      args[1] == 'test';
  if (!isTest) return args;
  final cleaned = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--reporter' || a == '-r') {
      i++;
      continue;
    }
    if (a.startsWith('--reporter=') || (a.startsWith('-r') && a.length > 2)) {
      continue;
    }
    cleaned.add(a);
  }
  return [...cleaned.take(2), '--reporter', 'json', ...cleaned.skip(2)];
}
