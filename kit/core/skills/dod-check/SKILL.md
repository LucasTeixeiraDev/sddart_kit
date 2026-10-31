---
name: dod-check
description: Como verificar a Definition of Done de uma spec - gates automáticos e checklist manual com evidência. Use na revisão e no fechamento.
---
# Verificação do DoD

## Gates automáticos
Rode `sdd check --spec <id> --json`. Gates configurados:
{{sdd:gates_list}}

## Checklist manual
Para cada item, registre no `review.md` a evidência (`arquivo:linha` ou comando) ou o achado:
{{sdd:dod_checklist}}

## Severidades (régua do reviewer)
- `blocker`: viola AC, item do DoD ou regra de arquitetura; quebra build ou gate.
- `major`: comportamento incorreto fora dos ACs; falha de tratamento de erro; teste que passa
  sem verificar de fato o AC.
- `minor`: nome, estilo, estrutura ou duplicação de teste, legibilidade (não gera correção).
