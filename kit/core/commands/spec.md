---
description: Escreve spec.md e plan.md de uma spec com análise aprovada e para para aprovação do plano.
args: <spec>
---
O argumento após o comando é o id da spec.

1. Confirme `analysis_approved` em `sdd status <spec> --json`; se faltar, pare e avise.
2. `sdd status set <spec> phase spec`
3. Dispare `sdd-architect` com o caminho da spec.
4. Mostre o resumo do plano (ACs, contratos, decisões) e **pare**.

O humano aprova com `sdd status set <spec> gate plan_approved`.
