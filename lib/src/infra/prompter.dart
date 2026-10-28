import 'package:mason_logger/mason_logger.dart' as mason;

/// Perguntas interativas (injetável para testes).
abstract interface class Prompter {
  bool confirm(String message, {bool defaultValue = true});

  String chooseOne(
    String message, {
    required List<String> choices,
    String? defaultValue,
  });

  List<String> chooseAny(
    String message, {
    required List<String> choices,
    List<String>? defaultValues,
  });
}

/// Implementação de terminal via `mason_logger`.
class TerminalPrompter implements Prompter {
  TerminalPrompter([mason.Logger? logger]) : _logger = logger ?? mason.Logger();

  final mason.Logger _logger;

  @override
  bool confirm(String message, {bool defaultValue = true}) =>
      _logger.confirm(message, defaultValue: defaultValue);

  @override
  String chooseOne(
    String message, {
    required List<String> choices,
    String? defaultValue,
  }) =>
      _logger.chooseOne(message, choices: choices, defaultValue: defaultValue);

  @override
  List<String> chooseAny(
    String message, {
    required List<String> choices,
    List<String>? defaultValues,
  }) => _logger.chooseAny(
    message,
    choices: choices,
    defaultValues: defaultValues,
  );
}
