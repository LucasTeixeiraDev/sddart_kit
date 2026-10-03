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
