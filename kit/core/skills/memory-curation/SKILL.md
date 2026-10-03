---
name: memory-curation
description: Ciclo das lições - de candidatas no review.md para learnings.md e daí para o destino certo (lint, kit, overrides, decisions). Use no /sdd-close.
---
# Curadoria de memória

`learnings.md` é caixa de entrada, não destino. Só o `/sdd-close` escreve nele, com lições
candidatas aprovadas pelo humano, uma por item: `- [<spec>] <lição>`.

## Boa lição
Específica, acionável e generalizável: "repository de auth engolia `DioException` sem
reportar" vira "todo `catch` genérico em repository reporta via `FlutterError.reportError`".
Descarte o que é só correção pontual.

## Destino de cada lição
- Verificável por máquina → regra de lint (`custom_lint`).
- Convenção geral de Flutter/stack → proposta para o kit (`.sdd/kit-proposals.md`).
- Específica do projeto → `.sdd/overrides/` (skill ou rule).
- Escolha com trade-off → `.sdd/memory/decisions.md` no formato
  `## D-NNN · título (AAAA-MM)` com Decisão, Motivo e Origem.

Depois de promovida, remova a lição do `learnings.md`. O `sdd status` alerta acima de
{{sdd:memory.learnings_warn_after}} lições pendentes.
