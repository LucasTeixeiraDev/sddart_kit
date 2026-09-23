# BRIEF — `flutter_sdd`: CLI Dart + kit de Spec-Driven Development para apps Flutter

> Este arquivo é o briefing completo do projeto. Leia-o inteiro antes de qualquer ação.
> Releia a seção relevante no início de cada milestone. Ele é a fonte de verdade: se algo
> aqui estiver ambíguo ou conflitante, pergunte antes de decidir.

---

## 1. Contexto e objetivo

Sou desenvolvedor Flutter e quero uma estrutura de **Spec-Driven Development (SDD)** reutilizável
entre vários apps Flutter com arquitetura semelhante. O fluxo alvo é:

```
PRD / história de negócio
  → Analisar (ambiguidades, perguntas)            [gate humano]
  → Especificar e planejar (spec.md + plan.md)    [gate humano]
  → Quebrar em tarefas (DAG com donos de arquivo)
  → Onda 0: contratos de domain (sequencial)
  → Onda 1..N: data / cubits / UI em paralelo (subagentes)
  → Onda final: integração (DI, rotas)
  → Gates determinísticos (format, analyze, testes, cobertura, rastreabilidade)
  → Revisão contra a spec (agente somente leitura)
  → Pronto (DoD) → descrição de PR + promoção de lições
```

O projeto tem **duas partes no mesmo repositório**:

1. **O CLI `sdd`** (pacote Dart `flutter_sdd`): faz todo o trabalho determinístico.
2. **O kit** (conteúdo): agentes, comandos, skills, rules, templates e bricks mason.
   O CLI instala o kit nos projetos e gera os arquivos específicos de cada ferramenta
   (Claude Code e Cursor).

Vou usar o kit em **projetos da empresa e em projetos pessoais**. Já tenho skills e rules para
Claude e Cursor em um repositório da empresa, mas elas **não fazem parte deste desenvolvimento**:
serão importadas depois, projeto a projeto, pelo comando `/sdd-import` (ver 8.2 e 8.4).
Consequência de design: o `flutter_sdd` (kit core + stack pack) deve conter **apenas conhecimento
genérico**. Nada específico ou proprietário de uma empresa entra no kit; isso vive nos
`.sdd/overrides/` do projeto correspondente.

---

## 2. Princípios inegociáveis

1. **O CLI nunca chama LLM.** Ele valida, gera, executa gates e resume saídas. A orquestração
   de agentes é feita pela ferramenta (Claude Code / Cursor) via comandos `/sdd-*`.
2. **Fonte única de verdade.** O conteúdo canônico vive em `kit/` (no pacote) e em
   `.sdd/overrides/` (no projeto). As pastas `.claude/` e `.cursor/` geradas são saída de build.
3. **Estado em disco, não em conversa.** Cada fase produz um arquivo; a fase seguinte lê o arquivo.
4. **Um único escritor para estado.** `status.yaml` só é alterado pelo CLI (`sdd status set ...`),
   nunca editado por agentes, para evitar conflito entre subagentes paralelos.
5. **Tiers abstratos de modelo** (`deep`, `standard`, `fast`). O kit nunca cita nome de modelo;
   o `config.yaml` do projeto mapeia tier → modelo por ferramenta.
6. **Contract-first + posse de arquivos.** Tarefas paralelas codificam contra contratos da onda 0
   e cada tarefa declara os arquivos que possui. Duas tarefas da mesma onda nunca possuem o mesmo arquivo.
7. **Economia de tokens por design.** Saídas compactas, `--json` para agentes, pacotes de contexto
   mínimos por tarefa, nada carregado "sempre" além do essencial.
8. **Idempotência.** Rodar `sdd sync` duas vezes seguidas não gera diff. Arquivos do usuário
   fora das áreas gerenciadas nunca são tocados.

---

## 3. Stack de referência do stack pack `flutter-clean-cubit`

O primeiro stack pack deve refletir esta arquitetura (é a do app principal onde vou usar):

- **Clean architecture** por feature em `lib/features/<feature>/`:
  - `domain/`: entidades, contratos de repository, usecases, `failures/` (Failure selado por feature).
  - `data/`: datasources (HTTP com Dio; realtime com SignalR via `Stream`), DTOs, impl de repositories.
  - `presentation/`: pages, widgets, cubits (+ states).
- Fluxo: `Cubit → Usecase → Repository → Datasource`.
- Tratamento de erro funcional com tipo **`Result` (Ok/Err)**:
  - Datasources podem lançar exceptions técnicas e de negócio (ex.: `UserNotFoundException`).
  - **O repository é a fronteira**: mapeia Exception → Failure e retorna `Result`.
    Nenhuma exception atravessa o repository.
  - Erros não mapeados **não podem ser engolidos**: devem continuar chegando ao Crashlytics
    (captura global via `FlutterError.onError` / zona).
  - Erros de regra de negócio do backend viram Failures específicos da feature.
- Streams realtime (SignalR) são caso especial: documentar no stack pack como decisão
  configurável, não impor `Result` por evento.
- Lint: `very_good_analysis` + `custom_lint` (incl. regras próprias de arquitetura)
  + `dart_code_linter`, com `flutter analyze` bloqueando a CI.
- Testes: `bloc_test` + `mocktail` (confirme no `pubspec.yaml` do projeto real; não assuma).

O kit deve ser **genérico o suficiente** para outros projetos com a mesma estrutura, com tudo
que varia (paths, comandos, thresholds, regex de testes) vindo do `config.yaml`.

---

## 4. Estrutura do repositório a construir

```
flutter_sdd/
├── bin/sdd.dart
├── lib/
│   ├── flutter_sdd.dart
│   └── src/
│       ├── cli/                 # CommandRunner e comandos (camada fina)
│       ├── core/                # lógica pura e testável (sem IO direto)
│       │   ├── config/          # schema e parsing do config.yaml
│       │   ├── kit/             # carregamento do kit + overrides, resolução de camadas
│       │   ├── tasks/           # parsing de frontmatter, DAG, validação, ondas
│       │   ├── status/          # leitura/escrita de status.yaml
│       │   ├── gates/           # execução de gates, parsing de saídas, cobertura (lcov), rastreabilidade
│       │   └── adapters/        # tradução canônico → claude / cursor
│       └── infra/               # FileSystem, ProcessRunner, Logger (abstrações injetáveis)
├── kit/
│   ├── core/
│   │   ├── agents/
│   │   ├── commands/
│   │   ├── skills/
│   │   ├── rules/
│   │   └── templates/           # prd.md, analysis.md, spec.md, plan.md, task.md, review.md, agents-md-section.md
│   └── stacks/
│       └── flutter-clean-cubit/
│           ├── stack.yaml        # metadados, defaults de config, detecção
│           ├── skills/
│           ├── rules/
│           └── bricks/           # mason
├── test/
│   ├── core/...
│   └── fixtures/                 # projetos Flutter falsos mínimos (pubspec + lib/ + specs/)
├── docs/
│   ├── milestones.md             # checklist de progresso deste desenvolvimento (atualize a cada milestone)
│   ├── adapters.md               # formatos verificados de Claude Code e Cursor, com data e fonte
│   └── decisions.md              # decisões tomadas durante o desenvolvimento do CLI
├── README.md
├── CHANGELOG.md
└── pubspec.yaml
```

Pacotes sugeridos (verifique versões atuais no pub.dev): `args`, `yaml`, `yaml_edit`, `path`,
`glob`, `collection`, `mason` (uso programático), `mason_logger` ou `cli_util` para saída.
Justifique no `docs/decisions.md` qualquer dependência adicional.

**Resolução do kit:** o kit é distribuído junto com o pacote. Proponha no M0 a estratégia de
localização em runtime (ex.: `Isolate.resolvePackageUri(Uri.parse('package:flutter_sdd/'))` e subir
para a raiz do pacote) funcionando tanto via `dart pub global activate --source git` quanto
via `dart run`. O projeto registra a versão usada em `.sdd/kit.lock`.

---

## 5. Estrutura gerada em cada projeto Flutter

```
meu_app/
├── AGENTS.md                     # seção gerenciada entre marcadores; resto é do usuário
├── CLAUDE.md                     # contém @AGENTS.md (criar só se não existir; se existir, garantir a linha)
├── .sdd/
│   ├── config.yaml
│   ├── kit.lock
│   ├── overrides/                # mesma estrutura de kit/ (agents, skills, rules, commands, templates)
│   └── memory/
│       ├── decisions.md
│       └── learnings.md
├── .claude/                      # gerado
├── .cursor/                      # gerado
└── specs/
    └── 0042-login-biometria/
        ├── prd.md
        ├── analysis.md
        ├── spec.md
        ├── plan.md
        ├── tasks/T01-*.md ...
        ├── status.yaml
        └── review.md
```

**Seção gerenciada do AGENTS.md:** delimitada por `<!-- sdd:begin -->` e `<!-- sdd:end -->`.
O `sync` substitui apenas o conteúdo entre os marcadores. Conteúdo fixo curto (alvo: até ~80 linhas
na seção gerenciada): visão do fluxo SDD, comandos disponíveis, onde ficam specs e memória,
comandos de gate do projeto, e **ponteiros** (não conteúdo) para skills e `.sdd/memory/`.

**Cabeçalho de arquivos gerados:** todo arquivo gerado recebe um aviso
`gerado por sdd vX.Y.Z — não edite; use .sdd/overrides/ ou o kit`. Em arquivos com frontmatter,
o aviso vai **depois** do frontmatter (o frontmatter precisa ser a primeira coisa do arquivo).

---

## 6. Schemas

### 6.1 `.sdd/config.yaml`

```yaml
version: 1
kit:
  stack: flutter-clean-cubit
targets: [claude, cursor]          # ferramentas para as quais o sync gera arquivos
language: pt-BR                    # idioma dos textos do kit renderizados

project:
  features_path: lib/features
  test_path: test
  state_management: cubit
  error_handling: result           # result | exceptions
  generated_globs: ["**/*.g.dart", "**/*.freezed.dart", "**/*.mocks.dart"]

commands:
  format: dart format --set-exit-if-changed {files}
  analyze: flutter analyze --fatal-infos {files}
  test: flutter test {files}
  test_all: flutter test --coverage
  codegen: dart run build_runner build -d

dod:
  gates: [format, analyze, test, coverage, traceability]
  coverage:
    min: 80
    paths: ["lib/features/**/domain/**", "lib/features/**/presentation/**/cubit/**"]
  traceability:
    ac_pattern: "AC-\\d{2,}"       # IDs de critério de aceite na spec
    test_tag_pattern: "\\[(AC-\\d{2,})\\]"   # como o ID aparece na descrição do teste
  checklist:                        # itens verificados pelo revisor (não automatizáveis)
    - Nenhuma exception atravessa a fronteira do repository
    - Erros não mapeados continuam chegando ao Crashlytics
    - Failures de negócio do backend estão mapeados para Failures da feature

execution:
  max_fix_attempts: 2              # após isso, escalar tier ou bloquear para humano
  escalate_to: deep

memory:
  learnings_warn_after: 15         # sdd status alerta acima disso

models:                            # valor único vale para todos os targets
  deep: opus
  standard: sonnet
  fast: haiku
  # override opcional por ferramenta, se um dia precisar:
  # deep: { default: opus, cursor: <outro> }
```

O adapter de cada ferramenta é responsável por traduzir o nome do modelo para o formato que
aquela ferramenta aceita no frontmatter (ex.: alias vs. id completo), conforme verificado em
`docs/adapters.md`.

Valide o config com mensagens de erro claras (caminho do campo + o que se esperava).
Placeholders `{files}` recebem a lista de arquivos no modo escopado por tarefa; no modo
completo, são removidos.

### 6.2 Frontmatter de tarefa (`specs/<id>/tasks/Txx-*.md`)

```yaml
id: T03                            # obrigatório, único na spec
title: AuthRepositoryImpl retornando Result
wave: 1                            # inteiro >= 0
depends_on: [T01]                  # ids existentes, sempre de ondas anteriores
tier: standard                     # deep | standard | fast
agent: implementer                 # nome canônico do agente
owns:                              # arquivos que a tarefa cria/altera (obrigatório, >= 1)
  - lib/features/auth/data/repositories/auth_repository_impl.dart
  - test/features/auth/data/repositories/auth_repository_impl_test.dart
reads:                             # contexto mínimo; devem existir ou ser "owned" por dependência
  - lib/features/auth/domain/repositories/auth_repository.dart
exemplar: lib/features/profile/data/repositories/profile_repository_impl.dart   # opcional, deve existir
brick: repository                  # opcional: brick mason a aplicar antes de implementar
acceptance: [AC-02, AC-05]         # IDs que devem existir na spec.md
```

Corpo da tarefa: `## Objetivo`, `## Detalhes`, `## Pronto da tarefa` (sempre inclui
`sdd check --task <id>` verde).

### 6.3 `status.yaml` (escrito só pelo CLI)

```yaml
spec: 0042-login-biometria
phase: exec                        # analyze | spec | plan | tasks | exec | review | done
gates: { analysis_approved: true, plan_approved: true }
tasks:
  T01: { state: done, attempts: 1, tier_used: deep }
  T03: { state: in_progress, attempts: 0 }
  # states: pending | in_progress | done | failed | blocked
review: { state: pending, blockers: 0 }
```

### 6.4 Formato canônico de agente (`kit/**/agents/<nome>.md`)

Frontmatter canônico (superset, traduzido pelos adapters):

```yaml
name: implementer
description: <quando usar — é o que a ferramenta usa para rotear; seja específico>
tier: standard                     # tier padrão
tier_variants: [fast, standard, deep]   # opcional: gerar uma variante por tier
tools: [read, search, edit, write, bash]  # ferramentas abstratas
readonly: false
skills: [result-failure, cubit-patterns]  # opcional
```

Os adapters mapeiam `tools` abstratas para os nomes reais de cada ferramenta e `tier` para o
modelo do `config.yaml`. Quando houver `tier_variants`, gerar `sdd-implementer-fast`,
`sdd-implementer-standard`, `sdd-implementer-deep`, para que o orquestrador escolha o modelo
escolhendo o agente (não dependa de passar modelo na invocação, que não é portável).
Todos os agentes gerados usam prefixo `sdd-` para não colidir com agentes existentes do usuário.

Formato canônico para skills: pasta com `SKILL.md` (frontmatter `name`, `description`) + arquivos
de apoio. Para rules: markdown com frontmatter `description`, `globs`, `always` (bool).
Para comandos: markdown com frontmatter `description`, `args` (opcional).

---

## 7. Especificação dos comandos do CLI

Regras gerais: saída humana por padrão, `--json` estável e documentado para uso por agentes,
exit codes consistentes (`0` ok, `1` falha de gate/validação, `2` erro de uso/config),
nada de logs verbosos por padrão (`--verbose` para debug). Toda saída pensada para ser curta.

| Comando | Função |
|---|---|
| `sdd init [--stack <nome>] [--yes]` | Detecta o projeto (pubspec, Flutter, deps como `flutter_bloc`, `analysis_options.yaml`, pasta de features), cria `.sdd/` com config preenchido, `kit.lock`, `memory/`, e roda `sync`. Interativo por padrão; `--yes` aceita os defaults detectados. |
| `sdd sync [--check]` | Resolve kit (core + stack) + overrides e gera os arquivos de cada `target`, a seção gerenciada do AGENTS.md e o CLAUDE.md. Remove arquivos gerados órfãos (só os que têm o cabeçalho do sdd). `--check` não escreve e falha se algo estiver desatualizado (uso em CI). |
| `sdd new "<título>"` | Cria `specs/NNNN-slug/` com `prd.md` do template e `status.yaml` inicial. Numeração sequencial de 4 dígitos. |
| `sdd tasks validate <spec>` | Valida schema de todas as tarefas, ids únicos, dependências existentes, DAG sem ciclos, dependências sempre em ondas anteriores, conflito de `owns` na mesma onda, `exemplar` existente, `reads` existentes ou possuídos por uma dependência, `acceptance` presentes na spec, e AC da spec sem nenhuma tarefa (aviso). |
| `sdd tasks graph <spec> [--mermaid]` | Mostra as ondas e dependências (texto compacto ou Mermaid). |
| `sdd tasks next <spec> [--json]` | Lista tarefas prontas para executar (dependências `done`, estado `pending`/`failed` com tentativas restantes), agrupadas pela menor onda disponível, com agente resolvido (considerando tier e escalonamento). |
| `sdd status [<spec>] [--json]` | Resumo do progresso. Sem argumento: todas as specs abertas. Alerta se `learnings.md` passou do limite. |
| `sdd status set <spec> <alvo> <valor>` | Única forma de mutar estado: `T03 done`, `T03 failed` (incrementa tentativas), `gate plan_approved`, `phase review`, etc. |
| `sdd check [--spec <id>] [--task <id>] [--json]` | Roda os gates. Com `--task`: format/analyze/test apenas nos arquivos `owns`, **e verifica via `git diff` que só arquivos `owns` (+ `generated_globs`) foram alterados**. Sem `--task`: gates completos do DoD, incluindo cobertura (parse de `coverage/lcov.info` filtrado por `dod.coverage.paths`) e rastreabilidade (todo AC da spec aparece em ao menos um teste segundo `test_tag_pattern`). |
| `sdd scaffold <brick> [--vars k=v]` | Aplica um brick do stack pack via API do mason. |
| `sdd import scan <caminho> [--json]` | Inventário determinístico de agentes/skills/rules/comandos existentes (Claude e Cursor) para o `/sdd-import`. Somente leitura. |
| `sdd doctor` | Verifica ambiente: Flutter/Dart no PATH, git, config válido, kit.lock compatível, sync em dia. |

**Formato de saída do `check` (essencial para economia de tokens):** nunca repassar o log bruto.
Parsear e emitir só falhas, no formato:

```
FAIL analyze  lib/features/auth/data/.../auth_repository_impl.dart:42  avoid_dynamic_calls
FAIL test     test/features/auth/.../auth_repository_impl_test.dart  "[AC-02] retorna Err quando usuário bloqueado"  Expected: Err<BlockedUserFailure> Actual: Ok
FAIL owns     lib/core/di/injector.dart  alterado fora de owns
PASS format
3 falhas · 1 gate ok
```

Para testes, use `flutter test --reporter json` e extraia apenas os testes que falharam
(nome + primeira linha útil do erro, truncada). Para analyze, parse da saída em formato
de máquina se disponível. Limite configurável de linhas por gate (`--max-lines`, default 20).

---

## 8. Conteúdo do kit

Textos do kit em **pt-BR**. Código, identificadores e flags do CLI em **inglês**.
Cada agente, skill e comando deve ser **curto e objetivo**: o que fazer, o que ler,
o que produzir, o que é proibido, e formato de retorno. Nada de prosa decorativa.

### 8.1 Agentes (`kit/core/agents/`)

| Agente | Tier | Tools | Papel |
|---|---|---|---|
| `explorer` | fast | read, search | Mapeia o código relevante para uma spec; devolve lista curta de arquivos, contratos existentes e exemplares candidatos. Somente leitura. |
| `analyst` | deep | read, search, write | Lê `prd.md` + saída do explorer; escreve `analysis.md` com ambiguidades, perguntas numeradas, riscos, features impactadas. Não propõe solução técnica. |
| `architect` | deep | read, search, write | Com a análise aprovada, escreve `spec.md` (requisitos + critérios `AC-xx` em Given/When/Then) e `plan.md` (mapeamento por camada, contratos, Failures, decisões). Consulta `.sdd/memory/decisions.md`. |
| `planner` | deep | read, search, write | Gera `tasks/*.md` seguindo a skill `task-breakdown`; roda `sdd tasks validate` até passar. |
| `implementer` | standard (variantes fast/standard/deep) | read, search, edit, write, bash | Executa **uma** tarefa. Só altera `owns`. Aplica `brick` se houver. Segue o `exemplar`. Roda `sdd check --task <id>`. Não edita `status.yaml`. |
| `reviewer` | deep | read, search, bash (só para `sdd check` e `git diff`) | Revisa o diff da spec contra `spec.md`, `plan.md` e `dod.checklist`. Escreve `review.md` com achados `blocker`/`major`/`minor` (arquivo:linha) e seção **Lições candidatas**. Não altera código. |

**Formato de retorno obrigatório do implementer** (para não inflar o contexto do orquestrador):

```
T03 | done|failed|blocked
alterados: <n> arquivos
gates: ok | <resumo de 1 linha>
nota: <no máximo 2 linhas, só se relevante>
```

### 8.2 Comandos (`kit/core/commands/`)

- `/sdd-analyze <spec>`: explorer → analyst → apresenta perguntas ao humano e **para**.
  Após respostas registradas em `analysis.md`, o humano aprova: `sdd status set <spec> gate analysis_approved`.
- `/sdd-spec <spec>`: architect → apresenta resumo do plano e **para** para aprovação (`plan_approved`).
- `/sdd-tasks <spec>`: planner → `sdd tasks validate` → mostra `sdd tasks graph`.
- `/sdd-exec <spec>`: loop do orquestrador (a sessão principal, nunca um subagente):
  1. `sdd tasks next <spec> --json`
  2. para cada tarefa pronta da onda: `sdd status set ... in_progress` e dispara o agente
     `sdd-implementer-<tier>` **em paralelo**, passando só o caminho do arquivo da tarefa
  3. ao receber cada retorno: confirma com `sdd check --task <id> --json` e marca `done`/`failed`
  4. `failed` com tentativas esgotadas → escalar para `execution.escalate_to` uma vez; depois `blocked` e parar para o humano
  5. repetir até não haver tarefas prontas; então `sdd check --spec <spec>`
- `/sdd-review <spec>`: reviewer → se houver `blocker`/`major`, o orquestrador cria tarefas
  de correção (`Txx-fix-*.md`, nova onda) e volta ao `/sdd-exec`. Máximo de 2 ciclos de revisão.
- `/sdd-close <spec>`: confirma DoD completo, gera descrição de PR (resumo, ACs cobertos,
  decisões), e conduz com o humano a **promoção das lições candidatas** (ver 8.5).
- `/sdd-run <spec>`: encadeia os anteriores respeitando os dois gates humanos.
- `/sdd-import <caminho>`: importa skills/rules/agentes preexistentes para o projeto atual
  (ver 8.4). Pode ser executado a qualquer momento e em qualquer projeto.

### 8.3 Skills do core (`kit/core/skills/`)

- `spec-writing`: estrutura de spec, critérios `AC-xx` testáveis em Given/When/Then, fora de escopo explícito.
- `task-breakdown`: contract-first (onda 0 = domain), tarefas de 1 a ~5 arquivos, `owns` sem sobreposição
  na mesma onda, `reads` mínimo, sempre indicar `exemplar` quando houver padrão existente, escolher tier
  pelo risco (contratos e fluxos complexos = deep; implementação com contrato + exemplar = standard;
  repetição de padrão = fast), cada AC coberto por ao menos uma tarefa.
- `context-packaging`: como montar o contexto mínimo de uma tarefa.
- `dod-check`: como verificar o checklist e registrar evidência.
- `memory-curation`: o ciclo das lições (ver 8.5).

### 8.4 Stack pack `flutter-clean-cubit`

- **Skills:** `clean-arch-layers`, `result-failure` (Ok/Err, Failure selado por feature, mapeamento na
  fronteira do repository, preservação do Crashlytics, erros de negócio do backend, caso SignalR),
  `cubit-patterns` (estados, emissões, sem lógica de negócio no widget), `bloc-testing`
  (bloc_test + mocktail, nome de teste com `[AC-xx]`), `dio-datasource`.
- **Rules por glob:** `domain/**` (sem imports de Flutter/Dio/data), `data/**` (repository nunca
  deixa exception escapar), `presentation/**` (cubit não conhece datasource), `test/**` (padrão de
  nome e tag de AC).
- **Bricks mason:** `feature` (esqueleto das 3 camadas), `failure` (sealed), `usecase`,
  `repository` (contrato + impl + teste), `cubit` (cubit + state + teste).
- **`stack.yaml`:** defaults de `config.yaml` para este stack e heurísticas de detecção usadas pelo `init`.
- **Importação (`/sdd-import <caminho>`), repetível e por projeto:**
  1. O CLI faz o inventário determinístico: `sdd import scan <caminho> --json` lista arquivos de
     agentes, skills, rules e comandos (Claude e Cursor), com tipo detectado, tamanho e duplicatas
     prováveis entre as duas ferramentas.
  2. Um agente (tier deep) classifica cada item: **override do projeto** (padrão para tudo que é
     específico), **candidato ao kit** (genérico de verdade), **já coberto pelo kit** ou **descartar**,
     com motivo, e apresenta a tabela.
  3. **Aguarda aprovação humana** item a item ou em bloco.
  4. Converte os aprovados para o formato canônico e grava em `.sdd/overrides/` do projeto atual,
     deduplicando versões Claude/Cursor do mesmo conteúdo; depois roda `sdd sync`.
  5. Itens "candidato ao kit" **não** são escritos no kit: gera um arquivo
     `.sdd/kit-proposals.md` com a proposta, para eu revisar e levar ao repositório do `flutter_sdd`
     manualmente (evita vazar conteúdo de um projeto para o kit compartilhado).
  O caminho de origem nunca é modificado.

### 8.5 Memória (`.sdd/memory/`)

- `decisions.md`: decisões de arquitetura que atravessam features, formato ADR enxuto
  (`## D-NNN · título (AAAA-MM)`, Decisão, Motivo, Origem).
- `learnings.md`: **caixa de entrada**, não destino. Só o `/sdd-close` escreve nele, a partir das
  lições candidatas do `review.md` aprovadas pelo humano.
- Promoção (conduzida pelo `/sdd-close` com o humano): verificável por máquina → regra de lint
  (custom_lint); convenção geral de Flutter/stack → proposta para o kit; específica do projeto →
  `.sdd/overrides/`; escolha com trade-off → `decisions.md`. Após promovida, a lição sai do `learnings.md`.
- Nenhum dos dois é carregado sempre: o AGENTS.md só aponta para eles. `architect` e `reviewer`
  leem por padrão; `implementer` não.

### 8.6 Hooks (opcional, controlado por config)

Gerar, quando habilitado, hook de pós-edição que roda `dart format` no arquivo `.dart` editado.
No Claude Code isso vai em `.claude/settings.json`; no Cursor, em `.cursor/hooks.json`.
**Faça merge** apenas das chaves gerenciadas pelo sdd, preservando o restante do arquivo do usuário.

---

## 9. Adapters (Claude Code e Cursor)

Os formatos dessas ferramentas mudam com frequência. **Antes de implementar os adapters (M2),
consulte a documentação oficial atual** e registre em `docs/adapters.md` o formato verificado,
a URL e a data. Pontos de partida a confirmar:

- **Claude Code:** subagentes em `.claude/agents/<nome>.md` (frontmatter com `name`, `description`,
  `tools`, `model`); skills em `.claude/skills/<nome>/SKILL.md`; comandos em `.claude/commands/`;
  hooks em `.claude/settings.json`; `CLAUDE.md` suporta import `@AGENTS.md`.
  Docs: https://code.claude.com/docs/en/subagents (e o mapa de docs do Claude Code).
- **Cursor:** subagentes em `.cursor/agents/` (o Cursor também lê `.claude/agents/`; em nomes
  duplicados, `.cursor/` tem precedência); rules em `.cursor/rules/*.mdc` (`description`, `globs`,
  `alwaysApply`); skills; comandos; hooks em `.cursor/hooks.json`.
  Docs: https://cursor.com/docs/context/subagents, /rules, /skills.

Como o Cursor lê `.claude/agents/`, avalie e documente se vale gerar agentes nos dois lugares
ou só em um (evitar listagem duplicada). Deixe configurável.

Os adapters devem ser implementados como estratégias isoladas (`ClaudeAdapter`, `CursorAdapter`)
sobre um modelo canônico em memória, para que adicionar outra ferramenta no futuro seja só um
novo adapter.

---

## 10. Qualidade do próprio CLI (Definition of Done do `flutter_sdd`)

- `dart analyze` sem issues com `very_good_analysis`.
- `dart format` aplicado.
- Lógica em `core/` sem IO direto: `FileSystem` e `ProcessRunner` injetados (use
  `package:file` com `MemoryFileSystem` nos testes, se fizer sentido).
- Testes unitários para: parsing/validação de config, frontmatter de tarefas, DAG (ciclos,
  ondas, conflitos de `owns`), `tasks next`, escrita de status, resolução kit + overrides,
  cada adapter (snapshot dos arquivos gerados), seção gerenciada do AGENTS.md, parsing de
  `flutter test --reporter json`, parsing de lcov, rastreabilidade de AC.
- Testes de integração com projetos em `test/fixtures/` (sem exigir Flutter SDK, via `ProcessRunner` falso).
- Cobertura ≥ 80% em `lib/src/core/`.
- `sdd sync` idempotente (teste que roda duas vezes e compara).
- `dart compile exe bin/sdd.dart` funciona.
- README com: instalação (`dart pub global activate --source git <url>`), quickstart
  (`init` → `new` → `/sdd-run`), referência de comandos, como criar um stack pack, como usar overrides.

---

## 11. Plano de execução em milestones

Trabalhe **um milestone por vez**. Ao final de cada um: rode os testes, atualize
`docs/milestones.md`, faça um commit (`feat(mN): ...`), me mostre um resumo de até 10 linhas
(o que foi feito, decisões, pendências) e **pare para aprovação** antes do próximo.

- **M0 — Plano e perguntas (em plan mode, sem escrever código).**
  Leia este brief, consulte as docs de Claude Code e Cursor, e me entregue: plano de implementação
  por milestone, estratégia de resolução do kit, riscos, e lista numerada de perguntas sobre
  ambiguidades. Aguarde minhas respostas.
- **M1 — Esqueleto do CLI.** `pubspec`, lints, `CommandRunner`, infra (FileSystem, ProcessRunner,
  Logger), schema e parsing do `config.yaml`, `sdd init` (com detecção) e `sdd doctor`.
- **M2 — Kit core + sync.** Formatos canônicos, carregamento kit + overrides, adapters Claude e
  Cursor, AGENTS.md gerenciado, CLAUDE.md, cabeçalhos, remoção de órfãos, `sync --check`,
  `docs/adapters.md`. Conteúdo do kit core pode estar em versão inicial.
- **M3 — Specs e tarefas.** `sdd new`, `tasks validate/graph/next`, `status` e `status set`.
- **M4 — Gates.** `sdd check` (escopado por tarefa e completo), verificação de `owns` via git,
  cobertura por lcov, rastreabilidade de AC, saída compacta e `--json`.
- **M5 — Stack pack `flutter-clean-cubit` e importação.** Skills, rules, bricks, `stack.yaml`,
  `sdd scaffold`, `sdd import scan` e o comando `/sdd-import`. Testar a importação com uma pasta
  de exemplo em `test/fixtures/` (não com meus arquivos reais).
- **M6 — Orquestração e memória.** Versão final dos agentes e comandos `/sdd-*`, fluxo de memória,
  hooks opcionais, README completo.
- **M7 — Dogfooding.** Em uma fixture realista (ou em um app que eu indicar), rode o fluxo completo
  com uma feature pequena de exemplo, registre atritos encontrados e proponha ajustes.

---

## 12. Como trabalhar neste repositório (economia de tokens durante o desenvolvimento)

- Use subagentes de exploração/leitura para pesquisar documentação e varrer arquivos, devolvendo
  só resumos; mantenha a sessão principal enxuta.
- Não cole saídas longas de comandos na conversa: resuma falhas.
- Ao retomar uma sessão, leia `docs/milestones.md` e `docs/decisions.md` antes de continuar,
  em vez de reler todo o código.
- Não reescreva arquivos inteiros para mudanças pequenas.
- Se uma correção falhar duas vezes seguidas, pare e me explique o impasse.

## 13. O que NÃO fazer

- Não fazer o CLI chamar APIs de LLM.
- Não colocar nomes de modelos dentro do kit (só no `config.yaml`).
- Não deixar agentes editarem `status.yaml` diretamente.
- Não sobrescrever arquivos do usuário fora das áreas gerenciadas (AGENTS.md fora dos marcadores,
  settings/hooks fora das chaves do sdd, agentes/skills sem o cabeçalho do sdd).
- Não inventar formatos de Claude Code/Cursor sem verificar a documentação.
- Não criar um `memory.md` genérico sempre carregado.
- Não avançar de milestone sem minha aprovação.