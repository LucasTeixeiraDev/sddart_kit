/// Hash FNV-1a de 64 bits incremental, em hex de 16 dígitos.
class Fnv1a64 {
  // CLI só roda na VM (ints de 64 bits); nunca compilado para JS.
  // ignore: avoid_js_rounded_ints
  int _hash = 0xcbf29ce484222325;

  static const _prime = 0x100000001b3;

  void add(List<int> bytes) {
    for (final b in bytes) {
      _hash = (_hash ^ b) * _prime;
    }
  }

  /// `toUnsigned(64)` não cabe num int de 64 bits com sinal: monta as metades.
  String get hex {
    String half(int v) => v.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    return '${half(_hash >> 32)}${half(_hash)}';
  }
}

String fnv1a64Hex(List<int> bytes) => (Fnv1a64()..add(bytes)).hex;
