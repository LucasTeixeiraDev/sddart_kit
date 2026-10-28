---
description: Fase 6 do SDD - confirma o DoD, gera a descrição do PR e conduz com o humano a promoção das lições candidatas para a memória.
args: <spec>
---
O argumento após o comando é o id da spec.

1. Confirme: `sdd check --spec <spec>` verde e `review.state = approved`
   (`sdd status <spec> --json`). Senão, pare e indique a fase pendente.
2. Escreva `specs/<spec>/pr.md`: resumo (3 a 5 linhas), ACs cobertos (AC → teste),
   decisões tomadas, minors conhecidos, como testar. Mostre ao humano.
3. **Lições** (skill `sdd-memory-curation`): apresente as lições candidatas do `review.md`
   numeradas e pergunte quais aprovar. Acrescente as aprovadas em
   `.sdd/memory/learnings.md` (`- [<spec>] <lição>`).
4. Para cada lição aprovada, proponha o destino e, com o "ok" do humano, aplique:
   regra de lint → tarefa ou issue com a proposta; kit → `.sdd/kit-proposals.md`;
   projeto → skill/rule em `.sdd/overrides/` + `sdd sync`; trade-off →
   `.sdd/memory/decisions.md` (`## D-NNN · título (AAAA-MM)`). Lição promovida sai do
   `learnings.md`; as não decididas ficam lá.
5. `sdd status set <spec> phase done` e faça o commit final na branch `sdd/<spec>`.
