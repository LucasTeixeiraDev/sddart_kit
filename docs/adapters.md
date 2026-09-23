# Adapters: formatos verificados

Consulta: **2026-09-23**. Este arquivo é completado no M2. Formatos mudam com frequência:
reverifique antes de alterar um adapter.

## Claude Code
Fontes: https://code.claude.com/docs/en/subagents · /skills · /hooks · /memory

- **Subagentes:** `.claude/agents/<nome>.md`, frontmatter `name`, `description`, `tools`
  (lista ou string separada por vírgula), `model` (`opus`/`sonnet`/`haiku`/`fable`, id completo
  ou `inherit`), `skills`, `hooks`, `effort` etc.
- **Bash por padrão:** `Bash(cmd:*)` em `tools` **não** restringe comandos.
- **Hooks no subagente:** `hooks: {PreToolUse: [{matcher: Bash, hooks: [{type: command, command: ...}]}]}`.
  Valem só enquanto o subagente roda; exit 2 bloqueia (stderr vira o motivo); comando em
  `tool_input.command` no stdin. Hooks de agentes do projeto exigem workspace confiável.
- **Skills:** `.claude/skills/<nome>/SKILL.md`; `disable-model-invocation: true` = só manual.
  Argumentos: `$ARGUMENTS`, `$0` é o primeiro (`$1` é o segundo).
- **Commands** (`.claude/commands/`): obsoletos em favor de skills.
- **Rules:** `.claude/rules/*.md` com `paths:` (lista de globs).
- **Hooks de sessão:** `.claude/settings.json`, `PostToolUse` com matcher `Edit|Write`;
  caminho em `tool_input.file_path`.
- **AGENTS.md:** lido nativamente só quando não existe CLAUDE.md; `@AGENTS.md` no CLAUDE.md
  continua sendo o caminho portátil.

## Cursor
Fontes: https://cursor.com/docs/context/subagents · /rules · /skills ·
https://cursor.com/docs/agent/hooks · https://cursor.com/docs/reference/third-party-hooks

- **Subagentes:** `.cursor/agents/` (também lê `.claude/agents/`; `.cursor/` vence em nomes
  iguais). Frontmatter: `name`, `description`, `model` (`inherit` ou id do Cursor, ex.
  `claude-opus-5-5`, `claude-sonnet-5`), `readonly`, `is_background`. Não há `tools`.
- **Rules:** só `.cursor/rules/*.mdc`; `description`, `globs` (string separada por vírgula),
  `alwaysApply`.
- **Skills:** `.cursor/skills/`, `.agents/skills/` e `.claude/skills/`;
  `disable-model-invocation: true` = só manual.
- **Commands:** `.cursor/commands/*.md` é legado, sem sintaxe de argumentos.
- **Hooks:** `.cursor/hooks.json` `{version: 1, hooks: {afterFileEdit: [{command}]}}`;
  `file_path` no stdin. **O Cursor também executa hooks de `.claude/settings.json`.**

## Regras de geração do sdd
- **Hooks (D-012):** com `claude` entre os `targets`, o hook de format-on-edit é gerado **só**
  em `.claude/settings.json` (o Cursor o executa por compatibilidade). `.cursor/hooks.json`
  só é gerado quando `claude` não é target. Nos dois casos, merge só das chaves do sdd.
- **Comandos (D-003):** gerados como skills manuais em `.claude/skills/`.
- **Agentes (D-005):** gerados em `.claude/agents/` e `.cursor/agents/`.
