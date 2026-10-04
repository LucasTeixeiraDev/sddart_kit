---
id: T02
title: DTO e datasource remoto do saldo (GET /wallet/balance)
wave: 1
depends_on: [T01]
tier: standard
agent: implementer
brick: datasource
owns:
  - lib/features/wallet/data/models/wallet_balance_dto.dart
  - lib/features/wallet/data/datasources/wallet_remote_data_source.dart
  - test/features/wallet/data/models/wallet_balance_dto_test.dart
  - test/features/wallet/data/datasources/wallet_remote_data_source_test.dart
reads:
  - lib/features/wallet/domain/entities/wallet_balance.dart
exemplar: lib/features/profile/data/datasources/profile_remote_data_source.dart
acceptance: [AC-07, AC-08, AC-12]
---
## Objetivo
Implementar o `WalletBalanceDto` (validação do corpo) e o `WalletRemoteDataSourceImpl` sobre Dio, que
distingue o 403 de carteira bloqueada.

## Detalhes
Leia a skill `sdd-dio-datasource`. Esqueleto: `sdd scaffold datasource --vars feature=wallet name=wallet_remote`.
Exemplo de DTO: `lib/features/profile/data/models/profile_dto.dart`.

Contratos (plan.md · Data):
```dart
// models/wallet_balance_dto.dart
class WalletBalanceDto {
  const WalletBalanceDto({required this.amountCents, required this.currency});
  /// Lança FormatException (Exception, não Error) se o corpo não for
  /// {"amount_cents": int, "currency": String}, inclusive corpo nulo.
  factory WalletBalanceDto.fromJson(Object? json);
  final int amountCents;
  final String currency;
  WalletBalance toEntity() => WalletBalance(amountCents: amountCents);
}

// datasources/wallet_remote_data_source.dart
/// Backend respondeu HTTP 403 com {"code": "WLT_403"}.
class WalletBlockedException implements Exception {}

abstract interface class WalletRemoteDataSource {
  /// GET /wallet/balance. Lança WalletBlockedException, DioException ou FormatException.
  Future<WalletBalanceDto> fetchBalance();
}
class WalletRemoteDataSourceImpl implements WalletRemoteDataSource {
  const WalletRemoteDataSourceImpl(this._dio);
}
```
- `fromJson` usa pattern matching (`if (json case {'amount_cents': final int a, 'currency': final String c})`),
  **sem `as`**, para que corpo malformado gere `FormatException` e nunca `TypeError`.
- O DTO **não** valida a moeda (regra de negócio, fica no repository — T05).
- Implementação: `_dio.get<Object?>('/wallet/balance')` → `WalletBalanceDto.fromJson(response.data)` (sem `!`).
  Em `on DioException catch (e)`: se `e.response?.statusCode == 403` **e** `e.response?.data case {'code': 'WLT_403'}`
  → `throw WalletBlockedException()`; senão `rethrow`.

Testes (nomes com a tag do AC):
- DTO: corpo válido; `{"amount_cents": "12,34", "currency": "BRL"}`, sem `currency`, `null` e corpo vazio → `FormatException` `[AC-12]`.
- Datasource (Dio mockado, como no exemplar): sucesso; 403 + `{"code": "WLT_403"}` → `WalletBlockedException` `[AC-07]`;
  403 sem código ou com outro código → rethrow da `DioException` `[AC-08]`; 200 com corpo malformado/nulo → `FormatException` `[AC-12]`.

## Pronto da tarefa
- [ ] `sdd check --task T02` verde
