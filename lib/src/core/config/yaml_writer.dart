import 'dart:convert';

/// Emissor YAML mínimo e determinístico (mapas, listas e escalares).
///
/// Strings que precisam de aspas usam aspas duplas no estilo JSON, que é um
/// subconjunto válido de YAML. Listas de escalares curtas saem em fluxo.
String toYaml(Map<String, Object?> map) {
  final buffer = StringBuffer();
  _writeMap(buffer, map, 0);
  return buffer.toString();
}

void _writeMap(StringBuffer b, Map<String, Object?> map, int indent) {
  final pad = ' ' * indent;
  for (final MapEntry(:key, :value) in map.entries) {
    final k = _scalar(key);
    if (value is Map<String, Object?> && value.isNotEmpty) {
      b.writeln('$pad$k:');
      _writeMap(b, value, indent + 2);
    } else if (value is List<Object?> && value.isNotEmpty && !_isFlow(value)) {
      b.writeln('$pad$k:');
      _writeList(b, value, indent + 2);
    } else {
      b.writeln('$pad$k: ${_inline(value)}');
    }
  }
}

void _writeList(StringBuffer b, List<Object?> list, int indent) {
  final pad = ' ' * indent;
  for (final item in list) {
    if (item is Map<String, Object?> && item.isNotEmpty) {
      final inner = StringBuffer();
      _writeMap(inner, item, indent + 2);
      b.writeln('$pad- ${inner.toString().substring(indent + 2).trimRight()}');
    } else {
      b.writeln('$pad- ${_inline(item)}');
    }
  }
}

bool _isFlow(List<Object?> list) =>
    list.every((e) => e is! Map && e is! List) &&
    list.map(_inline).join(', ').length <= 60;

String _inline(Object? value) => switch (value) {
  null => 'null',
  Map() when value.isEmpty => '{}',
  List() => '[${value.map(_inline).join(', ')}]',
  String() => _scalar(value),
  _ => '$value',
};

final _plainSafe = RegExp(r'^[A-Za-z_][A-Za-z0-9_./-]*$');
const _reserved = {'true', 'false', 'null', 'yes', 'no', 'on', 'off', '~'};

String _scalar(String value) =>
    _plainSafe.hasMatch(value) && !_reserved.contains(value.toLowerCase())
    ? value
    : jsonEncode(value);
