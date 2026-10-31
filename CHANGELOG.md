# Changelog

## 0.1.0 (em desenvolvimento)
- Pós-M7: bricks só de esqueleto e de uma camada (`repository-contract`, `repository-impl`,
  `repository-test`, `cubit-test`), `brick_vars` + checagem no `tasks validate`,
  `sdd scaffold --task`, `meta` esperado no stack, régua de severidade do reviewer.
- M7: dogfooding com fluxo completo; `write_allow` + `sdd hook guard-write` (reviewer grava
  só o `review.md`); arquivo sem dono vira interferência durante a onda; `scaffold` aceita
  pares `k=v` soltos; correção de conflito de templates no `sync`; ajustes de kit.
- M6: versão final dos comandos `/sdd-*` (exec, review, close, run), fluxo de memória,
  pergunta de format-on-edit no `init`, README completo.
- M5: stack pack `flutter-clean-cubit` (skills, rules, extensões de agentes, 6 bricks),
  `sdd scaffold`, `sdd import scan`, agente `importer` e `/sdd-import`.
- M4: `sdd check` (modo tarefa e DoD completo), parsers de analyze/format/test/lcov,
  rastreabilidade, verificação de `owns` com interferência; `format` padrão sem escrita.
- M3: `sdd new`, `tasks validate|graph|next`, `status`, `status set` (lock + guardas),
  templates de fase em `.sdd/templates/`; correção do hash do `kit.lock`.
- M2: kit core, adapters Claude/Cursor, `sdd sync [--check]`, AGENTS.md/CLAUDE.md gerenciados,
  hooks `sdd hook format|guard-bash`.
- M1: esqueleto do CLI, `sdd init`, `sdd doctor`, config em camadas, `kit.lock`.
