# Dogfooding (M7) · 2026-10-03

## O que foi feito

**App de referência:** `loja_app`, salvo como fixture `test/fixtures/dogfood_app`. É um app
Flutter com very_good_analysis, `flutter_bloc`, `dio`, `bloc_test` e `mocktail`, com o tipo
`Result` e DI manual. A feature `profile` serve de exemplar, com camadas, DTO, exception de
negócio mapeada, página e 9 testes.

**Feature:** "Saldo da carteira" (`GET /wallet/balance`). Ela tem formatação BRL, erro de
negócio `WLT_403`, sem conexão, moeda não suportada e um botão de atualizar.

**Execução:** o fluxo `/sdd-run` completo rodou com subagentes reais. Cada agente usou como
prompt o próprio arquivo gerado (`.claude/agents/sdd-*.md`) mais as skills do frontmatter,
com o modelo do seu tier:

| Tier | Modelo |
|---|---|
| deep | opus |
| standard | sonnet |
| fast | haiku |

**Papéis:** a sessão principal foi o orquestrador. Nos gates humanos, **a sessão principal fez
o papel do humano**: respondeu às 10 perguntas da análise, aprovou as 4 decisões do plano e
aprovou as 5 lições.

| Fase | Agentes | Resultado |
|---|---|---|
| analyze | explorer (haiku), analyst (opus) | 10 perguntas pertinentes, 4 riscos |
| spec | architect (opus) | 16 ACs Given/When/Then, plano com 4 decisões para aprovação |
| tasks | planner (opus) | 7 tarefas em 4 ondas, `validate` ok sem avisos |
| exec | 7 implementers (3 deep, 3 standard, 1 fast), até 3 em paralelo | todas `done`; DoD verde de primeira (58 testes, cobertura 88,7%, 16 ACs) |
| review | reviewer (opus) × 2 ciclos | ciclo 1: 1 major → tarefa `T08-fix`; ciclo 2: aprovado (5 minors) |
| close | orquestrador | `pr.md`, 5 lições promovidas (3 kit, 1 projeto, 1 lint), fase `done` |

O histórico ficou limpo na branch `sdd/0001-saldo-da-carteira`, com 13 commits: um por fase
e um por onda. O consumo foi de cerca de 690 mil tokens de subagentes. O contexto do
orquestrador ficou pequeno: só os retornos de 4 linhas e o JSON do CLI.

## O que funcionou bem

- **Os contratos do CLI sustentaram o orquestrador.** O loop
  `tasks next → status set → agente → check --task → status set` rodou sem ambiguidade.
- **"Confie no `sdd check`, não no autorrelato" se provou necessário.** A T04 se declarou
  `blocked`, mas a rechecagem do orquestrador estava verde.
- **O gate de `owns` pegou um arquivo real fora do escopo.** Era o nome duplicado que o brick
  gerou (F13).
- **Rastreabilidade e cobertura funcionaram sem configuração extra.** As tags `[AC-xx]` dos
  agentes casaram com o `test_tag_pattern`.
- **O ciclo de revisão funcionou.** Achado major → tarefa de correção numa nova onda →
  reexecução → aprovação no ciclo 2, dentro do limite de ciclos imposto pelo CLI.

## Atritos e ações

Legenda: ✅ corrigido. As 4 propostas iniciais foram decididas depois do M7 (D-042 a D-045).

| # | Fase | Atrito | Ação |
|---|---|---|---|
| F1 | analyze | O ambiente de subagentes bloqueou a gravação do `analysis.md`. Foi intermitente: o architect gravou. | ✅ Os comandos instruem o orquestrador a gravar o conteúdo devolvido. Os agentes retornam `falhou · motivo`. |
| F2 | spec | O retorno do explorer não era persistido, e o architect não sabia onde achá-lo. | ✅ Seção `## Mapa do código` no template de análise, preenchida pelo analyst. |
| F3 | spec | Não havia orientação sobre helpers puros de apresentação, como formatadores. | ✅ Skill `clean-arch-layers`: `presentation/formatters/`. |
| F4 | spec | DTO com `as` gera `TypeError` (um `Error`, não capturado), o que contradiz o fluxo de erro. | ✅ Skill `dio-datasource`: `fromJson` valida e lança `FormatException`. |
| F5 | todas | Caminhos relativos sem dizer a raiz; formato de retorno sem caso de falha. | ✅ AGENTS.md: "relativos à raiz"; agentes com retorno de falha. |
| F6 | spec | O template do plano não tinha seções de rastreabilidade nem de decisões para aprovação. | ✅ `## Testes (rastreabilidade)` e marcação `[aprovação]`. |
| F7 | tasks | `brick` é um só por tarefa, e o `repository` gera contrato e implementação, que ficam em ondas diferentes. | ✅ `repository-contract` + `repository-impl`; cada brick gera uma camada; `tasks validate` confere a saída do brick contra `owns` (D-042). |
| F8 | tasks | O template de tarefa não mostrava `exemplar` nem `brick`. | ✅ Campos opcionais comentados no template. |
| F9/F10 | exec | Os bricks geram assinaturas genéricas (`Result<void>`, `fetch()`), e os agentes reescreveram quase tudo. | ✅ Bricks reduzidos a esqueleto, sem assinaturas; exemplar primeiro (D-043). |
| F11 | exec | very_good_analysis exige `@immutable` (`package:meta`) para igualdade por valor. | ✅ Orientação na skill e `meta` nas dependências esperadas, com aviso no `init`/`doctor` (D-044). |
| F12 | exec | **Bug do kit:** a skill documentava `--vars a=1 b=2`, mas o CLI exigia `--vars` repetido. | ✅ Doc corrigida, e o CLI aceita pares `k=v` soltos após o brick. |
| F13 | exec | Um arquivo sem dono na onda reprovava qualquer tarefa que rodasse `check` enquanto as outras ainda estavam em andamento. | ✅ Vira `INTF` enquanto houver tarefa da onda rodando e falha na rechecagem do fim da onda (D-038). Nota do gate: "N da tarefa · M no total". |
| F14 | exec | Lints do very_good_analysis (`use_raw_strings` com `R$`, `cascade_invocations`) custaram ciclos. | ✅ Dicas na skill `bloc-testing`. |
| F15 | review | **Bug de desenho:** o reviewer é `readonly`, sem `Write`, mas precisa gravar o `review.md`. No Claude Code real, não conseguiria. | ✅ Campo `write_allow`: no Claude, `Write` + hook `sdd hook guard-write`; no Cursor, segue readonly e devolve o conteúdo (D-039). |
| F16 | review | Ciclo N>1 sem orientação: delta desde o ciclo anterior, itens resolvidos, quem atualiza o status. | ✅ O comando passa o commit do ciclo anterior; o template tem `ciclo` e `Resolvidos`; o reviewer não toca no status. |
| F17 | review | O orquestrador (eu) escolheu para a `T08-fix` um exemplar que usava o padrão a corrigir. | ✅ A skill `task-breakdown` tem uma seção sobre tarefas de correção. |
| F18 | close | **Bug do CLI:** templates em `.sdd/templates/` viravam conflito no `sync` quando o kit mudava. Uma correção do M3 nunca tinha sido aplicada. | ✅ `supportsMarker` exclui `.sdd/`, com teste de regressão (D-040). |
| F19 | exec | O implementer se declarou `blocked` por um `owns` que não era seu. | ✅ Implementer: falha de `owns` em arquivos não tocados → `done` com nota. |
| F20 | review | A severidade "desvio do plano = major" pegou um desvio só de teste. | ✅ Régua de severidade com exemplos no reviewer; minor não gera correção (D-045). |

## Limites deste dogfooding

- **Fidelidade:** os agentes rodaram como subagentes genéricos lendo os arquivos gerados. As
  restrições de `tools` e os hooks não foram impostos pela ferramenta: o F15 só apareceu
  porque o próprio agente notou.
- **Humano simulado:** os gates e as respostas foram dados pela sessão principal. Num uso real,
  as perguntas da análise e as decisões do plano são suas.
- **Fora do teste:** o Cursor não foi exercitado (só os arquivos gerados foram conferidos), e
  nem o hook de format-on-edit.

## Teste de integração

`test/cli/dogfood_flow_test.dart` repete o contrato do orquestrador sobre `dogfood_app`, com
os artefatos reais do fluxo (`test/fixtures/dogfood_run/`):
- `init`, `new` e os gates humanos, com as guardas de fase;
- `tasks validate` (8 tarefas, 5 ondas);
- `tasks next` onda a onda, com os agentes resolvidos por tier;
- `check --task`, a revisão em 2 ciclos e o `done`;
- grafo e `sync --check` no fim.
