import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Exceptions não mapeadas são reportadas via FlutterError.reportError:
  // capture para verificar o reporte (expect(reported, hasLength(1))).
  late List<FlutterErrorDetails> reported;
  final originalOnError = FlutterError.onError;

  setUp(() {
    reported = [];
    FlutterError.onError = reported.add;
  });

  tearDown(() => FlutterError.onError = originalOnError);

  group('{{name.pascalCase()}}RepositoryImpl', () {
    // Um teste '[AC-xx] ...' por exception mapeada e um para a não mapeada.
    test('harness pronto', () => expect(reported, isEmpty));
  });
}
