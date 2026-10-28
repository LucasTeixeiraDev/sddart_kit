---
description: Camada presentation - cubit não conhece datasource; widget sem lógica de negócio.
globs: ["{{sdd:project.features_path}}/**/presentation/**"]
---
- Cubit recebe usecases; nunca importa `data/` (datasource, repository impl, DTO).
- Estados `sealed`; `switch` exaustivo no `Result`; sem `try/catch` no cubit.
- Widgets só leem estado e chamam métodos do cubit; nada de regra de negócio.
