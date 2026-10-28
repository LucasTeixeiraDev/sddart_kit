import 'package:flutter_sdd/src/core/config/yaml_utils.dart';
import 'package:flutter_sdd/src/core/config/yaml_writer.dart';
import 'package:test/test.dart';

void main() {
  group('deepMerge', () {
    test('mapas combinam; listas e escalares substituem', () {
      final merged = deepMerge(
        {
          'a': {'x': 1, 'y': 2},
          'l': [1, 2],
          's': 'base',
        },
        {
          'a': {'y': 3},
          'l': [9],
          'n': true,
        },
      );
      expect(merged, {
        'a': {'x': 1, 'y': 3},
        'l': [9],
        's': 'base',
        'n': true,
      });
    });
  });

  group('toYaml', () {
    test('ida e volta preserva estrutura e escapes', () {
      final doc = <String, Object?>{
        'version': 1,
        'name': 'flutter-clean-cubit',
        'flag': false,
        'empty_list': <Object?>[],
        'empty_map': <String, Object?>{},
        'nothing': null,
        'ratio': 0.5,
        'short': ['a', 'b'],
        'long': [
          'lib/features/**/domain/**',
          'lib/features/**/presentation/**/cubit/**',
        ],
        'pattern': r'\[(AC-\d{2,})\]',
        'reserved': 'yes',
        'with space': 'dart format {files}',
        'nested': {
          'deep': {'default': 'opus', 'cursor': 'claude-opus-5-5'},
        },
        'objects': [
          {'dependency': 'flutter', 'score': 1},
          {'path': 'lib/features', 'score': 2},
        ],
      };
      final text = toYaml(doc);
      expect(loadPlainYaml(text), doc);
      expect(text, contains('short: [a, b]'));
      expect(text, contains('reserved: "yes"'));
    });
  });
}
