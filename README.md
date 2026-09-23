# flutter_sdd

CLI `sdd` + kit de **Spec-Driven Development** para apps Flutter, gerando configuração
para Claude Code e Cursor. Em desenvolvimento: veja `docs/milestones.md`.

## Instalação

```sh
dart pub global activate --source git https://github.com/LucasTeixeiraDev/sddart_kit.git
```

Com um executável compilado (`dart compile exe bin/sdd.dart`), aponte para o kit com
`--kit-path <dir>` ou `SDD_KIT_PATH`.

## Comandos disponíveis

| Comando | Função |
|---|---|
| `sdd init [--stack <nome>] [--yes] [--force]` | Detecta o projeto, cria `.sdd/` e roda `sync` |
| `sdd sync [--check]` | Gera `.claude/`, `.cursor/`, `AGENTS.md` e `CLAUDE.md`; `--check` falha se desatualizado (CI) |
| `sdd doctor` | Verifica ambiente, config, kit, `kit.lock` e se o sync está em dia |
| `sdd hook format\|guard-bash` | Hooks chamados pelos arquivos gerados (interno) |

## Overrides

Conteúdo específico do projeto vai em `.sdd/overrides/`, com a mesma estrutura do kit
(`agents/`, `skills/`, `rules/`, `commands/`, `templates/`). Um item com o mesmo nome
substitui o do kit; `disabled: true` no frontmatter o remove. Depois, `sdd sync`.
Nunca edite `.claude/` ou `.cursor/` gerados.

Flags globais: `--json`, `--verbose`, `--kit-path <dir>`, `--version`.
Exit codes: `0` ok, `1` falha de gate/validação, `2` erro de uso/config.
