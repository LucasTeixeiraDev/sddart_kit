---
id: T08
title: "Correção: teste do datasource com HttpClientAdapter fake"
wave: 4
depends_on: [T02]
tier: standard
agent: implementer
owns:
  - test/features/wallet/data/datasources/wallet_remote_data_source_test.dart
  - lib/features/wallet/data/datasources/wallet_remote_data_source.dart
reads:
  - lib/features/wallet/data/models/wallet_balance_dto.dart
exemplar: test/features/profile/data/datasources/profile_remote_data_source_test.dart
acceptance: [AC-07, AC-08, AC-12]
---
## Objetivo
Corrigir o achado major do review.md (ciclo 1): o teste do datasource deve usar um `Dio` real
com `HttpClientAdapter` fake, não `_MockDio`.

## Detalhes
- Achado: `wallet_remote_data_source_test.dart:6` usa mocktail para `Dio` e entrega a
  `DioException` pronta; não exercita `validateStatus` (403 → `badResponse`), a decodificação
  do corpo `{"code": "WLT_403"}` nem o corpo vazio/nulo de verdade.
- Crie um adapter fake (`implements HttpClientAdapter`) que devolve `ResponseBody.fromString`
  com status e headers `content-type: application/json`, e use `Dio(BaseOptions(baseUrl: ...))`
  com `httpClientAdapter = fake`.
- Cubra com tags: `[AC-07]` 403 + `WLT_403` → `WalletBlockedException`; `[AC-08]` 403 sem
  código → `DioException` propagada; `[AC-12]` corpo vazio e corpo malformado →
  `FormatException`; sucesso com `GET /wallet/balance` verificado no adapter.
- Só altere `wallet_remote_data_source.dart` se o teste real revelar bug de decodificação.

## Pronto da tarefa
- [ ] `sdd check --task T08` verde
