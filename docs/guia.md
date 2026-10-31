# Guia de uso do sdd

Passo a passo para usar o `sdd` num app Flutter novo, trazendo as suas próprias skills e
rules. No fim do guia, você terá uma feature entregue pelo fluxo completo: PRD → análise →
spec → tarefas → implementação em paralelo → revisão → PR.

Os exemplos de saída são reais (sdd 0.1.0). Onde aparece `0001`, use o número da sua spec.

**Sumário**
1. [Conceitos em 2 minutos](#1-conceitos-em-2-minutos)
2. [Preparar o app](#2-preparar-o-app)
3. [Inicializar o sdd no app](#3-inicializar-o-sdd-no-app)
4. [Trazer as suas skills e rules](#4-trazer-as-suas-skills-e-rules)
5. [Sua primeira feature, passo a passo](#5-sua-primeira-feature-passo-a-passo)
6. [Referência do CLI](#6-referência-do-cli)
7. [Referência dos comandos `/sdd-*`](#7-referência-dos-comandos-sdd)
8. [Situações comuns](#8-situações-comuns)
9. [CI](#9-ci)
10. [Glossário](#10-glossário)

---

## 1. Conceitos em 2 minutos

**Duas peças.**
- O **CLI `sdd`** roda no terminal e faz só trabalho determinístico: cria arquivos, valida,
  roda format/analyze/testes e guarda o estado. Ele nunca chama um LLM.
- Os **comandos `/sdd-*`** rodam dentro do Claude Code ou do Cursor e orquestram os agentes.
  Eles chamam o CLI o tempo todo.

**Spec.** Cada feature é uma pasta `specs/NNNN-slug/` com os arquivos de cada fase: `prd.md`,
`analysis.md`, `spec.md`, `plan.md`, `tasks/`, `review.md`, `pr.md` e `status.yaml` (o estado).

**Fases e gates humanos.**
```
analyze ──[você aprova a análise]──> spec ──[você aprova o plano]──> tasks → exec → review → done
```
Nenhum agente passa de um gate sem o seu "ok".

**Tarefas, ondas e `owns`.**
- O plano vira tarefas (`T01`, `T02`...) em **ondas**. A onda 0 tem os contratos de domain;
  as ondas seguintes trazem data, cubits e UI em paralelo; a última faz a integração.
- Cada tarefa declara os arquivos que **possui** (`owns`). Duas tarefas da mesma onda nunca
  possuem o mesmo arquivo, e é isso que permite rodá-las em paralelo.

**Agentes e tiers.**
- Os agentes gerados têm o prefixo `sdd-`: explorer, analyst, architect, planner,
  implementer, reviewer e importer.
- Cada agente tem um tier (`deep`, `standard`, `fast`), e o `config.yaml` define qual modelo
  cada tier usa.

**Arquivos seus × gerados.**
- **Gerados (não edite):** `.claude/`, `.cursor/`, a seção entre `<!-- sdd:begin -->` e
  `<!-- sdd:end -->` do `AGENTS.md` e `.sdd/templates/`.
- **Seus:** `.sdd/config.yaml`, `.sdd/overrides/` (suas skills, rules e agentes),
  `.sdd/memory/` e `specs/`.

---

## 2. Preparar o app

### 2.1 Instalar o sdd

```sh
dart pub global activate --source git https://github.com/LucasTeixeiraDev/sddart_kit.git
export PATH="$PATH:$HOME/.pub-cache/bin"   # coloque no seu ~/.zshrc ou ~/.bashrc
sdd --version
```

O `sdd` precisa estar no `PATH`: os hooks gerados (format-on-edit e o guard do reviewer)
chamam o comando.

### 2.2 Criar o app com as dependências do stack

O stack `flutter-clean-cubit` assume Cubit, `Result` (Ok/Err), Dio e `bloc_test` + `mocktail`.

```sh
flutter create minha_loja && cd minha_loja
flutter pub add flutter_bloc dio meta
flutter pub add --dev bloc_test mocktail very_good_analysis
echo "include: package:very_good_analysis/analysis_options.yaml" > analysis_options.yaml
mkdir -p lib/features lib/core/result
```

Crie o tipo `Result` que o stack usa, em `lib/core/result/result.dart`:

```dart
/// Resultado funcional: [Ok] ou [Err].
sealed class Result<T, E> {
  const Result();
}

/// Sucesso.
final class Ok<T, E> extends Result<T, E> {
  /// Cria um sucesso.
  const Ok(this.value);

  /// Valor.
  final T value;
}

/// Falha.
final class Err<T, E> extends Result<T, E> {
  /// Cria uma falha.
  const Err(this.error);

  /// Erro.
  final E error;
}
```

Se o seu `Result` tiver outro nome ou caminho, ajuste `scaffold.vars.result_import` no
config (seção [4.3](#43-ajustar-o-config)).

### 2.3 Git

O `sdd check` usa o git para verificar os `owns` de cada tarefa, e o fluxo faz commit por onda.

```sh
git init && git add -A && git commit -m "app inicial"
```

---

## 3. Inicializar o sdd no app

### 3.1 `sdd init`

```sh
sdd init          # interativo: confirma o stack, as ferramentas e o format-on-edit
sdd init --yes    # aceita o que foi detectado
```

Saída:

```
WARN gate custom_lint desligado: dependência custom_lint ausente
WARN gate dart_code_linter desligado: dependência dart_code_linter ausente
stack flutter-clean-cubit · targets claude, cursor
criado    .sdd/config.yaml
criado    .sdd/kit.lock
criado    .sdd/memory/decisions.md
criado    .sdd/memory/learnings.md
criado    .sdd/overrides/README.md
sync: 55 escritos · 0 removidos · 0 conflitos
próximo passo: sdd new "<título>"
```

- **Os `WARN`** são informativos. Um gate de lint opcional só fica ligado se o pacote estiver
  no pubspec. Para ligá-lo depois, adicione o pacote e inclua o nome do gate em `dod.gates`
  no `.sdd/config.yaml` (o comando já está em `commands`). Evite `sdd init --force`: ele
  regrava o config.
- **O que foi criado:**
  - `.sdd/` (config e memória);
  - `.claude/` e `.cursor/` (agentes, skills, rules e os comandos `/sdd-*`);
  - `AGENTS.md` com a seção do sdd e `CLAUDE.md` com `@AGENTS.md`.
- **Commite tudo**, inclusive `.claude/` e `.cursor/`: quem clonar o repo já terá os comandos.

### 3.2 `sdd doctor`

```
OK   dart      Dart SDK version: 3.13.4 (stable) ...
OK   flutter   Flutter 3.47.5 • channel stable ...
OK   git       git version 2.54.0
OK   git repo  sim
OK   kit       /Users/voce/.pub-cache/git/sddart_kit-.../kit (package)
OK   stack     flutter-clean-cubit
OK   deps      dependências do stack ok
OK   config    válido
OK   kit.lock  sdd 0.1.0
OK   sdd       0.1.0
OK   sync      em dia
0 falhas · 0 avisos
```

Rode o `doctor` sempre que algo parecer estranho. `WARN` não bloqueia; `FAIL` precisa ser
resolvido (exit 1).

### 3.3 Abrir na ferramenta

- **Claude Code:** abra o projeto e **confie no workspace** quando perguntado. Sem isso, os
  hooks dos agentes não rodam. Os comandos aparecem ao digitar `/sdd-`.
- **Cursor:** abra o projeto. O Cursor lê os agentes de `.cursor/agents/` e as skills e
  comandos de `.claude/skills/`.

---

## 4. Trazer as suas skills e rules

Você já tem skills, rules ou agentes (de outro projeto, da empresa ou do seu `~/.claude`).
Há dois caminhos. Nos dois, o conteúdo vai para `.sdd/overrides/` e o `sdd sync` gera os
arquivos de cada ferramenta.

### 4.1 Caminho A: importar com `/sdd-import` (recomendado)

1. **Veja o inventário** (somente leitura; não precisa de `sdd init`):

   ```sh
   sdd import scan ../repo-da-empresa
   ```
   ```
   agent    claude   code-reviewer   .claude/agents/code-reviewer.md  (dup: .cursor/agents/code-reviewer.md same_name)
   command  claude   deploy          .claude/commands/deploy.md  (dup: .cursor/commands/deploy.md same_content)
   skill    claude   api-errors      .claude/skills/api-errors/SKILL.md  (dup: .cursor/rules/api-errors.mdc similar)
   rule     cursor   widgets         .cursor/rules/widgets.mdc
   skill    generic  logging         shared/skills/logging/SKILL.md
   ...
   2 agent · 2 skill · 4 rule · 2 command · 2 memory · 1 gerados pelo sdd ignorados
   ```

   O `dup:` aponta versões Claude e Cursor do mesmo conteúdo. A importação as mescla num só
   arquivo.

2. **No Claude Code ou no Cursor:** `/sdd-import ../repo-da-empresa`. O agente `sdd-importer`
   classifica cada item numa tabela:

   | Classe | Destino |
   |---|---|
   | **override** (padrão para o que é do projeto/empresa) | `.sdd/overrides/` |
   | **kit** (genérico de Flutter) | `.sdd/kit-proposals.md`, para você revisar |
   | **coberto** (o kit já tem) | nada |
   | **descartar** | nada |

3. **Aprove** item a item ou em bloco. Você pode mudar a classe de qualquer item.
4. O agente converte os aprovados para o formato canônico, grava em `.sdd/overrides/` e roda
   `sdd sync`.

A origem nunca é modificada.

### 4.2 Caminho B: escrever overrides à mão

A estrutura de `.sdd/overrides/` é a mesma do kit. Depois de qualquer mudança: `sdd sync`.

**Uma skill sua** — `.sdd/overrides/skills/api-errors/SKILL.md`:
```markdown
---
description: Códigos de erro da API interna e o Failure correspondente. Use ao mapear erros do backend.
---
- USR_404 → UserNotFoundFailure
- USR_423 → BlockedUserFailure
- Qualquer outro código → <Feature>UnexpectedFailure
```
Arquivos de apoio (tabelas, exemplos) podem ficar na mesma pasta. Ela é gerada como
`.claude/skills/sdd-api-errors/`.

**Uma rule por caminho** — `.sdd/overrides/rules/widgets.md`:
```markdown
---
description: Componentes do design system.
globs: ["lib/**/widgets/**", "lib/**/pages/**"]
---
Use AppButton e AppText; nunca ElevatedButton/Text com estilo solto.
```
Use `always: true` no lugar de `globs` para uma regra que vale sempre (com moderação: ela
entra em todo contexto).

**Ensinar um agente do kit a usar a sua skill**, sem copiar o agente —
`.sdd/overrides/agents/implementer.md`:
```markdown
---
extend: true
skills: [api-errors]
---
Use o cliente HTTP `ApiClient` do app, nunca `Dio` direto.
```

**Outras operações:**
- Substituir um item do kit inteiro: crie um arquivo com o mesmo nome, sem `extend`.
- Desligar um item: `disabled: true` no frontmatter.

**Um agente novo seu** — `.sdd/overrides/agents/a11y-checker.md`:
```markdown
---
description: Revisa acessibilidade das telas (semântica, contraste, tamanho de toque). Use em PRs de UI.
tier: standard
tools: [read, search]
readonly: true
---
Liste problemas de acessibilidade com arquivo:linha e a correção sugerida.
```
Tools disponíveis: `read`, `search`, `edit`, `write`, `bash`. Nunca coloque nome de modelo:
use `tier`.

Ao rodar `sdd sync`, se já existir um arquivo seu no caminho de um gerado (por exemplo,
`.claude/agents/sdd-x.md` criado à mão), o sync reporta `conflict` e não sobrescreve.

### 4.3 Ajustar o config

`.sdd/config.yaml` (o `init` preenche tudo). Os ajustes mais comuns:

```yaml
project:
  features_path: lib/features      # onde ficam as features
commands:
  test: flutter test {files}       # {files} recebe os arquivos da tarefa
dod:
  gates: [format, analyze, test, coverage, traceability]
  coverage:
    min: 80
    paths: ["lib/features/**/domain/**", "lib/features/**/presentation/**/cubit/**"]
  checklist:                       # o reviewer verifica e registra evidência
    - Nenhuma exception atravessa a fronteira do repository
models:                            # tier → modelo (Claude usa o alias; Cursor, o id)
  deep: {default: opus, cursor: claude-opus-5-5}
  standard: {default: sonnet, cursor: claude-sonnet-5}
  fast: {default: haiku, cursor: claude-sonnet-5}
hooks:
  format_on_edit: true             # dart format a cada edição de agente
scaffold:
  vars: {result_import: "package:{package}/core/result/result.dart"}
```

Depois de mudar o config: `sdd sync`. Se houver erro, a mensagem aponta o campo, por exemplo
`dod.coverage.min: deve estar entre 0 e 100, recebido 150`.

---

## 5. Sua primeira feature, passo a passo

Exemplo: "Login com biometria". Os comandos `/sdd-*` são digitados no chat do Claude Code ou
do Cursor; os comandos `sdd` vão no terminal.

### 5.1 Criar a spec e escrever o PRD

```sh
sdd new "Login com biometria"
```
```
criado specs/0001-login-com-biometria/ (prd.md, status.yaml)
próximo passo: preencha prd.md e rode /sdd-analyze 0001-login-com-biometria
```

Preencha `specs/0001-login-com-biometria/prd.md`. Quanto mais concreto, melhor a análise:

```markdown
# PRD · Login com biometria

## Problema
Usuários desistem do login por esquecer a senha.

## Objetivo
Permitir entrar com a digital/face já cadastrada no aparelho.

## Histórias
- Como cliente, quero entrar com a digital para não digitar a senha.

## Regras de negócio
- Só oferecer biometria se o aparelho suportar e o usuário já tiver logado uma vez com senha.
- Usuário bloqueado no backend (`USR_423`): "Conta bloqueada. Fale com o suporte."

## Fora de escopo
Cadastro de biometria, recuperação de senha.
```

### 5.2 Análise — `/sdd-analyze 0001`

**O que acontece**
1. O `sdd-explorer` mapeia o código existente: contratos e exemplares.
2. O `sdd-analyst` escreve o `analysis.md` com ambiguidades, perguntas numeradas e riscos.
3. O agente **para** e mostra as perguntas.

**O que você faz**
- Responda às perguntas no chat, ou direto no `analysis.md`, abaixo de cada `Resposta:`.
- Quando estiver satisfeito, diga que aprova. O agente registra:
  ```sh
  sdd status set 0001 gate analysis_approved
  ```

Exemplo de pergunta: *"Q4 · O saldo é buscado automaticamente ao abrir a tela? — impacto:
sem resposta, a tela pode abrir vazia ou fazer uma chamada indesejada."*

### 5.3 Spec e plano — `/sdd-spec 0001`

**O que acontece**
- O `sdd-architect` escreve:
  - `spec.md`: requisitos e critérios `AC-01`, `AC-02`... em Given/When/Then, mais o fora de
    escopo;
  - `plan.md`: contratos por camada, Failures, mapeamento Exception → Failure, testes por AC e
    decisões.
- Depois mostra o resumo e **para**.

**O que você faz**
- Revise principalmente os ACs e as decisões marcadas `[aprovação]`.
- Peça ajustes no chat; o architect refaz.
- Aprove: `sdd status set 0001 gate plan_approved`.

Exemplo de AC:
```
AC-07 · Carteira bloqueada
Given o backend responde 403 com {"code": "WLT_403"}
When a tela carrega o saldo
Then mostra "Carteira bloqueada. Fale com o suporte."
```

### 5.4 Tarefas — `/sdd-tasks 0001`

**O que acontece:** o `sdd-planner` cria `tasks/Txx-*.md`, valida e mostra o grafo.

```sh
sdd tasks validate 0001
```
```
ok · 7 tarefas · 4 ondas
```
```sh
sdd tasks graph 0001
```
```
onda 0
  T01 [pending] Contratos de domain da carteira (entidade, failures, repository, usecase)
onda 1
  T02 [pending] DTO e datasource remoto do saldo (GET /wallet/balance) ← T01
  T03 [pending] WalletCubit e estados ← T01
  T04 [pending] Formatação de centavos em reais (formatBrlCents)
onda 2
  T05 [pending] WalletRepositoryImpl (fronteira de erro) ← T01, T02
  T06 [pending] WalletPage ← T03, T04
onda 3
  T07 [pending] Integração da carteira no Dependencies ← T03, T05, T06
```

Uma tarefa por dentro:
```markdown
---
id: T05
title: WalletRepositoryImpl (fronteira de erro Exception → WalletFailure)
wave: 2
depends_on: [T01, T02]
tier: deep                 # deep | standard | fast, pelo risco
agent: implementer
owns:                      # só estes arquivos podem ser alterados
  - lib/features/wallet/data/repositories/wallet_repository_impl.dart
  - test/features/wallet/data/repositories/wallet_repository_impl_test.dart
reads:                     # contexto mínimo
  - lib/features/wallet/domain/repositories/wallet_repository.dart
exemplar: lib/features/profile/data/repositories/profile_repository_impl.dart
brick: repository-impl     # opcional: esqueleto
brick_vars: {feature: wallet}
acceptance: [AC-07, AC-08, AC-09]
---
## Objetivo
## Detalhes
## Pronto da tarefa
- [ ] `sdd check --task T05` verde
```

O que você faz: confira o grafo e se cada AC aparece em alguma tarefa. O `validate` avisa
quando um AC fica sem tarefa.

### 5.5 Implementação — `/sdd-exec 0001`

**O que acontece.** A sessão principal vira o orquestrador:
1. Cria a branch `sdd/0001-...` e marca a fase `exec`.
2. Pede as tarefas prontas: `sdd tasks next 0001 --json`.
3. Marca cada uma `in_progress` e dispara os implementers **em paralelo**, cada um no modelo
   do tier da tarefa.
4. Quando cada um volta, confirma com `sdd check --task Txx --json` e marca `done` ou
   `failed`.
5. Ao fim da onda, faz commit e segue para a próxima.

**O que você faz:** em geral, nada. Acompanhe pelo terminal:

```sh
sdd status 0001
```
```
0001-saldo-da-carteira · fase exec
gates: análise ✓ · plano ✓
onda 0: T01 done
onda 1: T02 done · T03 in_progress · T04 done x1
onda 2: T05 pending · T06 pending
onda 3: T07 pending
review: pending · blockers 0 · ciclos 0
```
(`x1` = uma falha registrada)

**Quando para e pede você:** uma tarefa ficou `blocked`. Isso acontece depois de 2 falhas no
tier dela e de uma tentativa escalada para `deep`. Veja a seção [8](#8-situações-comuns).

Ao terminar todas as ondas, roda o DoD completo:

```
PASS format
PASS analyze
PASS test      58 testes
PASS coverage  88.7% (mínimo 80%)
PASS traceability  16 ACs
0 falhas · 5 gates ok
```

### 5.6 Revisão — `/sdd-review 0001`

**O que acontece**
- O `sdd-reviewer` (somente leitura, exceto o `review.md`) compara o diff com spec, plano,
  decisões e checklist do DoD.
- Classifica cada achado:
  - **blocker:** viola AC, DoD ou arquitetura, ou quebra gate;
  - **major:** comportamento errado, falha de tratamento de erro ou teste que não verifica o
    AC;
  - **minor:** estilo ou legibilidade.
- Blocker ou major vira tarefa `Txx-fix-*` numa nova onda, e o fluxo volta ao `/sdd-exec`.
  Minor nunca gera correção.
- São no máximo 2 ciclos; depois disso, o fluxo para para você.

**O que você faz:** leia o `review.md`, especialmente se o ciclo 2 ainda tiver majors.

### 5.7 Fechamento — `/sdd-close 0001`

**O que acontece**
1. Confirma o DoD e a revisão aprovada.
2. Escreve o `specs/0001-.../pr.md`: resumo, ACs cobertos, decisões, minors e como testar.
3. Mostra as **lições candidatas** do review.

**O que você faz**
- Aprove as lições que valem a pena.
- Escolha o destino de cada uma:

  | Lição | Destino |
  |---|---|
  | verificável por máquina | regra de lint |
  | convenção geral | `.sdd/kit-proposals.md` |
  | específica do projeto | skill ou rule em `.sdd/overrides/` |
  | escolha com trade-off | `.sdd/memory/decisions.md` |
- Use o `pr.md` como descrição do PR da branch `sdd/0001-...`.

### 5.8 Atalho: `/sdd-run 0001`

Faz as fases em sequência, retomando de onde a spec está, e para nos mesmos pontos: os dois
gates, tarefas bloqueadas e o limite de revisões. Depois de cada parada, responda ou aprove e
rode `/sdd-run 0001` de novo.

---

## 6. Referência do CLI

Convenções:
- **Spec:** aceita `0001-login-com-biometria`, `0001` ou `1`.
- **`--json`:** saída estável para agentes e scripts.
- **Exit codes:** `0` ok; `1` falha de gate, validação ou transição recusada; `2` erro de uso
  ou config.
- **Flags globais:** `--json`, `--verbose`, `--kit-path <dir>`, `--version`.

### `sdd init [--stack <nome>] [--yes] [--force]`
- **Quando:** uma vez por app, ou com `--force` para regravar `config.yaml` e `kit.lock` (a
  memória é preservada).
- **O que faz:**
  - detecta pubspec, dependências e pastas;
  - escolhe o stack e cria `.sdd/`;
  - roda o `sync`.
- **Retorno:** avisos da detecção, lista de arquivos criados e resumo do sync (seção 3.1).
  Com `--json`: `{stack, targets, created, skipped, notes, sync_ok}`.

### `sdd sync [--check]`
- **Quando:** depois de mudar `config.yaml` ou `.sdd/overrides/`, ou de atualizar o sdd. Em CI,
  com `--check`.
- **O que faz:** gera `.claude/`, `.cursor/`, `.sdd/templates/`, a seção do `AGENTS.md` e o
  `CLAUDE.md`. Remove gerados órfãos e **nunca** toca em arquivos seus.
- **Retorno:**
  - normal: `sync: 15 escritos · 0 removidos · 0 conflitos` (com `--verbose`, lista os
    arquivos);
  - `--check`: `sync em dia` (exit 0), ou a lista `write|delete|conflict <arquivo>` mais
    `N mudanças pendentes` (exit 1);
  - conflito: exit 1.

### `sdd new "<título>"`
- **Quando:** para começar uma feature.
- **O que faz:** cria `specs/NNNN-slug/` com `prd.md` (do template) e `status.yaml`.
- **Retorno:** `criado specs/0001-login-com-biometria/ (prd.md, status.yaml)`.
  Com `--json`: `{spec, path}`.

### `sdd tasks validate <spec>`
- **Quando:** depois de criar ou editar tarefas. O planner e o `/sdd-tasks` já rodam.
- **O que faz:** verifica
  - schema das tarefas e ids únicos;
  - dependências em ondas anteriores e ciclos;
  - `owns` sem conflito na mesma onda;
  - `reads` e `exemplar` existentes;
  - agente e tier válidos;
  - saída do `brick` dentro de `owns`;
  - ACs existentes, e ACs sem tarefa (aviso).
- **Retorno:**
  ```
  ok · 7 tarefas · 4 ondas
  ```
  ou
  ```
  FAIL T03  specs/0001-x/tasks/T03-login-cubit.md  owns: lib/.../auth_repository_impl.dart também é de T02 (onda 1)
  WARN specs/0001-x/spec.md  AC-03 sem tarefa
  1 erros · 1 avisos
  ```

### `sdd tasks graph <spec> [--mermaid]`
- **Quando:** para ver o plano de execução.
- **Retorno:** ondas com o estado de cada tarefa (seção 5.4). `--mermaid` gera um
  `flowchart` para colar em PR ou wiki.

### `sdd tasks next <spec>`
- **Quando:** é o coração do `/sdd-exec`. Também serve para ver o que vem a seguir.
- **O que faz:** devolve as tarefas prontas da **menor onda** não concluída, com o agente já
  resolvido pelo tier. Retentativas usam o mesmo tier; depois de `max_fix_attempts` falhas,
  uma tentativa escalada.
- **Retorno:**
  ```
  onda 0 · 1 prontas
    T01  sdd-implementer-deep  specs/0001-saldo-da-carteira/tasks/T01-contratos-domain-wallet.md
  ```
  Com `--json`:
  ```json
  {"spec": "0001-saldo-da-carteira", "complete": false, "wave": 0,
   "ready": [{"id": "T01", "title": "...", "file": "specs/.../T01-....md",
              "tier": "deep", "agent": "sdd-implementer-deep", "attempt": 1, "escalated": false}],
   "in_progress": [], "blocked": [], "remaining": 7}
  ```

### `sdd status [<spec>]`
- **Quando:** a qualquer momento.
- **Retorno:**
  - sem argumento: uma linha por spec aberta, por exemplo
    `0001-login-com-biometria  analyze  sem tarefas  (análise · plano ·)`;
  - com uma spec: o detalhe por onda (seção 5.5);
  - avisa quando o `learnings.md` passa do limite.
  - Com `--json`: `{specs: [...], learnings: {pending, limit}}`.

### `sdd status set <spec> <alvo> <valor>`
- **Quando:** é a **única** forma de mudar o `status.yaml`. Os agentes usam no fluxo; você
  usa para aprovar gates ou destravar tarefas.
- **Alvos:**

  | Exemplo | Efeito |
  |---|---|
  | `T03 in_progress` | inicia (exige fase `exec` e dependências `done`; registra o tier usado) |
  | `T03 done` | conclui |
  | `T03 failed` | conta uma tentativa; esgotadas → `blocked` automaticamente |
  | `T03 blocked` / `T03 pending` | bloqueia / reseta (zera as tentativas) |
  | `gate analysis_approved` / `gate plan_approved [false]` | aprova (ou revoga) os gates, nessa ordem |
  | `phase exec` | muda a fase (exige os gates; `done` exige tarefas concluídas e revisão aprovada) |
  | `review in_progress` / `review changes_requested blockers=1` / `review approved blockers=0` | estado da revisão; `in_progress` conta um ciclo |
- **Retorno:** `T01: pending → in_progress (tier deep)`. Quando recusado, mostra o motivo:
  ```
  ERRO T02 depende de tarefas não concluídas: T01          (exit 1)
  ERRO estado "zzz" inválido + uso                         (exit 2)
  ```
- O arquivo é gravado sob lock, então chamadas simultâneas não perdem atualização.

### `sdd check --task <id> [--spec <id>]`
- **Quando:** ao final de cada tarefa. O implementer e o orquestrador rodam.
- **O que faz:**
  - format, analyze e test **só nos arquivos de `owns`**;
  - via git, verifica que nada fora de `owns` mudou (tolera arquivos de outras tarefas da
    onda, `specs/` e `generated_globs`).
- **Retorno:**
  ```
  FAIL format    lib/features/wallet/domain/failures/wallet_failure.dart  não formatado
  FAIL analyze   lib/features/wallet/domain/failures/wallet_failure.dart:17  return_of_invalid_type: ...
  FAIL owns      lib/fora.dart  alterado fora de owns
  SKIP test      nenhum *_test.dart em owns
  4 falhas · 0 gates ok
  ```
  - `INTF`: a falha parece vir de outra tarefa em andamento. Não conta tentativa; é rechecada
    ao fim da onda.
  - Com `--json`: `{ok, mode, spec, task, failures, interference, gates: [{gate, status, note?, failures: [{location, message, interference_with?}], truncated?}]}`.

### `sdd check [--spec <id>] [--max-lines N]`
- **Quando:** ao fim da implementação, antes da revisão e em CI.
- **O que faz:** roda os gates de `dod.gates` na ordem:
  - format, analyze e lints extras;
  - testes (com cobertura via `test_all`);
  - cobertura do lcov filtrada por `dod.coverage.paths`;
  - rastreabilidade: cada AC da spec aparece num teste `[AC-xx]`.
- **Retorno:** o mesmo formato (seção 5.5). Sem `--spec`, usa a única spec em `exec` ou
  `review`; se não houver, pula a rastreabilidade.

### `sdd scaffold <brick> [--vars k=v ...]` · `sdd scaffold --task <id>`
- **Quando:** para poupar boilerplate. Bricks são **só esqueleto**; assinaturas vêm do
  exemplar.
- **Bricks do stack:**

  | Brick | Gera |
  |---|---|
  | `feature` | pastas das 3 camadas |
  | `failure` | sealed `<Feature>Failure` + `UnexpectedFailure` |
  | `repository-contract` | interface vazia (domain) |
  | `repository-impl` | classe vazia (data) |
  | `repository-test` | harness de teste |
  | `cubit-test` | harness de teste (`name` obrigatório) |
- **O que faz:** gera os arquivos (nunca sobrescreve), ordena imports e formata.
  `package`, `features_path` e `test_path` vêm sozinhos.
- **Retorno:**
  ```
  created    lib/features/wallet/domain/failures/wallet_failure.dart
  failure: 1 criados · 0 mantidos
  ```
  Com `--task`, avisa arquivos fora dos `owns` da tarefa.

### `sdd import scan <caminho>`
- **Quando:** antes do `/sdd-import`, ou só para ver o que um repo tem.
- **O que faz:** inventário somente leitura de agentes, skills, rules, comandos e memória,
  com duplicatas (`same_name`, `same_content`, `similar`).
- **Retorno:** tabela e resumo (seção 4.1). Com `--json`:
  `{source, summary, items: [{path, tool, kind, name, description, bytes, lines, hash, support_files?, duplicates?}], skipped_generated}`.

### `sdd doctor`
- **Quando:** depois de instalar, ao clonar o repo e quando algo falhar sem motivo aparente.
- **O que faz:** verifica dart, flutter, git, kit, stack, dependências esperadas, config,
  `kit.lock`, `sdd` no PATH e sync em dia.
- **Retorno:** uma linha `OK|WARN|FAIL` por item (seção 3.2); exit 1 se houver `FAIL`.

### `sdd hook ...`
Uso interno dos arquivos gerados: `format` (format-on-edit), `guard-bash` e `guard-write`
(limites do reviewer). Você não chama.

---

## 7. Referência dos comandos `/sdd-*`

| Comando | Quando | O que acontece | O que você faz | Resultado |
|---|---|---|---|---|
| `/sdd-analyze <spec>` | PRD escrito | explorer → analyst | responde às perguntas e aprova | `analysis.md`, gate `analysis_approved` |
| `/sdd-spec <spec>` | análise aprovada | architect | revisa ACs e decisões, aprova | `spec.md`, `plan.md`, gate `plan_approved` |
| `/sdd-tasks <spec>` | plano aprovado | planner + validate | confere o grafo | `tasks/*.md` válidas |
| `/sdd-exec <spec>` | tarefas válidas | ondas em paralelo, check, commit por onda | nada, salvo tarefas `blocked` | código + DoD verde na branch `sdd/<spec>` |
| `/sdd-review <spec>` | DoD verde | reviewer; correções em nova onda | lê o `review.md` | revisão aprovada |
| `/sdd-close <spec>` | revisão aprovada | `pr.md` e lições | aprova lições e escolhe destinos | spec `done`, memória atualizada |
| `/sdd-run <spec>` | a qualquer momento | todas as fases a partir da atual | o mesmo de cada fase | idem |
| `/sdd-import <caminho>` | quando quiser trazer conteúdo | scan → classificação → aprovação → conversão | aprova a tabela | `.sdd/overrides/`, `kit-proposals.md` |

Os comandos só podem ser disparados por você (não são invocados automaticamente pelo modelo).
O argumento é o id da spec (`0001`) ou um caminho.

---

## 8. Situações comuns

**Uma tarefa ficou `blocked`.** Veja o motivo:
```sh
sdd check --task T03 --spec 0001
```
Corrija à mão, ou ajuste a tarefa (detalhes, exemplar, tier). Depois, recomece:
```sh
sdd status set 0001 T03 pending      # zera tentativas
```
e rode `/sdd-exec 0001` de novo. Se você mesmo terminou o código:
`sdd status set 0001 T03 done`.

**`INTF` no check.** É uma falha causada por arquivo de outra tarefa da mesma onda ainda em
andamento. Não conta tentativa: o orquestrador recheca ao fim da onda.

**`owns: ... alterado fora de owns`.** A tarefa mexeu em arquivo que não é dela. Reverta a
mudança ou, se fizer sentido, ajuste o `owns` da tarefa e rode `sdd tasks validate`.

**`sync` com `conflict`.** Existe um arquivo seu no caminho de um gerado. Renomeie-o (e, se
for um agente ou skill seu, mova para `.sdd/overrides/`) e rode `sdd sync`.

**Limite de ciclos de revisão.** O `review in_progress` é recusado depois de
`execution.max_review_cycles` (padrão 2). Decida: corrija manualmente, aumente o limite no
config ou aprove com os achados documentados.

**`WARN models ... usando inherit`** (Cursor). Algum tier não tem id do Cursor. Adicione
`cursor: <id>` em `models.<tier>` e rode `sdd sync`.

**Hooks não rodam.**
- `sdd doctor` deve mostrar `OK sdd`; se não, instale o sdd no PATH (seção 2.1).
- No Claude Code, aceite a confiança do workspace.

**Quero usar outro padrão de erro ou outro `Result`.** Ajuste `scaffold.vars.result_import`.
Se o contrato for diferente, sobrescreva os bricks em `.sdd/overrides/bricks/` e escreva uma
skill sua que substitua `result-failure`.

**Atualizei o sdd.** `sdd doctor` avisa `rode sdd sync`. Rode e commite os arquivos gerados.

---

## 9. CI

```yaml
- run: dart pub global activate --source git https://github.com/LucasTeixeiraDev/sddart_kit.git
- run: sdd sync --check            # gerados em dia com o kit e o config
- run: sdd check --spec 0001       # DoD da spec do PR (ou sem --spec na spec ativa)
```

---

## 10. Glossário

| Termo | Significado |
|---|---|
| **AC** | critério de aceite (`AC-01`), em Given/When/Then; todo AC precisa de um teste `[AC-01] ...` |
| **DoD** | definição de pronto: os gates de `dod.gates` mais o checklist revisado |
| **Gate humano** | aprovação sua (`analysis_approved`, `plan_approved`) sem a qual o fluxo não avança |
| **Onda** | grupo de tarefas que roda em paralelo; ondas são sequenciais, com commit ao fim de cada uma |
| **`owns`** | arquivos que uma tarefa pode alterar |
| **Exemplar** | arquivo existente que a tarefa deve imitar; vale mais que um brick |
| **Tier** | `deep`, `standard` ou `fast`; o config mapeia para o modelo de cada ferramenta |
| **Override** | seu conteúdo em `.sdd/overrides/`, que substitui ou estende o kit |
| **Interferência (`INTF`)** | falha atribuída a outra tarefa da mesma onda em andamento |
