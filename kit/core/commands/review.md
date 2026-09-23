---
description: Revisa a implementação de uma spec contra spec, plano e DoD; cria tarefas de correção se necessário.
args: <spec>
---
O argumento após o comando é o id da spec.

1. `sdd status set <spec> phase review`
2. Dispare `sdd-reviewer` com o caminho da spec.
3. Com `blocker` ou `major` em `review.md`: crie tarefas `tasks/Txx-fix-*.md` numa nova onda
   (skill `sdd-task-breakdown`), rode `sdd tasks validate <spec>` e volte ao `/sdd-exec`.
4. Máximo de 2 ciclos de revisão; depois disso, pare e escale para o humano.
