import 'dart:isolate';

/// Resolve a raiz do pacote `flutter_sdd` a partir do package config.
///
/// Funciona em `dart run` e `dart pub global activate` (git ou path).
/// Em executáveis AOT retorna `null` (use `--kit-path` ou `SDD_KIT_PATH`).
Future<Uri?> resolveFlutterSddPackageRoot() async {
  try {
    final lib = await Isolate.resolvePackageUri(
      Uri.parse('package:flutter_sdd/'),
    );
    return lib?.resolve('..');
  } on Object {
    return null;
  }
}
