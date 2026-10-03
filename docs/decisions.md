# Decisões do desenvolvimento do `flutter_sdd`

Formato: `## D-NNN · título (AAAA-MM)` com Decisão, Motivo e Origem.
Origem "M0-Pn" = resposta à pergunta n do plano do M0.

## D-001 · Resolução do kit em runtime (2026-09)
**Decisão:** ordem `--kit-path` > `SDD_KIT_PATH` > raiz do pacote via
`Isolate.resolvePackageUri(package:flutter_sdd/)` + `kit/`. Executável AOT exige
flag ou env. Kit embutido no binário fica para depois do M7.
**Motivo:** cobre `dart run`, `pub global activate --source git|path` sem gerar código.
**Origem:** M0-P1.

## D-002 · Dependências (2026-09)
**Decisão:** `args`, `yaml`, `path`, `file` (FS injetável/MemoryFileSystem), `collection`,
`mason_logger` (prompts do `init`), `pub_semver` (compatibilidade do `kit.lock`), `meta`.
`yaml_edit`, `glob` e `mason` entram quando usados (M2/M3/M5).
Emissor YAML próprio (`yaml_writer.dart`) para gerar `config.yaml` e `kit.lock`.
**Motivo:** saída determinística e legível (idempotência); `yaml_edit` não controla estilo
ao criar documentos do zero.
**Origem:** M1.

## D-003 · Comandos `/sdd-*` gerados como skills manuais (2026-09)
**Decisão:** comandos canônicos viram skills em `.claude/skills/sdd-*/SKILL.md` com
`disable-model-invocation: true`. Não gerar `.claude/commands/` nem `.cursor/commands/`.
**Motivo:** verificado em 2026-09-23 que as duas ferramentas suportam o campo
(Claude: "Only you can invoke the skill"; Cursor: "only included in context when you
explicitly type `/skill-name`"), e o Cursor lê `.claude/skills/`. Commands são legado nas duas.
**Origem:** M0-P2.

## D-004 · Modelos por ferramenta (2026-09)
**Decisão:** sem override `cursor:`, o adapter do Cursor usa `inherit` com aviso no `sync`
e no `doctor` (nunca erro). Defaults do stack `flutter-clean-cubit`:
deep `{default: opus, cursor: claude-opus-5-5}`, standard `{default: sonnet, cursor: claude-sonnet-5}`,
fast `{default: haiku, cursor: claude-sonnet-5}`.
**Motivo:** o Cursor não documenta aliases. Haiku não está disponível de forma confiável
para subagentes no Cursor (staff no fórum, 2026-09), então fast usa sonnet no Cursor.
**Pendência:** confirmar as strings exatas na UI do Cursor; só vieram de resumo das docs.
**Origem:** M0-P3.

## D-005 · Agentes gerados em `.claude/agents/` e `.cursor/agents/` (2026-09)
**Decisão:** gerar nos dois lugares; no Cursor com `model` e `readonly` próprios
(o reviewer é `readonly: true` lá).
**Motivo:** `.cursor/agents/` tem precedência no Cursor para nomes iguais, então não há
listagem duplicada, e o `model` difere entre as ferramentas.
**Origem:** M0-P4.

## D-006 · Gates de lint (2026-09)
**Decisão:** `analyze` padrão = `dart analyze --format=machine --fatal-infos {files}`.
`custom_lint` e `dart_code_linter` são gates opcionais do core, ligados no stack
`flutter-clean-cubit`. O `init` desliga um gate se a dependência exigida
(`gate_requirements` no `stack.yaml`) não estiver no pubspec.
**Motivo:** saída parseável; `analyze` não roda custom_lint nem dart_code_linter.
**Pendência (M4):** validar o comando do dart_code_linter (`dart run dart_code_linter:metrics analyze lib`).
**Origem:** M0-P5.

## D-007 · Execução paralela e verificação de `owns` (2026-09)
**Decisão:** o orquestrador trabalha sempre em uma branch `sdd/<spec>` (nunca na main) e
faz commit ao fim de cada onda. A checagem de `owns` de uma tarefa tolera arquivos
possuídos por outras tarefas `in_progress` da mesma onda. Falha de analyze/test causada por
arquivo de outra tarefa em andamento é reportada como **interferência**, não consome
tentativa, e a tarefa é rechecada ao fim da onda.
**Origem:** M0-P6.

## D-008 · Restrição de Bash do reviewer (2026-09)
**Decisão:** nunca `permissions.deny` de sessão. O agente `sdd-reviewer` do Claude recebe
`hooks.PreToolUse` (matcher `Bash`) no próprio frontmatter, bloqueando tudo fora de
`sdd check`, `git diff` e `git log`. Plano: o próprio CLI provê o guard
(ex.: `sdd hook guard-bash`), para não depender de `jq`/scripts shell. No Cursor, só
`readonly: true` + prompt.
**Motivo:** verificado que subagentes aceitam hooks no frontmatter e que eles só valem
enquanto o subagente roda. Ressalva: hooks de agentes do projeto só rodam depois que o
workspace é marcado como confiável (não em `claude -p`), por isso a regra também fica no prompt.
**Origem:** M0-P7.

## D-009 · Idioma (2026-09)
**Decisão:** kit só em pt-BR; `language` é validado, e um valor diferente de `pt-BR` gera
aviso e é ignorado.
**Origem:** M0-P8.

## D-010 · Repositório e distribuição (2026-09)
**Decisão:** a raiz do repo é o pacote `flutter_sdd`. URL de instalação: o remote atual
`https://github.com/LucasTeixeiraDev/sddart_kit.git`.
**Pendência:** licença ainda não definida; nenhum `LICENSE` foi criado.
**Origem:** M0-P9.

## D-011 · Dogfooding, mason e ordem init/sync (2026-09)
**Decisão:** o M7 usa uma fixture criada aqui, que também vira teste de integração.
O `mason` fica para o `scaffold`. O `init` só chama o `sync` a partir do M2.
**Origem:** M0-P10, P11, P12.

## D-012 · Hooks de format-on-edit (2026-09)
**Decisão:** com Claude entre os targets, o hook vai só em `.claude/settings.json`;
`.cursor/hooks.json` só é gerado quando Claude não é target. Regra em `docs/adapters.md`.
**Motivo:** o Cursor executa hooks de `.claude/settings.json`; gerar nos dois roda em dobro.
**Origem:** M0-P13.

## D-013 · Config em camadas e validação (2026-09)
**Decisão:** o config efetivo é defaults do core → `config_defaults` do stack → `config.yaml`.
Mapas são combinados; listas e escalares substituem. Chaves desconhecidas e `language` ≠ pt-BR
geram aviso; demais problemas são erros agregados no formato `caminho: mensagem`.
O `init` grava o config completo (para ficar legível) e nunca sobrescreve `memory/` nem
`overrides/`; `--force` regrava só `config.yaml` e `kit.lock`.
**Origem:** M1.

## D-014 · `kit.lock` (2026-09)
**Decisão:** registra `sdd_version`, `stack` e `kit_hash` (FNV-1a 64 de `core/` + stack).
Não registra caminho nem data, para ser portátil e idempotente. Lock mais novo que o CLI =
falha; CLI mais novo ou kit alterado = aviso "rode sdd sync".
**Origem:** M1.

## D-015 · Branch de desenvolvimento (2026-09)
**Decisão:** commits dos milestones na branch `feat/flutter-sdd`, e não direto na main.
**Origem:** M1.

## D-016 · Conteúdo do kit com variáveis `{{sdd:chave}}` (2026-09)
**Decisão:** corpos do kit podem usar `{{sdd:chave}}` (config e listas calculadas, ex.:
`gates_list`, `commands_list`, `dod_checklist`). Variável desconhecida = erro no sync.
**Motivo:** o kit fica genérico e o texto gerado reflete o config do projeto. O prefixo `sdd:`
evita conflito com o `{{ }}` dos bricks mason.
**Origem:** M2.

## D-017 · Hooks implementados pelo próprio CLI (2026-09)
**Decisão:** `sdd hook format` (format-on-edit) e `sdd hook guard-bash --allow ...` (reviewer)
leem o payload JSON do stdin; os arquivos gerados só chamam `sdd`.
O guard bloqueia encadeamento/redirecionamento (`; & | > < $(` e crase).
**Motivo:** sem dependência de `jq` ou scripts shell, testável e igual nas duas ferramentas.
**Origem:** M2 (realiza D-008 e D-012).

## D-018 · Identificação de arquivos gerados (2026-09)
**Decisão:** aviso no arquivo (markdown) + manifesto `.sdd/generated.json`. Um arquivo só é
sobrescrito ou removido se tiver o aviso (ou, sem suporte a comentário, estiver no manifesto).
Arquivo do usuário no caminho de um gerado vira **conflito** (não escrito; exit 1).
Órfãos são procurados no manifesto e em `.claude|.cursor/{agents,skills,rules}`.
**Origem:** M2.

## D-019 · Resolução de camadas do kit (2026-09)
**Decisão:** core → stack → `.sdd/overrides/`. Item de mesmo nome substitui por inteiro (skill
inclui arquivos de apoio); `disabled: true` remove. Templates por caminho relativo.
Canônico sem prefixo; o prefixo `sdd-` é aplicado na geração.
**Pendência (M5):** stacks precisam acrescentar skills a agentes do core (ex.: implementer
com `result-failure`) sem copiar o agente inteiro.
**Origem:** M2.

## D-020 · Texto dos comandos independente de ferramenta (2026-09)
**Decisão:** comandos não usam `$ARGUMENTS`; o corpo diz "o argumento após o comando é...".
**Pendência:** confirmar que o Claude Code anexa os argumentos quando o corpo não usa
`$ARGUMENTS`; se não anexar, o adapter do Claude injeta a linha.
**Origem:** M2.

## D-021 · Escrita do `status.yaml` (2026-10)
**Decisão:** `sdd status set` relê o arquivo sob lock do SO (`RandomAccessFile.lock`, arquivo
de lock em `<tmp>/sdd-locks/`, fora do repo) e grava com arquivo temporário + rename.
Gramática fechada: `<Txx> <estado>`, `gate <nome> [true|false]`, `phase <fase>`,
`review <estado> [blockers=N]`. Erro de gramática = exit 2; transição inválida = exit 1.
**Motivo:** implementers paralelos disparam `status set` ao mesmo tempo; `package:file`
ignora `exclusive` na criação de arquivos, então não serve como lock.
**Origem:** M3.

## D-022 · Guardas de transição (2026-10)
**Decisão:** o CLI aplica as regras do fluxo, não o orquestrador:
- `Txx in_progress` exige fase `exec` e dependências `done`, e registra `tier_used`;
- `Txx failed` incrementa `attempts` e vira `blocked` sozinho quando as tentativas acabam;
- `Txx pending` (reset humano) zera `attempts`;
- `gate plan_approved` exige `analysis_approved`; revogar um gate revoga os seguintes;
- fases `spec|plan` exigem `analysis_approved`; `tasks|exec|review` exigem `plan_approved`;
  `done` exige todas as tarefas `done` e `review approved` (sem blockers);
- `review in_progress` conta um ciclo; acima de `execution.max_review_cycles` (padrão 2), recusa.
**Motivo:** estado determinístico e à prova de erro do LLM.
**Origem:** M3.

## D-023 · Política de tentativas e ondas no `tasks next` (2026-10)
**Decisão:** até `max_fix_attempts` falhas no tier da tarefa; depois **uma** execução no
`escalate_to` (só se for um tier acima); depois esgotada (`blocked`). O `next` devolve apenas a
menor onda com tarefas não concluídas (ondas sequenciais, commit por onda, D-007), com o
agente resolvido (`sdd-implementer-<tier>`). Tier sem variante no agente = erro no `validate`;
escalonamento sem variante = aviso.
**Origem:** M3.

## D-024 · Templates de fase exportados para `.sdd/templates/` (2026-10)
**Decisão:** o `sync` gera `.sdd/templates/{analysis,spec,plan,task,review}.md`, sem renderizar
e sem aviso de gerado (identificados pelo manifesto). Os agentes leem dali.
**Motivo:** o kit fica no pub-cache, fora do alcance dos agentes; o aviso seria copiado para as
specs junto com o template.
**Origem:** M3.

## D-025 · Validação de tarefas (2026-10)
**Decisão:** além da tabela do brief, também é erro:
- o nome do arquivo não começar com o id (`T03-*.md`);
- faltar uma das seções `## Objetivo`, `## Detalhes` ou `## Pronto da tarefa`;
- um caminho em `owns`, `reads` ou `exemplar` ser absoluto ou conter `..`;
- o agente não existir no kit.

`reads` aceita arquivos que são `owns` de dependências transitivas. `Pronto da tarefa` sem
`sdd check --task` gera aviso. A spec pode ser referida por id completo, `0001` ou `1`.
**Origem:** M3.

## D-026 · Execução dos gates (2026-10)
**Decisão:** os comandos do config são tokenizados (com suporte a aspas) e executados sem shell.
`{files}` recebe os arquivos no modo tarefa e é removido no modo completo, exceto no `format`,
que recebe `.` (sem caminhos o `dart format` lê do stdin). O gate `test` recebe
`--reporter json` automaticamente. No modo completo, `test` usa `commands.test_all` quando
`coverage` está nos gates. O padrão do `format` passa a ser
`dart format --output=none --set-exit-if-changed {files}`.
**Motivo:** verificado com ferramentas reais (Dart 3.13 / Flutter 3.47): a versão sem
`--output=none` reescreve arquivos, e um gate não deve alterar o workspace (CI).
O format-on-edit (D-012) cuida da formatação durante a edição.
**Origem:** M4.

## D-027 · Gate de `owns` e interferência (2026-10)
**Decisão:** alterados = `git diff --name-only --relative HEAD` + `git ls-files --others
--exclude-standard`. Ficam tolerados:
- os `owns` da própria tarefa;
- os `owns` de tarefas da mesma onda já iniciadas;
- `specs/<spec>/**` (estado e artefatos do orquestrador);
- `generated_globs`.

Uma falha de analyze/test é interferência (`INTF`) quando o local ou a mensagem cita um
arquivo, com ou sem `lib/`, de outra tarefa `in_progress`. `"interference": true` no JSON
quando **todas** as falhas são interferência: o orquestrador não consome tentativa e
rechecha ao fim da onda.
**Limite conhecido:** é heurística; uma interferência que não cita o arquivo de origem vira
falha comum.
**Origem:** M4 (realiza D-007).

## D-028 · Parsers verificados com saídas reais (2026-10)
**Decisão:** os parsers são testados contra saídas reais capturadas em
`test/fixtures/outputs/`:
- analyze: `--format=machine`, com fallback para a saída humana do `flutter analyze`;
- format: linhas `Changed`;
- testes: eventos `--reporter json`.

Falhas de carga (erro de compilação) chegam como um teste **não oculto** chamado
`loading <arquivo>`, com a mensagem útil na segunda linha. Gates sem parser dedicado
(custom_lint, dart_code_linter) extraem linhas com caminho `lib|test/...dart` ou as
primeiras linhas da saída. A rastreabilidade é estática: busca `test_tag_pattern` em
`<test_path>/**/*_test.dart`.
**Origem:** M4.

## D-029 · Extensão de agentes por camada (2026-10)
**Decisão:** um arquivo de agente com `extend: true` numa camada posterior acrescenta `skills`
e anexa o corpo ao agente de mesmo nome, sem copiá-lo. Outros campos são proibidos na extensão.
O stack pré-carrega só o essencial: implementer `[result-failure, bloc-testing]`, architect
`[clean-arch-layers, result-failure]`, planner `[clean-arch-layers]`, reviewer
`[result-failure]`. As demais skills são lidas sob demanda (a tarefa cita `sdd-<nome>`), e as
rules por glob carregam as regras de camada automaticamente.
**Motivo:** skills pré-carregadas entram inteiras no contexto (economia de tokens, princípio 7).
**Origem:** M5 (resolve a pendência do D-019).

## D-030 · Bricks do stack (2026-10)
**Decisão:**
- 6 bricks: `feature` (pastas), `failure`, `datasource` (extra: deixa o `repository`
  compilável sozinho), `repository`, `usecase` e `cubit`.
- Variáveis automáticas: `package` (do pubspec), `features_path`, `features_import` e
  `test_path`. Ficam em `scaffold.vars` do config: `result_import`, com `{package}`.
- Defaults podem referenciar outras variáveis (`default: "{feature}"`).
- Variáveis de caminho usam chave tripla (`{{{features_path}}}`): o mason escapa `/` em HTML.
- O scaffold nunca sobrescreve (conflito = `skipped`; conteúdo igual = `identical`).
- Contrato assumido: `Result<T, E>` selado com `Ok(value)` e `Err(error)`. Projetos com outro
  contrato trocam os bricks via `.sdd/overrides/bricks/`.
**Origem:** M5.

## D-031 · Código gerado passa nos gates (2026-10)
**Decisão:** depois de gerar, o `sdd scaffold` roda `dart fix --apply
--code=directives_ordering` em cada `.dart` criado (o `dart fix` aceita um único caminho;
passar o diretório mexeria em arquivos do usuário) e `dart format` neles.
Os membros públicos dos templates são documentados.
**Motivo:** a ordem dos imports e as quebras de linha dependem do nome do pacote e dos nomes
gerados. Validado num app Flutter real com `very_good_analysis`: analyze sem issues, format
sem mudanças e testes gerados passando.
**Origem:** M5.

## D-032 · Exceptions não mapeadas no repository (2026-10)
**Decisão:** o `RepositoryImpl` captura só `Exception`. As conhecidas viram Failures
específicas. As não mapeadas fazem `FlutterError.reportError(...)` (chega ao
`FlutterError.onError`, ou seja, ao Crashlytics) e retornam `Err(<Feature>UnexpectedFailure)`.
`Error` (bug) nunca é capturado.
**Motivo:** concilia "nenhuma exception atravessa o repository" com "erros não mapeados não
podem ser engolidos". É uma decisão do stack; projetos com reporter próprio trocam por override.
**Origem:** M5.

## D-033 · Importação (2026-10)
**Decisão:** `sdd import scan` percorre o caminho inteiro, ignorando `.git`, `build` e `.sdd`.
- **Tipo:** inferido pelo caminho (`agents/`, `commands/`, `rules/`, `SKILL.md`, `.mdc`,
  `CLAUDE.md`, `AGENTS.md`, `.cursorrules`).
- **Ferramenta:** inferida pelo caminho (`.claude`/`claude`, `.cursor`/`cursor`), pela
  extensão e pelo frontmatter.
- **Duplicatas:** mesmo tipo e nome, mesmo conteúdo normalizado, ou Jaccard de linhas ≥ 0,8.
- Arquivos gerados pelo sdd são ignorados.

O agente `importer` (deep) classifica e converte; o `/sdd-import` para para aprovação humana
entre os dois modos. Itens "kit" vão para `.sdd/kit-proposals.md`, nunca para o kit.
**Origem:** M5.

## D-034 · Formatação e análise deste repositório (2026-10)
**Decisão:** `kit/**` fica fora do analyzer, e o format do repo roda em `bin lib test`.
**Motivo:** os templates dos bricks são mustache, não Dart válido.
**Origem:** M5.

## D-035 · Argumentos e encadeamento dos comandos (2026-10)
**Decisão:**
- **Argumentos:** os comandos mantêm o texto neutro ("o argumento após o comando é ..."),
  sem `$ARGUMENTS`.
- **Encadeamento:** o `/sdd-run` lê e segue `{{sdd:skills_dir}}/sdd-<fase>/SKILL.md` com a
  ferramenta de leitura, e não usa a ferramenta de skills.
- **Pasta de skills:** a variável `skills_dir` vale `.claude/skills` quando claude é target
  (o Cursor também a lê); senão, `.cursor/skills`.

**Motivo:** verificado em 2026-10-03 em https://code.claude.com/docs/en/skills:
- quando nenhum placeholder recebe o argumento, o Claude Code anexa `ARGUMENTS: <entrada>`
  ao conteúdo;
- skills com `disable-model-invocation: true` não podem ser invocadas pelo modelo. Se ele
  tentar, a chamada é bloqueada e ele é instruído a não reproduzir os passos de outro jeito.

No Cursor, a doc não fala do texto após `/skill`; o texto neutro cobre os dois casos.
**Origem:** M6 (resolve a pendência do D-020).

## D-036 · Orquestração final (2026-10)
**Decisão:** os `/sdd-*` se apoiam só em contratos do CLI.
- **Loop do `/sdd-exec`:**
  - lê os campos do `tasks next --json` (`ready[].agent`, `ready[].file`, `in_progress`,
    `blocked`, `complete`);
  - marca `in_progress` antes de disparar os agentes em paralelo;
  - confirma cada tarefa com `sdd check --task --json` (`ok`, `interference`);
  - quem bloqueia por tentativas esgotadas é o CLI;
  - faz commit por onda na branch `sdd/<spec>`.
- **Revisão:**
  - `review in_progress` conta o ciclo;
  - o orquestrador passa o commit base (`git merge-base`) ao reviewer;
  - blockers/majors viram `Txx-fix-*` numa nova onda.
- **Fechamento:** o `/sdd-close` escreve `specs/<spec>/pr.md` e conduz a promoção das lições
  item a item.
- **Gates humanos:** nunca são aprovados pelo agente sem confirmação explícita.
**Origem:** M6.

## D-037 · Hook no `init` interativo (2026-10)
**Decisão:** o `init` interativo pergunta se o format-on-edit deve ser ligado (padrão: não).
`--yes` mantém desligado.
**Origem:** M6.
