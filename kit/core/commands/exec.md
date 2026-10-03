---
description: Fase 4 do SDD - loop do orquestrador que executa as ondas de tarefas com implementers em paralelo, verificando cada uma com sdd check.
args: <spec>
---
O argumento após o comando é o id da spec. **Você (sessão principal) é o orquestrador; nunca
delegue este loop a um subagente.** Não leia o código produzido: confie no retorno do agente
e no `sdd check`.

## Preparação
- Trabalhe na branch `sdd/<spec>` (crie a partir da atual se não existir; nunca na main).
  O working tree deve começar limpo.
- `sdd status set <spec> phase exec`

## Loop
1. `sdd tasks next <spec> --json` → campos `complete`, `wave`, `ready[]` (`id`, `file`,
   `agent`, `tier`, `attempt`, `escalated`), `in_progress`, `blocked`.
2. `complete: true` → vá para "Fim".
3. Para cada item de `ready`: `sdd status set <spec> <id> in_progress` e dispare o agente
   `ready[].agent` **em paralelo** (uma chamada por tarefa, todas na mesma mensagem), passando
   só o caminho `ready[].file`.
4. Para cada retorno, confirme com `sdd check --task <id> --spec <spec> --json`:
   - `ok: true` → `sdd status set <spec> <id> done`
   - `interference: true` → mantenha `in_progress` (não consome tentativa); recheque no
     passo 6.
   - senão → `sdd status set <spec> <id> failed` (o CLI bloqueia sozinho quando acabam as
     tentativas).
5. Volte ao passo 1 enquanto houver `ready` na mesma onda.
6. Fim da onda (nada `ready`, nada aguardando agente): recheque as tarefas em interferência
   com `sdd check --task`; verde → `done`, vermelho → `failed` e redispare via passo 1.
7. Onda concluída: `git add -A && git commit -m "sdd(<spec>): onda <n>"`.
8. `blocked` não vazio e nada mais `ready` → **pare** e mostre ao humano as tarefas
   bloqueadas com o último resumo de `sdd check`.

## Fim
`sdd check --spec <spec>`. Verde → siga para `/sdd-review`. Vermelho → crie tarefas de
correção (ver `/sdd-review`, passo 4) ou pare e mostre ao humano.
