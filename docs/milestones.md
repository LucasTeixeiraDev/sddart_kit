# Milestones

Legenda: [x] feito · [ ] pendente. Detalhes das decisões em `decisions.md`.

## M0 — Plano e perguntas ✅
- [x] Docs de Claude Code e Cursor consultadas (2026-09-23)
- [x] Plano por milestone, estratégia do kit, riscos e 13 perguntas respondidas (D-001..D-012)

## M1 — Esqueleto do CLI ✅
- [x] `pubspec.yaml`, `very_good_analysis`, `.gitignore`
- [x] Infra: `ProcessRunner` (real/fake), `Logger` (humano/JSON/verbose), `Prompter`, `ExitCodes` (0/1/2)
- [x] `SddCommandRunner` com `--json`, `--verbose`, `--version`, `--kit-path`
- [x] Config: modelo tipado, parser com erros agregados, camadas core → stack → projeto, models por ferramenta
- [x] `KitLocator` (flag > env > pacote), `kit.lock` com hash e checagem de compatibilidade
- [x] `stack.yaml` do `flutter-clean-cubit` (defaults, detecção, `gate_requirements`)
- [x] `sdd init` (detecção, interativo/`--yes`, `--stack`, `--force`, `--json`)
- [x] `sdd doctor` (dart, flutter, git, repo, kit, stack, config, avisos de modelo, kit.lock)
- [x] Fixtures `app_cubit`, `app_plain_dart`, `app_no_features`; 65 testes; cobertura de `lib/src/core/` 98%
- [x] `dart compile exe` compila e roda (com `SDD_KIT_PATH`)

## M2 — Kit core + sync ✅
- [x] Modelo canônico (agent, skill, rule, command, template), frontmatter e camadas core → stack → overrides (D-019)
- [x] Variáveis `{{sdd:chave}}` no conteúdo do kit (D-016)
- [x] `ClaudeAdapter` e `CursorAdapter` com goldens; variantes de tier; prefixo `sdd-`; modelos por ferramenta
- [x] Comandos como skills manuais (D-003); hook `PreToolUse` do reviewer via `sdd hook guard-bash` (D-008, D-017)
- [x] AGENTS.md gerenciado, CLAUDE.md com `@AGENTS.md`, avisos, manifesto, órfãos, conflitos (D-018)
- [x] Hooks de format-on-edit com merge em JSON do usuário (D-012)
- [x] `sdd sync [--check]` idempotente; `init` chama `sync`; `doctor` checa sync e `sdd` no PATH
- [x] Kit core inicial: 6 agentes, 8 comandos, 5 skills, 1 rule, templates
- [x] `docs/adapters.md` completo; 119 testes; cobertura de `lib/src/core/` 98%

## M3 — Specs e tarefas ✅
- [x] `sdd new` (slug ASCII, numeração de 4 dígitos, `prd.md` do template, `status.yaml` inicial)
- [x] Parser de tarefas com erros por arquivo/campo; validação completa do DAG (D-025)
- [x] `tasks validate`, `tasks graph [--mermaid]`, `tasks next [--json]` com tentativas e escalonamento (D-023)
- [x] `status` (lista/detalhe/json, aviso de learnings) e `status set` com guardas (D-022)
- [x] Escrita de `status.yaml` sob lock do SO + rename atômico (D-021)
- [x] Templates de fase exportados para `.sdd/templates/` pelo sync (D-024)
- [x] Correção: hash do `kit.lock` podia sair negativo (formatação de 64 bits)
- [x] Fixture `app_with_spec` (DAG de 4 tarefas em 3 ondas); 167 testes; cobertura de `lib/src/core/` 99%

## M4 — Gates ✅
- [x] `sdd check --task` (format/analyze/test nos `owns` + verificação de `owns` via git) e `sdd check [--spec]` (DoD completo)
- [x] Comandos sem shell, `{files}`, `--reporter json` automático, `test_all` com cobertura (D-026)
- [x] Parsers de analyze (machine e humano), format, `flutter test --reporter json`, lcov e genérico (D-028)
- [x] Cobertura por lcov filtrada por `dod.coverage.paths`; rastreabilidade de AC
- [x] Tolerância de `owns` e marcação de interferência `INTF` (D-027)
- [x] Saída compacta (`FAIL/INTF/PASS/SKIP`, `--max-lines`) e `--json` estável
- [x] Teste manual com Flutter, git e cobertura reais; correção do `format` no modo completo
- [x] 201 testes; cobertura de `lib/src/core/` 99%

## M5 — Stack pack e importação ✅
- [x] Skills `clean-arch-layers`, `result-failure`, `cubit-patterns`, `bloc-testing`, `dio-datasource`
- [x] Rules por glob (`domain`, `data`, `presentation`, `tests`) com caminhos do config
- [x] Extensão de agentes do core pelo stack (D-029)
- [x] 6 bricks + `sdd scaffold` (mason, variáveis automáticas, `--task` checa owns) (D-030, D-031)
- [x] Bricks validados num app Flutter real: analyze (very_good_analysis), format e testes verdes
- [x] `sdd import scan`, agente `importer`, skill `import-conversion`, `/sdd-import` (D-033)
- [x] Fixture `import_source` (duplicatas Claude/Cursor, layout de repositório, arquivo gerado)
- [x] 219 testes; cobertura de `lib/src/core/` 99%

## M6 — Orquestração e memória ✅
- [x] Versão final dos 8 comandos `/sdd-*` sobre os contratos do CLI (D-036)
- [x] `/sdd-run` encadeia as fases lendo os `SKILL.md`; argumentos verificados nas docs (D-035)
- [x] Reviewer com base do diff e lições com destino; `/sdd-close` com `pr.md` e promoção
- [x] Hooks opcionais: format-on-edit perguntado no `init` interativo (D-037); guard do reviewer
- [x] README completo (instalação, quickstart, referência, config, overrides, memória, hooks, CI, stack pack)
- [x] `pub global activate --source path` validado num PUB_CACHE isolado; `dart compile exe` ok
- [x] 220 testes; cobertura de `lib/src/core/` 99%

## M7 — Dogfooding
- [ ] Fixture realista de ponta a ponta (também como teste de integração)
