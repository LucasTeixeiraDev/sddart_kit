---
id: T03
title: WalletCubit e estados (carga na criação, refresh sem busca simultânea)
wave: 1
depends_on: [T01]
tier: deep
agent: implementer
owns:
  - lib/features/wallet/presentation/cubit/wallet_state.dart
  - lib/features/wallet/presentation/cubit/wallet_cubit.dart
  - test/features/wallet/presentation/cubit/wallet_cubit_test.dart
reads:
  - lib/core/result/result.dart
  - lib/features/wallet/domain/entities/wallet_balance.dart
  - lib/features/wallet/domain/failures/wallet_failure.dart
  - lib/features/wallet/domain/usecases/fetch_wallet_balance_use_case.dart
exemplar: lib/features/profile/presentation/cubit/profile_cubit.dart
acceptance: [AC-01, AC-14, AC-15, AC-16]
---
## Objetivo
Implementar o estado da tela de saldo: busca automática na criação e "Atualizar" que volta ao carregamento
e é ignorado durante uma busca em andamento.

## Detalhes
Leia a skill `sdd-cubit-patterns` e siga o exemplar.

Contratos (plan.md · Presentation):
```dart
// cubit/wallet_state.dart  (part of 'wallet_cubit.dart') — igualdade por valor
sealed class WalletState { const WalletState(); }
final class WalletLoading extends WalletState {}
final class WalletLoaded extends WalletState { final WalletBalance balance; }
final class WalletError extends WalletState { final WalletFailure failure; }

// cubit/wallet_cubit.dart
class WalletCubit extends Cubit<WalletState> {
  /// Começa em WalletLoading e já dispara a busca.
  WalletCubit(this._fetchBalance) : super(const WalletLoading()) { _load(); }
  final FetchWalletBalanceUseCase _fetchBalance;
  /// Botão "Atualizar". Ignorado se o estado atual for WalletLoading.
  Future<void> refresh();   // emit(WalletLoading()) e _load()
  Future<void> _load();     // await usecase; if (isClosed) return; switch exaustivo Ok/Err
}
```
- **Sem estado `Initial`** e sem `try/catch` no cubit (o usecase nunca lança).
- Guard de concorrência: `refresh()` retorna sem fazer nada se `state is WalletLoading`; como toda busca
  começa emitindo `WalletLoading`, nunca há duas em andamento.

Testes (`bloc_test` + mocktail):
- `[AC-01]` estado inicial é `WalletLoading` e o usecase é chamado uma vez na criação; emite `WalletLoaded`.
- `[AC-14]` a partir de `WalletLoaded(12345)`, `refresh` emite `WalletLoading` e depois `WalletLoaded(20000)`.
- `[AC-15]` a partir de `WalletError(WalletBlockedFailure())`, `refresh` emite `WalletLoading` e `WalletLoaded(12345)`.
- `[AC-16]` `refresh` enquanto a busca inicial não terminou (use `Completer`) não chama o usecase de novo (`verify(...).called(1)`).
- Erro: `Err(WalletServerFailure())` → `WalletError`.

## Pronto da tarefa
- [ ] `sdd check --task T03` verde
