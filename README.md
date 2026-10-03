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
| `sdd new "<título>"` | Cria `specs/NNNN-slug/` com `prd.md` e `status.yaml` |
| `sdd tasks validate <spec>` | Valida schema, DAG, ondas, `owns`, `reads`, `exemplar` e ACs |
| `sdd tasks graph <spec> [--mermaid]` | Mostra ondas e dependências |
| `sdd tasks next <spec>` | Tarefas prontas da menor onda, com agente/tier resolvidos |
| `sdd status [<spec>]` | Progresso das specs abertas (ou detalhe de uma) |
| `sdd status set <spec> <alvo> <valor>` | Única forma de mudar `status.yaml` (`T03 done`, `gate plan_approved`, `phase exec`, `review approved`) |
| `sdd check --task <id> [--spec <id>]` | Gates nos arquivos `owns` da tarefa + verificação de `owns` via git |
| `sdd check [--spec <id>] [--max-lines N]` | DoD completo: gates de `dod.gates`, cobertura (lcov) e rastreabilidade de AC |
| `sdd scaffold <brick> [--vars k=v ...] [--task <id>]` | Aplica um brick mason do stack (nunca sobrescreve) |
| `sdd import scan <caminho>` | Inventário somente leitura de agentes/skills/rules/comandos (Claude e Cursor) para o `/sdd-import` |
| `sdd doctor` | Verifica ambiente, config, kit, `kit.lock` e se o sync está em dia |
| `sdd hook format\|guard-bash` | Hooks chamados pelos arquivos gerados (interno) |

## Stack pack `flutter-clean-cubit`

Clean architecture por feature + Cubit + `Result` (Ok/Err) com Failure selado. Traz skills,
rules por camada, extensões dos agentes do core e os bricks `feature`, `failure`,
`datasource`, `repository`, `usecase` e `cubit`:

```sh
sdd scaffold failure --vars feature=auth
sdd scaffold repository --vars feature=auth --vars method=login --vars ac=AC-02
```

Os bricks assumem `Result<T, E>` selado com `Ok(value)`/`Err(error)` em
`scaffold.vars.result_import` (padrão `package:<app>/core/result/result.dart`).

## Overrides

Conteúdo específico do projeto vai em `.sdd/overrides/`, com a mesma estrutura do kit
(`agents/`, `skills/`, `rules/`, `commands/`, `templates/`). Um item com o mesmo nome
substitui o do kit; `disabled: true` no frontmatter o remove. Depois, `sdd sync`.
Nunca edite `.claude/` ou `.cursor/` gerados.

A spec pode ser indicada pelo id completo, `0001` ou `1`.

Flags globais: `--json`, `--verbose`, `--kit-path <dir>`, `--version`.
Saída do `check`: só falhas (`FAIL`), interferências (`INTF`) e o resumo; nunca o log bruto.
Exit codes: `0` ok, `1` falha de gate/validação, `2` erro de uso/config.
