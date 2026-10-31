---
id: T01
title: Contratos de domain da carteira (entidade, failures, repository, usecase)
wave: 0
depends_on: []
tier: deep
agent: implementer
brick: failure
brick_vars: {feature: wallet}
owns:
  - lib/features/wallet/domain/failures/wallet_failure.dart
  - lib/features/wallet/domain/entities/wallet_balance.dart
  - lib/features/wallet/domain/repositories/wallet_repository.dart
  - lib/features/wallet/domain/usecases/fetch_wallet_balance_use_case.dart
  - test/features/wallet/domain/usecases/fetch_wallet_balance_use_case_test.dart
reads:
  - lib/core/result/result.dart
exemplar: lib/features/profile/domain/failures/profile_failure.dart
acceptance: []
---
## Objetivo
Criar os contratos de domain da feature `wallet` contra os quais data, cubit e UI serão codificados.

## Detalhes
Esqueleto: `sdd scaffold --task T01` (failure); o resto segue o exemplar.

Assinaturas exatas (plan.md · Domain):
```dart
// entities/wallet_balance.dart — sempre BRL; igualdade por valor (== / hashCode)
final class WalletBalance {
  const WalletBalance({required this.amountCents});
  final int amountCents;
}

// repositories/wallet_repository.dart
abstract interface class WalletRepository {
  /// Busca o saldo atual. Nunca lança.
  Future<Result<WalletBalance, WalletFailure>> fetchBalance();
}

// usecases/fetch_wallet_balance_use_case.dart
class FetchWalletBalanceUseCase {
  const FetchWalletBalanceUseCase(this._repository);
  final WalletRepository _repository;
  Future<Result<WalletBalance, WalletFailure>> call() => _repository.fetchBalance();
}

// failures/wallet_failure.dart — todas as subclasses neste arquivo, construtor const ([super.message])
sealed class WalletFailure { const WalletFailure([this.message]); final String? message; }
final class WalletBlockedFailure extends WalletFailure {}              // 403 + WLT_403
final class WalletNetworkFailure extends WalletFailure {}              // sem conexão / timeout
final class WalletUnsupportedCurrencyFailure extends WalletFailure {}  // currency != "BRL" (message = moeda recebida)
final class WalletServerFailure extends WalletFailure {}               // demais respostas HTTP / erros Dio
final class WalletUnexpectedFailure extends WalletFailure {}           // Exception não mapeada (reportada)
```
Teste do usecase (mocktail): repassa `Ok(WalletBalance(amountCents: 12345))` e um `Err(WalletNetworkFailure())`
do repository; inclua um caso de igualdade por valor de `WalletBalance` (mesmo `amountCents` ⇒ `==` e mesmo `hashCode`),
para manter a cobertura de domain ≥ 80%.

## Pronto da tarefa
- [ ] `sdd check --task T01` verde
