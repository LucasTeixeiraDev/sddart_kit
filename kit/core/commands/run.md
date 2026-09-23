---
description: Executa o fluxo SDD completo de uma spec, parando nos dois gates humanos.
args: <spec>
---
O argumento após o comando é o id da spec. Consulte `sdd status <spec> --json` e retome da fase atual:

1. `/sdd-analyze` → **pare** até `analysis_approved`.
2. `/sdd-spec` → **pare** até `plan_approved`.
3. `/sdd-tasks` → `/sdd-exec` → `/sdd-review` (até 2 ciclos) → `/sdd-close`.

Nunca pule um gate humano, mesmo que o conteúdo pareça óbvio.
