import 'dart:convert';

/// `.sdd/generated.json`: o que o último sync gerou.
class GeneratedManifest {
  const GeneratedManifest({this.files = const {}, this.createdJson = const {}});

  factory GeneratedManifest.parse(String source) {
    try {
      final raw = jsonDecode(source);
      if (raw is Map<String, Object?>) {
        Set<String> list(String key) => {
          ...((raw[key] as List<Object?>?) ?? const []).whereType<String>(),
        };
        return GeneratedManifest(
          files: list('files'),
          createdJson: list('created_json'),
        );
      }
    } on FormatException {
      // Manifesto corrompido: tratado como vazio; o marcador ainda protege.
    }
    return const GeneratedManifest();
  }

  /// Arquivos gerados (caminhos relativos à raiz).
  final Set<String> files;

  /// Arquivos JSON de hooks criados pelo sdd (podem ser apagados se vazios).
  final Set<String> createdJson;

  String serialize() {
    final doc = {
      'files': files.toList()..sort(),
      'created_json': createdJson.toList()..sort(),
    };
    return '${const JsonEncoder.withIndent('  ').convert(doc)}\n';
  }
}
