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

## Severidades
- `blocker`: AC não atendido, gate vermelho, violação de item do checklist.
- `major`: desvio do plano ou de decisões sem justificativa, teste fraco para um AC.
- `minor`: legibilidade, nomes, duplicação local.
