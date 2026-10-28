<!-- {{sdd:notice}} -->
## Spec-Driven Development (sdd)

Fluxo: PRD → análise [aprovação humana] → spec + plano [aprovação humana] → tarefas (DAG)
→ ondas de implementação em paralelo → gates → revisão → fechamento.

### Comandos
{{sdd:commands_list}}

### Onde fica cada coisa
Caminhos neste kit são relativos à raiz do projeto.
- Specs: `specs/NNNN-slug/` (`prd.md`, `analysis.md`, `spec.md`, `plan.md`, `tasks/`,
  `status.yaml`, `review.md`).
- Estado: `status.yaml` é escrito só pelo CLI (`sdd status set <spec> <alvo> <valor>`).
- Templates de fase: `.sdd/templates/` (gerados pelo sync).
- Memória: `.sdd/memory/decisions.md` e `.sdd/memory/learnings.md`. Não carregue por padrão;
  os agentes que precisam leem.
- Conteúdo do projeto: `.sdd/overrides/`. Nunca edite `.claude/`, `.cursor/` nem esta seção;
  rode `sdd sync`.

### Gates do projeto (DoD)
{{sdd:gates_list}}

Verifique com `sdd check --task <id>` (escopado) ou `sdd check --spec <id>` (completo);
agentes usam `--json`.

### Agentes
{{sdd:agents_list}}

### Skills
{{sdd:skills_list}}
