import 'package:flutter_sdd/src/core/adapters/generated_file.dart';
import 'package:flutter_sdd/src/core/adapters/tool_adapter.dart';

bool _isSdd(Object? hook) =>
    hook is Map<String, Object?> &&
    hook['command'] is String &&
    (hook['command']! as String).startsWith(sddHookPrefix);

/// Remove as entradas do sdd de [existing] e adiciona as de [registration],
/// preservando tudo o que é do usuário. Não altera [existing].
Map<String, Object?> mergeHooks(
  Map<String, Object?> existing,
  HookRegistration registration,
) {
  final result = <String, Object?>{...existing};
  final hooksRaw = existing['hooks'];
  final hooks = <String, Object?>{
    if (hooksRaw is Map<String, Object?>) ...hooksRaw,
  };

  for (final event in hooks.keys.toList()) {
    final entries = hooks[event];
    if (entries is! List<Object?>) continue;
    final kept = <Object?>[];
    for (final entry in entries) {
      switch (registration.style) {
        case HookStyle.cursorHooks:
          if (!_isSdd(entry)) kept.add(entry);
        case HookStyle.claudeSettings:
          if (entry is Map<String, Object?> && entry['hooks'] is List) {
            final inner = entry['hooks']! as List<Object?>;
            final innerKept = inner.where((h) => !_isSdd(h)).toList();
            if (innerKept.length == inner.length) {
              kept.add(entry);
            } else if (innerKept.isNotEmpty) {
              kept.add({...entry, 'hooks': innerKept});
            }
          } else {
            kept.add(entry);
          }
      }
    }
    if (kept.isEmpty) {
      hooks.remove(event);
    } else {
      hooks[event] = kept;
    }
  }

  for (final MapEntry(key: event, value: entries)
      in registration.entries.entries) {
    hooks[event] = [...?(hooks[event] as List<Object?>?), ...entries];
  }

  if (hooks.isEmpty) {
    result.remove('hooks');
  } else {
    if (registration.style == HookStyle.cursorHooks) {
      result.putIfAbsent('version', () => 1);
    }
    result['hooks'] = hooks;
  }
  return result;
}

/// Se o documento não tem nada além do que o sdd colocaria sozinho.
bool isEffectivelyEmpty(Map<String, Object?> doc, HookStyle style) =>
    style == HookStyle.cursorHooks
    ? doc.keys.every((k) => k == 'version')
    : doc.isEmpty;
