/// Defaults genéricos do core. O `stack.yaml` do stack pack sobrescreve estes
/// valores e o `config.yaml` do projeto sobrescreve ambos.
const Map<String, Object?> coreConfigDefaults = {
  'version': 1,
  'targets': ['claude', 'cursor'],
  'language': 'pt-BR',
  'project': {
    'features_path': 'lib',
    'test_path': 'test',
    'state_management': 'none',
    'error_handling': 'exceptions',
    'generated_globs': [
      '**/*.g.dart',
      '**/*.freezed.dart',
      '**/*.mocks.dart',
      '**/.gitkeep',
    ],
  },
  'commands': {
    'format': 'dart format --output=none --set-exit-if-changed {files}',
    'analyze': 'dart analyze --format=machine --fatal-infos {files}',
    'test': 'flutter test {files}',
    'test_all': 'flutter test --coverage',
    'codegen': 'dart run build_runner build -d',
  },
  'dod': {
    'gates': ['format', 'analyze', 'test', 'coverage', 'traceability'],
    'coverage': {
      'min': 80,
      'paths': ['lib/**'],
    },
    'traceability': {
      'ac_pattern': r'AC-\d{2,}',
      'test_tag_pattern': r'\[(AC-\d{2,})\]',
    },
    'checklist': <String>[],
  },
  'execution': {
    'max_fix_attempts': 2,
    'escalate_to': 'deep',
    'max_review_cycles': 2,
  },
  'memory': {'learnings_warn_after': 15},
  'models': {'deep': 'opus', 'standard': 'sonnet', 'fast': 'haiku'},
  'hooks': {'format_on_edit': false},
  'scaffold': {'vars': <String, Object?>{}},
  'adapters': {
    'cursor': {'skills': 'shared', 'agents': 'own'},
  },
};
