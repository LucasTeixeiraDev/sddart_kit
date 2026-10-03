---
description: Executa o fluxo SDD completo de uma spec (analyze → spec → tasks → exec → review → close), retomando da fase atual e parando nos gates humanos.
args: <spec>
---
O argumento após o comando é o id da spec.

1. `sdd status <spec> --json` para saber a fase e os gates.
2. Para cada fase a partir da atual, **leia com a ferramenta de leitura e siga** o arquivo da
   fase: `{{sdd:skills_dir}}/sdd-<fase>/SKILL.md`. Não use a ferramenta de skills: os
   comandos `/sdd-*` são só manuais e a chamada é bloqueada. Ordem:
   `analyze → spec → tasks → exec → review → close`.
3. Respeite os dois gates humanos: depois de `analyze` e de `spec`, **pare** até o humano
   aprovar (`analysis_approved`, `plan_approved`). Nunca aprove por conta própria.
4. Também pare em: tarefas `blocked`, limite de ciclos de revisão, `sdd tasks validate`
   falhando após 2 correções, ou qualquer erro de CLI com exit 2.
