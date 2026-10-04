---
name: clean-arch-layers
description: Camadas da clean architecture por feature (domain, data, presentation), dependências permitidas e onde cada tipo de arquivo vive. Use ao planejar ou criar arquivos de uma feature.
---
# Camadas por feature

`{{sdd:project.features_path}}/<feature>/`:

| Camada | Pastas | Contém | Pode importar |
|---|---|---|---|
| domain | `entities/`, `repositories/`, `usecases/`, `failures/` | entidades, contratos de repository, usecases, Failure selado | só Dart puro e outros domains |
| data | `datasources/`, `models/`, `repositories/` | datasources (Dio/SignalR), DTOs, `*RepositoryImpl` | domain da própria feature, Dio |
| presentation | `pages/`, `widgets/`, `cubit/` | pages, widgets, cubits e states | domain (usecases, entidades, failures) |

Fluxo: `Cubit → UseCase → Repository (contrato) → RepositoryImpl → DataSource`.

## Regras
- domain não importa Flutter, Dio nem nada de `data/` ou `presentation/`.
- presentation não conhece datasource nem `RepositoryImpl`; recebe usecases por injeção.
- DTO (data) ≠ entidade (domain): o repository converte.
- Helpers puros de apresentação (formatadores, máscaras) em `presentation/formatters/`.
- Com very_good_analysis, igualdade por valor (`==`/`hashCode`) exige `@immutable`
  (`package:meta` no pubspec); sem `meta`, prefira não sobrescrever `==` em entidades.
- Testes espelham o caminho em `{{sdd:project.test_path}}/features/<feature>/...`.
- Bricks: `feature` (pastas), `failure`, `usecase`, `repository`, `datasource`, `cubit`
  (`sdd scaffold <brick> --vars feature=<f> --vars name=<n>`).
