---
name: dio-datasource
description: Datasources HTTP com Dio (contrato + implementação, DTOs, exceptions técnicas e de negócio) e realtime com SignalR via Stream. Use ao criar ou revisar a camada data.
---
# Datasources

## HTTP (Dio)
- Contrato `abstract interface class <Nome>RemoteDataSource` + `<Nome>RemoteDataSourceImpl(Dio)`.
- Retorna DTOs (`data/models/`), nunca entidades; o repository converte.
- **Lança exceptions**, não retorna `Result`:
  - técnicas: deixe o `DioException` subir;
  - de negócio: traduza o código/erro do backend para exceptions próprias da feature
    (`UserNotFoundException`, `BlockedUserException`) em `data/datasources/`.
- Sem `try/catch` genérico no datasource; sem lógica de retry escondida.
- `fromJson` valida o corpo e lança `FormatException` (uma `Exception`) quando o formato é
  inválido; nunca deixe `as` gerar `TypeError` (um `Error` não é capturado pelo repository e
  quebraria o fluxo de erro).
- DTO com `fromJson`/`toJson` explícitos (ou codegen, se o projeto usa: veja `commands.codegen`).

## Realtime (SignalR)
- O datasource expõe `Stream<EventoDto>` e métodos `connect()`/`disconnect()`.
- Falhas de conexão vão para um stream de estado de conexão separado (ver skill
  `sdd-result-failure`, caso SignalR); não feche o stream de eventos por erro transitório.

## Testes
Mocke `Dio` (mocktail) e cubra: sucesso (DTO), cada exception de negócio, erro técnico.
