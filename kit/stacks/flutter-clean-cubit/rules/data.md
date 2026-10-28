---
description: Camada data - repository é a fronteira; nenhuma exception escapa dele.
globs: ["{{sdd:project.features_path}}/**/data/**"]
---
- `*RepositoryImpl` captura só `Exception`, mapeia para Failures da feature e retorna `Result`;
  nenhuma exception atravessa o repository.
- Exception não mapeada: `FlutterError.reportError(...)` + `Err(<Feature>UnexpectedFailure)`. Nunca engula.
- Nunca capture `Error` (bugs seguem para o Crashlytics).
- Datasources lançam exceptions (técnicas ou de negócio) e trabalham com DTOs, não entidades.
