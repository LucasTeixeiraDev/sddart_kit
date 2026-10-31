---
id: T05
title: WalletRepositoryImpl (fronteira de erro Exception → WalletFailure)
wave: 2
depends_on: [T01, T02]
tier: deep
agent: implementer
brick: repository-impl
brick_vars: {feature: wallet}
owns:
  - lib/features/wallet/data/repositories/wallet_repository_impl.dart
  - test/features/wallet/data/repositories/wallet_repository_impl_test.dart
reads:
  - lib/core/result/result.dart
  - lib/features/wallet/domain/repositories/wallet_repository.dart
  - lib/features/wallet/domain/failures/wallet_failure.dart
  - lib/features/wallet/data/datasources/wallet_remote_data_source.dart
  - lib/features/wallet/data/models/wallet_balance_dto.dart
exemplar: lib/features/profile/data/repositories/profile_repository_impl.dart
acceptance: [AC-07, AC-08, AC-09, AC-10, AC-11, AC-12, AC-13]
---
## Objetivo
Implementar `WalletRepositoryImpl implements WalletRepository`, a fronteira que converte exceções do
datasource em `Result<WalletBalance, WalletFailure>` e nunca lança `Exception`.

## Detalhes
Esqueleto: `sdd scaffold --task T05` (repository-impl); siga o exemplar para os métodos.

Mapeamento (plan.md · Data), capturando **só `Exception`**:

| Origem | Condição | Result |
|---|---|---|
| datasource | `WalletBlockedException` | `Err(WalletBlockedFailure())` |
| Dio | `DioException.type` em `connectionError`, `connectionTimeout`, `sendTimeout`, `receiveTimeout` | `Err(WalletNetworkFailure(e.message))` |
| Dio | demais `DioException` (`badResponse` — 401, 5xx, 403 sem `WLT_403` —, `cancel`, `badCertificate`, `unknown`) | `Err(WalletServerFailure(e.message))` |
| DTO ok | `dto.currency != 'BRL'` | `Err(WalletUnsupportedCurrencyFailure(dto.currency))` (não reportado) |
| outra `Exception` (inclui `FormatException`) | — | `FlutterError.reportError(...)` + `Err(WalletUnexpectedFailure(e.toString()))` |
| `Error` (`TypeError`, `StateError`...) | — | não capturar; segue ao handler global |

- Sucesso: `Ok(dto.toEntity())` quando `currency == 'BRL'`.
- 401/5xx/`unknown` e moeda ≠ BRL **não** são reportados ao Crashlytics; só a linha "outra Exception" chama `FlutterError.reportError`.

Testes (datasource mockado; tag do AC no nome):
- `[AC-07]` `WalletBlockedException` → `WalletBlockedFailure`.
- `[AC-08]` `DioException.badResponse` 403 sem `WLT_403` → `WalletServerFailure`.
- `[AC-09]` `connectionError` → `WalletNetworkFailure`.
- `[AC-10]` um teste por `connectionTimeout`, `sendTimeout`, `receiveTimeout` → `WalletNetworkFailure`.
- `[AC-11]` `badResponse` 500 e 401 → `WalletServerFailure`; `unknown` → `WalletServerFailure`.
- `[AC-12]` `FormatException` → `WalletUnexpectedFailure` e `FlutterError.reportError` chamado
  (substitua `FlutterError.onError` no teste e restaure no `tearDown`).
- `[AC-13]` DTO com `currency: 'USD'` → `WalletUnsupportedCurrencyFailure('USD')`, sem reportar.
- Sucesso BRL → `Ok(WalletBalance(amountCents: 12345))`; `StateError` do datasource propaga (não é capturado).

## Pronto da tarefa
- [ ] `sdd check --task T05` verde
