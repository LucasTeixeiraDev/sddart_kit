---
description: Fase 5 do SDD - revisão somente leitura contra spec, plano e DoD; cria tarefas de correção para blockers/majors (máx. de ciclos configurado).
args: <spec>
---
O argumento após o comando é o id da spec.

1. `sdd status set <spec> phase review`
2. `sdd status set <spec> review in_progress` (conta um ciclo; acima de
   `execution.max_review_cycles` o CLI recusa) → se recusar, **pare** e escale para o humano.
3. Calcule a base do diff (`git merge-base HEAD <branch de origem da sdd/<spec>>`) e dispare
   `sdd-reviewer` com o caminho da spec, o commit base e, a partir do 2º ciclo, o commit em
   que o ciclo anterior foi revisado; ele escreve `review.md`.
4. Com `blocker` ou `major`:
   - `sdd status set <spec> review changes_requested blockers=<n de blockers>`
   - crie `tasks/Txx-fix-<slug>.md` (próximos ids, **nova onda** = maior onda + 1), um por
     achado ou grupo coeso, seguindo a skill `sdd-task-breakdown`, com o achado em
     `## Detalhes`;
   - `sdd tasks validate <spec>`, `sdd status set <spec> phase exec` e volte ao `/sdd-exec`;
     depois, `/sdd-review` de novo.
5. Sem blockers/majors: `sdd status set <spec> review approved blockers=0` e siga para
   `/sdd-close`. Minors ficam registrados no `review.md` para o PR.

Se o ambiente impedir o agente de gravar e ele devolver o conteúdo dos arquivos, grave-o
você mesmo, sem alterar.
