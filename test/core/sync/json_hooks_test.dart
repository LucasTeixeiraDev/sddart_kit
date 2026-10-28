import 'package:flutter_sdd/src/core/adapters/generated_file.dart';
import 'package:flutter_sdd/src/core/sync/json_hooks.dart';
import 'package:test/test.dart';

const Map<String, List<Map<String, Object>>> claudeFormat = {
  'PostToolUse': [
    {
      'matcher': 'Edit|Write',
      'hooks': [
        {'type': 'command', 'command': 'sdd hook format'},
      ],
    },
  ],
};

void main() {
  group('claudeSettings', () {
    test('preserva o usuário, troca as entradas do sdd, idempotente', () {
      final existing = <String, Object?>{
        'permissions': {
          'allow': ['Bash(ls)'],
        },
        'hooks': {
          'PostToolUse': [
            {
              'matcher': 'Write',
              'hooks': [
                {'type': 'command', 'command': 'meu-lint'},
                {'type': 'command', 'command': 'sdd hook velho'},
              ],
            },
          ],
          'Stop': [
            {
              'hooks': [
                {'type': 'command', 'command': 'sdd hook x'},
              ],
            },
          ],
        },
      };
      const reg = HookRegistration(
        '.claude/settings.json',
        HookStyle.claudeSettings,
        claudeFormat,
      );
      final merged = mergeHooks(existing, reg);
      expect(merged['permissions'], existing['permissions']);
      final hooks = merged['hooks']! as Map<String, Object?>;
      expect(hooks.keys, ['PostToolUse']);
      expect(hooks['PostToolUse'], [
        {
          'matcher': 'Write',
          'hooks': [
            {'type': 'command', 'command': 'meu-lint'},
          ],
        },
        ...claudeFormat['PostToolUse']!,
      ]);
      expect(mergeHooks(merged, reg), merged);
    });

    test('registro vazio remove o sdd e a chave hooks vazia', () {
      final merged = mergeHooks({
        'hooks': claudeFormat,
        'model': 'x',
        'other': 1,
      }, const HookRegistration('p', HookStyle.claudeSettings, {}));
      expect(merged, {'model': 'x', 'other': 1});
      expect(isEffectivelyEmpty({}, HookStyle.claudeSettings), isTrue);
    });

    test('entradas sem formato conhecido são mantidas', () {
      final merged = mergeHooks({
        'hooks': {
          'Weird': [1, 'x'],
          'NotList': 3,
        },
      }, const HookRegistration('p', HookStyle.claudeSettings, {}));
      expect(merged['hooks'], {
        'Weird': [1, 'x'],
        'NotList': 3,
      });
    });
  });

  group('cursorHooks', () {
    test('adiciona version e remove só o sdd', () {
      const reg = HookRegistration(
        '.cursor/hooks.json',
        HookStyle.cursorHooks,
        {
          'afterFileEdit': [
            {'command': 'sdd hook format'},
          ],
        },
      );
      final merged = mergeHooks({
        'hooks': {
          'afterFileEdit': [
            {'command': './meu.sh'},
            {'command': 'sdd hook format'},
          ],
        },
      }, reg);
      expect(merged, {
        'hooks': {
          'afterFileEdit': [
            {'command': './meu.sh'},
            {'command': 'sdd hook format'},
          ],
        },
        'version': 1,
      });
      final cleared = mergeHooks(
        merged,
        const HookRegistration('p', HookStyle.cursorHooks, {}),
      );
      expect(cleared['hooks'], {
        'afterFileEdit': [
          {'command': './meu.sh'},
        ],
      });
      expect(isEffectivelyEmpty({'version': 1}, HookStyle.cursorHooks), isTrue);
    });
  });
}
