---
description: Loop do orquestrador que executa as ondas de tarefas de uma spec com implementers em paralelo.
args: <spec>
---
O argumento após o comando é o id da spec. Você (sessão principal) é o orquestrador;
nunca delegue este loop a um subagente.

0. Trabalhe na branch `sdd/<spec>` (crie se preciso; nunca na main).
   `sdd status set <spec> phase exec`.
1. `sdd tasks next <spec> --json`.
2. Para cada tarefa pronta da onda: `sdd status set <spec> <Txx> in_progress` e dispare o
   agente indicado (`sdd-implementer-<tier>`) **em paralelo**, passando só o caminho da tarefa.
3. Para cada retorno: confirme com `sdd check --task <Txx> --json`.
   - verde → `sdd status set <spec> <Txx> done`
   - falha causada por arquivo de outra tarefa em andamento (interferência) → não marque
     falha; rechecar ao fim da onda.
   - falha → `sdd status set <spec> <Txx> failed`
4. Ao fim da onda: recheque as tarefas com interferência e faça commit da onda.
5. Tarefa `failed` sem tentativas: o `tasks next` indica o tier de escalonamento
   ({{sdd:execution.escalate_to}}) uma vez; depois `blocked` e **pare** para o humano.
6. Repita até não haver tarefas prontas; então `sdd check --spec <spec>`.

Não leia o código produzido pelos implementers; confie no retorno + `sdd check`.
