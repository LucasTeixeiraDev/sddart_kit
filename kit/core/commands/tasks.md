---
description: Fase 3 do SDD - quebra spec e plano aprovados em tarefas (DAG em ondas), valida e mostra o grafo.
args: <spec>
---
O argumento após o comando é o id da spec.

1. Exige `gates.plan_approved` (`sdd status <spec> --json`).
2. `sdd status set <spec> phase tasks`
3. Dispare `sdd-planner` com o caminho da spec. Ele roda `sdd tasks validate <spec>` até
   passar.
4. Confirme você mesmo: `sdd tasks validate <spec>`. Erros → devolva ao planner (máx. 2 vezes;
   depois pare e mostre ao humano). Avisos de AC sem tarefa também voltam ao planner.
5. Mostre `sdd tasks graph <spec>` e siga para `/sdd-exec` se estiver em `/sdd-run`.

Se o ambiente impedir o agente de gravar e ele devolver o conteúdo dos arquivos, grave-o
você mesmo, sem alterar.
