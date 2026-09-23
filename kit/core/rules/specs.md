---
description: Regras para arquivos em specs/ (estado, IDs de AC e tarefas).
globs: ["specs/**"]
---
- `status.yaml` é escrito **só** pelo CLI: `sdd status set <spec> <alvo> <valor>`. Nunca edite.
- IDs de AC (`AC-xx`) aprovados nunca são renumerados.
- Tarefas seguem o frontmatter do template; valide com `sdd tasks validate <spec>`.
