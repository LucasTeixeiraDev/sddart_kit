# flutter_sdd

CLI `sdd` + kit de **Spec-Driven Development** para apps Flutter, com geração de
configuração para **Claude Code** e **Cursor**.

O CLI faz todo o trabalho determinístico: valida, gera arquivos, executa gates e resume
saídas. Ele **nunca chama LLM**. A orquestração dos agentes fica com a ferramenta, pelos
comandos `/sdd-*`.

```
PRD → /sdd-analyze [aprovação] → /sdd-spec [aprovação] → /sdd-tasks → /sdd-exec (ondas em paralelo)
    → sdd check (gates) → /sdd-review → /sdd-close (PR + lições)
```

## Instalação

Requisitos: Dart ≥ 3.9, Flutter (para os gates do app) e git.

```sh
dart pub global activate --source git https://github.com/LucasTeixeiraDev/sddart_kit.git
sdd --version
```

`~/.pub-cache/bin` precisa estar no `PATH`: os hooks gerados chamam `sdd`, e o
`sdd doctor` avisa se não estiver.

Executável compilado (`dart compile exe bin/sdd.dart -o sdd`): aponte para o kit com
`--kit-path <dir>` ou `SDD_KIT_PATH=<repo>/kit`. A ordem de resolução é flag, depois
variável de ambiente, depois o pacote instalado.

## Quickstart

```sh
cd meu_app
sdd init                  # detecta o projeto, cria .sdd/ e gera .claude/, .cursor/, AGENTS.md
sdd new "Login com biometria"
# preencha specs/0001-login-com-biometria/prd.md
```

No Claude Code ou no Cursor:

```
/sdd-run 0001
```

O fluxo para em dois gates humanos: aprovação da análise e aprovação do plano. Também para
em tarefas bloqueadas ou no limite de ciclos de revisão. Para retomar, rode `/sdd-run`
de novo: ele continua da fase em que parou.

## Comandos do CLI

| Comando | Função |
|---|---|
| `sdd init [--stack <nome>] [--yes] [--force]` | Detecta o projeto, cria `.sdd/` (config, `kit.lock`, memória, overrides) e roda `sync` |
| `sdd sync [--check]` | Gera `.claude/`, `.cursor/`, `.sdd/templates/`, a seção do `AGENTS.md` e o `CLAUDE.md`; `--check` só verifica (CI) |
| `sdd new "<título>"` | Cria `specs/NNNN-slug/` com `prd.md` e `status.yaml` |
| `sdd tasks validate <spec>` | Valida schema, DAG (ciclos, ondas), `owns`, `reads`, `exemplar`, agente/tier e ACs |
| `sdd tasks graph <spec> [--mermaid]` | Ondas e dependências com o estado de cada tarefa |
| `sdd tasks next <spec>` | Tarefas prontas da menor onda, com agente e tier resolvidos (tentativas e escalonamento) |
| `sdd status [<spec>]` | Progresso das specs abertas (ou detalhe de uma); avisa se `learnings.md` passou do limite |
| `sdd status set <spec> <alvo> <valor>` | **Única** forma de mudar `status.yaml`: `T03 done`, `gate plan_approved`, `phase exec`, `review approved blockers=0` |
| `sdd check --task <id> [--spec <id>]` | format/analyze/test nos `owns` da tarefa + verificação de `owns` via git |
| `sdd check [--spec <id>] [--max-lines N]` | DoD completo: gates de `dod.gates`, cobertura (lcov) e rastreabilidade de AC |
| `sdd scaffold <brick> [--vars k=v ...] [--task <id>]` | Aplica um brick mason do stack (nunca sobrescreve) |
| `sdd import scan <caminho>` | Inventário somente leitura de agentes, skills, rules e comandos existentes |
| `sdd doctor` | Ambiente (Flutter, Dart, git, `sdd` no PATH), config, `kit.lock` e sync em dia |
| `sdd hook format\|guard-bash\|guard-write` | Hooks chamados pelos arquivos gerados (uso interno) |

- **Flags globais:** `--json` (saída estável para agentes), `--verbose`, `--kit-path <dir>`, `--version`.
- **Spec:** pode ser indicada pelo id completo, `0001` ou `1`.
- **Exit codes:** `0` ok; `1` falha de gate, validação ou transição; `2` erro de uso ou config.

A saída do `check` mostra só falhas, nunca o log bruto:

```
FAIL analyze   lib/features/auth/data/auth_repository_impl.dart:42  avoid_dynamic_calls: ...
FAIL test      test/features/auth/.../auth_repository_impl_test.dart  "[AC-02] ..."  Expected: ... Actual: ...
INTF analyze   lib/features/auth/.../login_cubit.dart:3  uri_does_not_exist: ...  (T04 em andamento)
PASS format
3 falhas · 1 gates ok
```

`INTF` marca uma falha causada por um arquivo de outra tarefa da mesma onda ainda em
andamento. Nesse caso o orquestrador recheca ao fim da onda, sem gastar tentativa.

## Comandos `/sdd-*` (Claude Code e Cursor)

| Comando | O que faz |
|---|---|
| `/sdd-analyze <spec>` | explorer → analyst → perguntas em `analysis.md`; para para o humano |
| `/sdd-spec <spec>` | architect → `spec.md` (ACs Given/When/Then) e `plan.md`; para para aprovação |
| `/sdd-tasks <spec>` | planner → `tasks/Txx-*.md` validadas; mostra o grafo |
| `/sdd-exec <spec>` | Loop do orquestrador: ondas em paralelo, `sdd check --task`, commit por onda na branch `sdd/<spec>` |
| `/sdd-review <spec>` | Reviewer somente leitura → `review.md`; blockers/majors viram tarefas de correção |
| `/sdd-close <spec>` | DoD, `pr.md` e promoção das lições para a memória |
| `/sdd-run <spec>` | Encadeia tudo, retomando da fase atual |
| `/sdd-import <caminho>` | Importa skills/rules/agentes existentes para `.sdd/overrides/`, com aprovação |

Os comandos são gerados como skills de invocação **só manual**
(`disable-model-invocation: true`) nas duas ferramentas.

Os agentes têm o prefixo `sdd-`: explorer, analyst, architect, planner,
implementer-{fast,standard,deep}, reviewer e importer. O modelo é escolhido pelo tier, e o
orquestrador escolhe o tier escolhendo o agente.

## Configuração (`.sdd/config.yaml`)

Criado pelo `init` com tudo preenchido. Camadas: defaults do core → `config_defaults` do
stack → este arquivo. Erros mostram o caminho do campo, por exemplo
`commands.test: esperado string, recebido lista`.

```yaml
version: 1
kit: {stack: flutter-clean-cubit}
targets: [claude, cursor]
language: pt-BR                     # reservado: o kit só existe em pt-BR
project:
  features_path: lib/features
  test_path: test
  error_handling: result
  generated_globs: ["**/*.g.dart", "**/*.freezed.dart", "**/*.mocks.dart"]
commands:                           # {files} recebe os arquivos no modo tarefa
  format: dart format --output=none --set-exit-if-changed {files}
  analyze: dart analyze --format=machine --fatal-infos {files}
  test: flutter test {files}        # --reporter json é adicionado pelo sdd
  test_all: flutter test --coverage
  custom_lint: dart run custom_lint # gates extras: qualquer nome com comando
dod:
  gates: [format, analyze, custom_lint, test, coverage, traceability]
  coverage: {min: 80, paths: ["lib/features/**/domain/**"]}
  traceability: {ac_pattern: "AC-\\d{2,}", test_tag_pattern: "\\[(AC-\\d{2,})\\]"}
  checklist: [Nenhuma exception atravessa a fronteira do repository]
execution:
  max_fix_attempts: 2               # falhas no tier da tarefa antes de escalar
  escalate_to: deep                 # uma tentativa escalada; depois, blocked
  max_review_cycles: 2
memory: {learnings_warn_after: 15}
models:                             # tier → modelo; valor único ou por ferramenta
  deep: {default: opus, cursor: claude-opus-5-5}
  standard: {default: sonnet, cursor: claude-sonnet-5}
  fast: {default: haiku, cursor: claude-sonnet-5}
hooks: {format_on_edit: false}
scaffold:
  vars: {result_import: "package:{package}/core/result/result.dart"}
adapters:
  cursor: {skills: shared, agents: own}
```

Sem id do Cursor para um tier, o agente usa `model: inherit`, e `sync` e `doctor` avisam.

## Estrutura no projeto

```
AGENTS.md            # seção entre <!-- sdd:begin --> e <!-- sdd:end -->; o resto é seu
CLAUDE.md            # contém @AGENTS.md
.sdd/
  config.yaml  kit.lock  generated.json
  overrides/           # seu conteúdo (mesma estrutura do kit)
  memory/decisions.md  memory/learnings.md
  templates/           # templates de fase (gerados)
.claude/  .cursor/     # gerados: não edite
specs/NNNN-slug/       # prd, analysis, spec, plan, tasks/, status.yaml, review, pr
```

Todo arquivo gerado leva o aviso `gerado por sdd vX.Y.Z — não edite`. O `sync` nunca toca
em arquivos sem esse aviso. Se um arquivo seu estiver no caminho de um gerado, o `sync`
reporta conflito em vez de sobrescrever. Arquivos gerados que deixaram de existir no kit
são removidos.

## Overrides

`.sdd/overrides/` tem a mesma estrutura do kit: `agents/`, `skills/`, `rules/`, `commands/`,
`templates/` e `bricks/`.

- **Substituir:** um item com o mesmo nome substitui o do kit.
- **Remover:** `disabled: true` no frontmatter remove o item.
- **Estender um agente:** acrescenta skills e texto sem copiar o agente:
  ```markdown
  ---
  extend: true
  skills: [api-errors]
  ---
  Use o cliente HTTP `ApiClient`, nunca `Dio` direto.
  ```
- O conteúdo pode usar variáveis do config, como `{{sdd:project.features_path}}`.

Depois de editar, rode `sdd sync`. Para trazer conteúdo que você já tem (de outro
repositório, Claude ou Cursor), use `/sdd-import <caminho>`.

## Memória

- `decisions.md`: decisões de arquitetura no formato ADR enxuto
  (`## D-NNN · título (AAAA-MM)`). O architect e o reviewer leem.
- `learnings.md`: caixa de entrada, não destino. Só o `/sdd-close` escreve, com lições
  aprovadas por você.
- **Promoção:** cada lição é promovida para o lugar certo e sai do `learnings.md`:
  - verificável por máquina → regra de lint;
  - convenção geral → `.sdd/kit-proposals.md`;
  - específica do projeto → `.sdd/overrides/`;
  - escolha com trade-off → `decisions.md`.
- Nenhum dos dois arquivos é carregado sempre: o `AGENTS.md` só aponta para eles.

## Hooks

- **Format-on-edit** (`hooks.format_on_edit: true`): roda `dart format` em cada `.dart`
  editado pelo agente.
  - Com Claude entre os targets, o hook vai só em `.claude/settings.json`, porque o Cursor
    também executa esses hooks. Sem Claude, vai em `.cursor/hooks.json`.
  - O merge mexe só nas entradas do sdd e preserva o resto do arquivo.
- **Guard do reviewer (Claude):** hooks `PreToolUse` no próprio agente bloqueiam Bash fora
  de `sdd check`, `git diff` e `git log`, e gravação fora de `specs/*/review.md`
  (`write_allow`).
  - Hooks de agentes do projeto só rodam depois que o workspace é marcado como confiável
    (não em `claude -p`). Por isso a regra também está no prompt.
  - No Cursor, o reviewer é `readonly`.

## CI

```sh
sdd sync --check          # arquivos gerados em dia com o kit e o config
sdd check --spec 0001     # DoD completo da spec
```

## Stack pack `flutter-clean-cubit`

Clean architecture por feature, Cubit e `Result` (Ok/Err) com Failure selado:

- **Skills:** `clean-arch-layers`, `result-failure`, `cubit-patterns`, `bloc-testing`,
  `dio-datasource`.
- **Rules:** uma por camada (domain, data, presentation, tests).
- **Agentes:** extensões dos agentes do core.
- **Bricks:**

```sh
sdd scaffold feature --vars feature=auth          # pastas das 3 camadas
sdd scaffold failure --vars feature=auth          # sealed AuthFailure
sdd scaffold datasource --vars feature=auth --vars method=login
sdd scaffold repository --vars feature=auth --vars method=login --vars ac=AC-02
sdd scaffold usecase --vars feature=auth --vars name=login
sdd scaffold cubit --vars feature=auth --vars name=login
```

- **Contrato do `Result`:** os bricks assumem `Result<T, E>` selado com `Ok(value)` e
  `Err(error)`, importado de `scaffold.vars.result_import`. Para outro contrato, sobrescreva
  os bricks em `.sdd/overrides/bricks/`.
- **Exceptions:** o repository captura só `Exception`. As não mapeadas são reportadas via
  `FlutterError.reportError`, chegando ao Crashlytics, e viram `UnexpectedFailure`. `Error`
  nunca é capturado.

## Como criar um stack pack

```
kit/stacks/<nome>/
  stack.yaml     # obrigatório
  skills/<n>/SKILL.md   rules/<n>.md   agents/<n>.md (extend: true)   bricks/<n>/
```

```yaml
name: meu-stack
description: Uma linha.
expected_dependencies: [flutter_riverpod]        # o init avisa se faltar
detect:                                          # pontuação usada pelo init
  min_score: 3
  signals:
    - {dependency: flutter_riverpod, score: 2}
    - {path: lib/features, score: 1}
gate_requirements: {custom_lint: custom_lint}    # gate só entra se a dependência existir
config_defaults:                                 # mesmo formato do config.yaml
  project: {features_path: lib/features}
```

- **Formatos canônicos:**
  - agente: `description`, `tier`, `tools`, `readonly`, `skills`, `bash_allow`, `write_allow`;
  - skill: `description` no `SKILL.md`;
  - rule: `description`, `globs`, `always`;
  - comando: `description`, `args`.

  Detalhes na skill `sdd-import-conversion`.
- **Restrições do conteúdo:** só conhecimento genérico. Nunca nomes de modelo (use tiers) e
  nada proprietário.
- **Teste local:** `sdd --kit-path <repo>/kit sync` num app de teste.

## Desenvolvimento do flutter_sdd

```sh
dart test                          # UPDATE_GOLDENS=1 dart test regrava os snapshots dos adapters
dart analyze
dart format bin lib test           # kit/ tem templates mustache: fora do format e do analyzer
dart compile exe bin/sdd.dart
```

- `docs/milestones.md`: progresso do desenvolvimento.
- `docs/decisions.md`: decisões tomadas.
- `docs/adapters.md`: formatos verificados de Claude Code e Cursor, com fonte e data.
- `docs/dogfooding.md`: fluxo completo real, atritos encontrados e ajustes.

## Licença

A definir.
