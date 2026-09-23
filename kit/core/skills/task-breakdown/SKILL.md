---
name: task-breakdown
description: Como quebrar um plano em tarefas contract-first com ondas, owns sem sobreposição, reads mínimo, exemplar e tier pelo risco. Use ao gerar ou corrigir tasks/.
---
# Quebra em tarefas

## Ondas
- **Onda 0**: contratos de domain (entidades, contratos de repository, usecases, Failures).
- **Ondas 1..N**: data, cubits e UI em paralelo, codificando contra os contratos da onda 0.
- **Onda final**: integração (DI, rotas).
- `depends_on` só aponta para tarefas de ondas anteriores.

## Cada tarefa
- 1 a ~5 arquivos em `owns` (incluindo o teste). Duas tarefas da mesma onda nunca possuem
  o mesmo arquivo.
- `reads` mínimo: só contratos e arquivos realmente necessários.
- `exemplar` sempre que houver um arquivo que já implementa o mesmo padrão.
- `brick` quando um brick do stack gerar o esqueleto.
- `acceptance`: ACs cobertos. Todo AC da spec deve aparecer em ao menos uma tarefa.

## Tier pelo risco
- `deep`: contratos, fluxos complexos, concorrência, migração.
- `standard`: implementação com contrato + exemplar.
- `fast`: repetição de padrão já existente.

## Formato
Frontmatter conforme o template de tarefa; corpo com `## Objetivo`, `## Detalhes` e
`## Pronto da tarefa` (sempre inclui `sdd check --task <id>` verde).
Valide com `sdd tasks validate <spec>`.
