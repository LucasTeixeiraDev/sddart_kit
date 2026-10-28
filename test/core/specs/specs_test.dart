import 'package:flutter_sdd/src/core/specs/slug.dart';
import 'package:flutter_sdd/src/core/specs/spec_repository.dart';
import 'package:flutter_sdd/src/core/status/spec_status.dart';
import 'package:test/test.dart';

import '../../helpers/test_env.dart';

void main() {
  group('slugify', () {
    test('acentos, pontuação e espaços', () {
      expect(slugify('Login com Biometria!'), 'login-com-biometria');
      expect(slugify('  Ação  de   Exceção ç/ñ '), 'acao-de-excecao-c-n');
      expect(slugify('???'), '');
    });
    test('corta no limite em fronteira de palavra', () {
      final slug = slugify('palavra ' * 20, maxLength: 30);
      expect(slug.length, lessThanOrEqualTo(30));
      expect(slug, isNot(endsWith('-')));
      expect(slugify('a' * 80, maxLength: 10), 'a' * 10);
    });
  });

  group('SpecRepository', () {
    test('numeração, criação, resolução e carregamento', () {
      final fs = memoryFs();
      final repo = SpecRepository(fs, memProjectPath);
      expect(repo.list(), isEmpty);
      expect(repo.nextId('Login com Biometria'), '0001-login-com-biometria');
      repo.create('0001-login-com-biometria', prd: '# PRD');
      fs.directory('$memProjectPath/specs/0007-outra').createSync();
      fs.directory('$memProjectPath/specs/rascunho').createSync();
      expect(repo.list(), ['0001-login-com-biometria', '0007-outra']);
      expect(repo.nextId('Nova'), '0008-nova');

      expect(
        repo.resolve('0001-login-com-biometria'),
        '0001-login-com-biometria',
      );
      expect(repo.resolve('0007'), '0007-outra');
      expect(repo.resolve('7'), '0007-outra');
      expect(() => repo.resolve('9'), throwsA(isA<SpecNotFoundException>()));
      expect(() => repo.create('0007-outra', prd: ''), throwsFormatException);
      expect(() => repo.nextId('!!!'), throwsFormatException);

      final spec = repo.load('0001-login-com-biometria');
      expect(spec.status.phase, Phase.analyze);
      expect(spec.tasks, isEmpty);
      expect(spec.specMd, isNull);
      // Sem status.yaml: estado inicial.
      expect(repo.load('0007-outra').status.spec, '0007-outra');
      expect(() => repo.load('0009-x'), throwsA(isA<SpecNotFoundException>()));
    });

    test('carrega tarefas da fixture em ordem natural', () {
      final fs = memoryFs(fixture: 'app_with_spec');
      final spec = SpecRepository(
        fs,
        memProjectPath,
      ).load('0001-login-biometria');
      expect(spec.tasks.map((t) => t.id), ['T01', 'T02', 'T03', 'T04']);
      expect(spec.taskIssues, isEmpty);
      expect(spec.task('T02')!.exemplar, isNotNull);
      expect(spec.task('T99'), isNull);
      expect(spec.statusPath, 'specs/0001-login-biometria/status.yaml');
    });
  });
}
