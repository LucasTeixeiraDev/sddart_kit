---
id: T01
title: <título>
wave: 0
depends_on: []
tier: standard
agent: implementer
owns:
  - <arquivo>
reads: []          # contratos que a tarefa lê (existem ou são owns de dependências)
acceptance: []     # ACs da spec cobertos por testes desta tarefa
# exemplar: lib/...  # opcional: arquivo existente a imitar
# brick: failure                 # opcional: esqueleto; a saída precisa estar em owns
# brick_vars: {feature: wallet}   # obrigatório com brick (sdd scaffold --task <id>)
---
## Objetivo

## Detalhes

## Pronto da tarefa
- [ ] `sdd check --task T01` verde
