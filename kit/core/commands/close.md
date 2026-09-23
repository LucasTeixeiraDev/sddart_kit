---
description: Fecha uma spec - confirma o DoD, gera a descrição do PR e conduz a promoção das lições candidatas.
args: <spec>
---
O argumento após o comando é o id da spec.

1. `sdd check --spec <spec>` precisa estar verde e `review.md` sem `blocker`/`major`.
2. Gere a descrição do PR: resumo, ACs cobertos (com testes), decisões tomadas.
3. Promoção de lições (skill `sdd-memory-curation`): apresente as lições candidatas do
   `review.md`, registre as aprovadas em `.sdd/memory/learnings.md` e proponha o destino de
   cada uma. Após promovida, a lição sai do `learnings.md`.
4. `sdd status set <spec> phase done`.
