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

## M2 — Kit core + sync
- [ ] Modelo canônico (agent, skill, rule, command, template) + camadas kit/overrides
- [ ] `ClaudeAdapter` e `CursorAdapter` (goldens), variantes de tier, prefixo `sdd-`
- [ ] Comandos como skills manuais (D-003); hooks de agente do reviewer (D-008)
- [ ] AGENTS.md gerenciado, CLAUDE.md com `@AGENTS.md`, cabeçalhos, manifesto e órfãos
- [ ] `sdd sync [--check]` idempotente; `init` chama `sync`; doctor checa "sync em dia"
- [ ] Kit core inicial; `docs/adapters.md` completo

## M3 — Specs e tarefas
- [ ] `sdd new`, `tasks validate|graph|next`, `status`, `status set` (lock + escrita atômica)

## M4 — Gates
- [ ] `sdd check` escopado e completo, `owns` via git com regra de interferência (D-007), lcov,
      rastreabilidade, saída compacta e `--json`

## M5 — Stack pack e importação
- [ ] Skills, rules, bricks, `sdd scaffold`, `sdd import scan`, `/sdd-import`

## M6 — Orquestração e memória
- [ ] Agentes e comandos finais, memória, hooks opcionais (D-012), README completo, CHANGELOG

## M7 — Dogfooding
- [ ] Fixture realista de ponta a ponta (também como teste de integração)
