# Adapters: formatos verificados

Consulta às docs oficiais: **2026-09-23**. Formatos mudam com frequência: reverifique antes
de alterar um adapter e atualize os goldens (`UPDATE_GOLDENS=1 dart test`).

## Claude Code
Fontes: https://code.claude.com/docs/en/subagents · https://code.claude.com/docs/en/skills ·
https://code.claude.com/docs/en/hooks · https://code.claude.com/docs/en/memory

| Item | Formato |
|---|---|
| Subagente | `.claude/agents/<nome>.md`; frontmatter `name`, `description`, `tools` (lista ou string separada por vírgula), `model` (`opus`/`sonnet`/`haiku`/`fable`, id completo ou `inherit`), `skills` (pré-carregadas), `hooks`, `effort`, entre outros |
| Ferramentas | `Read`, `Grep`, `Glob`, `Edit`, `Write`, `Bash`, `WebFetch`... `Bash(cmd:*)` em `tools` **não** restringe comandos |
| Hooks do subagente | `hooks: {PreToolUse: [{matcher: Bash, hooks: [{type: command, command}]}]}`; valem só enquanto o subagente roda; exit 2 bloqueia (stderr = motivo); stdin traz `tool_input.command`. Hooks de agentes do projeto só rodam depois que o workspace é marcado como confiável (não em `claude -p`) |
| Skill | `.claude/skills/<nome>/SKILL.md` + arquivos de apoio; `name`, `description`; `disable-model-invocation: true` = só manual; `argument-hint` |
| Argumentos de skill | `$ARGUMENTS`, `$0` é o primeiro (`$1` é o segundo) |
| Commands | `.claude/commands/` é obsoleto em favor de skills |
| Rules | `.claude/rules/*.md`; frontmatter só `paths:` (lista de globs); sem `paths` carrega no início da sessão |
| Hooks de sessão | `.claude/settings.json` → `hooks.PostToolUse[{matcher: "Edit|Write", hooks: [{type, command}]}]`; stdin traz `tool_input.file_path` |
| AGENTS.md | lido nativamente só quando não existe CLAUDE.md; `@AGENTS.md` no CLAUDE.md é o caminho portátil |

## Cursor
Fontes: https://cursor.com/docs/context/subagents · https://cursor.com/docs/context/rules ·
https://cursor.com/docs/context/skills · https://cursor.com/docs/agent/hooks ·
https://cursor.com/docs/reference/third-party-hooks · https://cursor.com/docs/models

| Item | Formato |
|---|---|
| Subagente | `.cursor/agents/<nome>.md` (também lê `.claude/agents/`; `.cursor/` vence em nomes iguais); `name`, `description`, `model`, `readonly`, `is_background`. **Sem `tools`** |
| Modelos | `inherit` ou id do Cursor (`claude-opus-5-5`, `claude-sonnet-5`). Aliases (`opus`) não documentados. Haiku sem uso confiável em subagentes |
| Rules | só `.cursor/rules/*.mdc`; `description`, `globs` (**string** separada por vírgula), `alwaysApply` |
| Skills | `.cursor/skills/`, `.agents/skills/` **e `.claude/skills/`**; `disable-model-invocation: true` = só manual |
| Commands | `.cursor/commands/*.md`: legado, sem sintaxe de argumentos |
| Hooks | `.cursor/hooks.json` `{version: 1, hooks: {afterFileEdit: [{command}]}}`; stdin traz `file_path`. **Também executa hooks de `.claude/settings.json`** |
| AGENTS.md | lido nativamente |

## O que o `sdd sync` gera

Nomes gerados sempre com prefixo `sdd-`. Todo arquivo markdown gerado tem o aviso
`<!-- gerado por sdd vX.Y.Z — não edite; use .sdd/overrides/ ou o kit -->` logo após o
frontmatter. Arquivos sem suporte a comentário (ex.: scripts de skill) são identificados só
pelo manifesto `.sdd/generated.json`.

| Canônico (`kit/`) | Claude (target `claude`) | Cursor (target `cursor`) |
|---|---|---|
| `agents/<n>.md` | `.claude/agents/sdd-<n>.md` com `tools` reais, `model` do tier, `skills` prefixadas; `bash_allow` → hook `PreToolUse` `sdd hook guard-bash`; `write_allow` → tool `Write` + hook `Write\|Edit` `sdd hook guard-write` | `.cursor/agents/sdd-<n>.md` com `model` do Cursor e `readonly` (agente com `write_allow` devolve o conteúdo ao orquestrador) |
| `tier_variants` | um agente por tier: `sdd-<n>-<tier>` | idem |
| `skills/<n>/` | `.claude/skills/sdd-<n>/` | nada (lê `.claude/skills/`) ou `.cursor/skills/` (ver regras) |
| `commands/<n>.md` | skill manual `.claude/skills/sdd-<n>/SKILL.md` (`disable-model-invocation: true`, `argument-hint`) | idem skills |
| `rules/<n>.md` | `.claude/rules/sdd-<n>.md` (`paths`; sem frontmatter se `always`) | `.cursor/rules/sdd-<n>.mdc` |
| `hooks.format_on_edit` | `.claude/settings.json` → `PostToolUse` `sdd hook format` | ver regras |
| seção do AGENTS.md | `AGENTS.md` entre `<!-- sdd:begin -->` e `<!-- sdd:end -->` (qualquer target) | |
| CLAUDE.md | cria com `@AGENTS.md` ou garante a linha | — |

Tools abstratas → Claude: `read`→Read, `search`→Grep+Glob, `edit`→Edit, `write`→Write,
`bash`→Bash. No Cursor não há mapeamento: só `readonly`.

## Regras de geração
- **Hooks (D-012):** com `claude` entre os `targets`, o hook de format-on-edit vai **só** em
  `.claude/settings.json` (o Cursor o executa por compatibilidade). `.cursor/hooks.json` só é
  gerado quando `claude` não é target. Nos dois casos o merge mexe só nas entradas cujo
  comando começa com `sdd hook `; o arquivo só é apagado se foi criado pelo sdd e ficou vazio.
- **Skills e comandos no Cursor:** `adapters.cursor.skills: shared` (padrão) usa
  `.claude/skills/`; `own` gera `.cursor/skills/`. Sem `claude` nos targets, sempre `own`.
- **Agentes no Cursor (D-005):** `adapters.cursor.agents: own` (padrão) gera `.cursor/agents/`
  com `model`/`readonly` próprios; `shared` depende de `.claude/agents/`. Sem `claude` nos
  targets, sempre `own`.
- **Argumentos dos comandos:** o corpo usa texto neutro ("o argumento após o comando é...")
  porque o Cursor não documenta `$ARGUMENTS`. O Claude Code anexa `ARGUMENTS: <entrada>`
  quando nenhum placeholder a recebe (verificado em 2026-10-03, D-035).
- **Comandos não se chamam entre si:** skills com `disable-model-invocation: true` não podem
  ser invocadas pelo modelo (o Claude Code bloqueia). O `/sdd-run` lê o `SKILL.md` de cada
  fase com a ferramenta de leitura.
- **Hooks chamam `sdd` pelo PATH.** O `sdd doctor` avisa se não estiver.
