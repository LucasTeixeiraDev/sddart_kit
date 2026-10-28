---
description: Camada domain - Dart puro, sem Flutter, Dio ou imports de data/presentation.
globs: ["{{sdd:project.features_path}}/**/domain/**"]
---
- Proibido importar `package:flutter/`, `package:dio/` ou qualquer arquivo de `data/` ou `presentation/`.
- Repositories são contratos (`abstract interface class`) que retornam `Result<T, <Feature>Failure>`.
- Failures da feature: `sealed class` em `domain/failures/`, subclasses no mesmo arquivo.
- Usecases têm um único método `call` e não lançam exceptions.
