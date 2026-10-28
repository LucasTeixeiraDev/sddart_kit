---
description: Fase 2 do SDD - escreve spec.md (ACs Given/When/Then) e plan.md a partir da análise aprovada e para para aprovação do plano.
args: <spec>
---
O argumento após o comando é o id da spec.

1. `sdd status <spec> --json`: exige `gates.analysis_approved`; senão, pare e indique
   `/sdd-analyze`.
2. `sdd status set <spec> phase spec`
3. Dispare `sdd-architect` com o caminho da spec.
4. Mostre: lista de ACs (id + título), contratos novos/alterados, Failures, decisões com
   trade-off e o que ficou fora de escopo. **Pare.**
5. Ajustes pedidos pelo humano: redispare o architect com o pedido (não edite à mão).
6. Com aprovação explícita: `sdd status set <spec> gate plan_approved`.

Se o ambiente impedir o agente de gravar e ele devolver o conteúdo dos arquivos, grave-o
você mesmo, sem alterar.
