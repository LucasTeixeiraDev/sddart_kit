import 'package:flutter_sdd/src/core/project/project_info.dart';
import 'package:test/test.dart';

import '../../helpers/test_env.dart';

void main() {
  test('detecta app_cubit', () {
    final fs = memoryFs(fixture: 'app_cubit');
    final info = ProjectDetector(fs).detect(memProjectPath);
    expect(info.name, 'app_cubit');
    expect(info.isFlutter, isTrue);
    expect(info.dependsOn('flutter_bloc'), isTrue);
    expect(info.dependsOn('bloc_test'), isTrue);
    expect(info.dependsOn('riverpod'), isFalse);
    expect(
      info.existingPaths,
      containsAll(['lib', 'lib/features', 'test', 'analysis_options.yaml']),
    );
  });

  test('projeto Dart puro', () {
    final fs = memoryFs(fixture: 'app_plain_dart');
    final info = ProjectDetector(fs).detect(memProjectPath);
    expect(info.isFlutter, isFalse);
    expect(info.existingPaths, isNot(contains('lib/features')));
  });

  test('sem pubspec ou pubspec inválido', () {
    final fs = memoryFs();
    final detector = ProjectDetector(fs);
    expect(
      () => detector.detect(memProjectPath),
      throwsA(isA<ProjectDetectionException>()),
    );
    fs.file('$memProjectPath/pubspec.yaml').writeAsStringSync('name: [');
    expect(
      () => detector.detect(memProjectPath),
      throwsA(isA<ProjectDetectionException>()),
    );
    fs.file('$memProjectPath/pubspec.yaml').writeAsStringSync('- a');
    expect(
      () => detector.detect(memProjectPath),
      throwsA(isA<ProjectDetectionException>()),
    );
  });
}
