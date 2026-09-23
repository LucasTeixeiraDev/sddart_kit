---
description: Quebra uma spec com plano aprovado em tarefas validadas e mostra o grafo de ondas.
args: <spec>
---
O argumento após o comando é o id da spec.

1. Confirme `plan_approved` em `sdd status <spec> --json`; se faltar, pare.
2. `sdd status set <spec> phase tasks`
3. Dispare `sdd-planner` com o caminho da spec.
4. Rode `sdd tasks validate <spec>`; se falhar, devolva os erros ao planner.
5. Mostre `sdd tasks graph <spec>`.
