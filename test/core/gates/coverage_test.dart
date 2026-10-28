import 'package:flutter_sdd/src/core/gates/coverage.dart';
import 'package:test/test.dart';

const lcov = '''
SF:lib/features/auth/domain/usecase.dart
DA:1,1
DA:2,0
DA:3,4
LF:3
LH:2
end_of_record
SF:/proj/app/lib/features/auth/presentation/cubit/login_cubit.dart
DA:1,1
DA:2,1
DA:bad
end_of_record
SF:lib/main.dart
DA:1,0
end_of_record
''';

void main() {
  test('parse, filtro por glob e total', () {
    final files = parseLcov(lcov, '/proj/app');
    expect(files.map((f) => f.path), [
      'lib/features/auth/domain/usecase.dart',
      'lib/features/auth/presentation/cubit/login_cubit.dart',
      'lib/main.dart',
    ]);
    expect(files.first.percent, closeTo(66.7, 0.1));
    final scoped = filterCoverage(files, [
      'lib/features/**/domain/**',
      'lib/features/**/presentation/**/cubit/**',
    ]);
    expect(scoped, hasLength(2));
    expect(totalPercent(scoped), closeTo(80, 0.01));
    expect(totalPercent(const []), 100);
    expect(const FileCoverage('x', 0, 0).percent, 100);
  });
}
