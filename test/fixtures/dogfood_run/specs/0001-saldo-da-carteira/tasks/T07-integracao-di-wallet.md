---
id: T07
title: Integração da carteira no Dependencies (walletCubit)
wave: 3
depends_on: [T03, T05, T06]
tier: fast
agent: implementer
owns:
  - lib/core/di/dependencies.dart
reads:
  - lib/features/wallet/data/datasources/wallet_remote_data_source.dart
  - lib/features/wallet/data/repositories/wallet_repository_impl.dart
  - lib/features/wallet/domain/usecases/fetch_wallet_balance_use_case.dart
  - lib/features/wallet/presentation/cubit/wallet_cubit.dart
exemplar: lib/core/di/dependencies.dart
acceptance: [AC-01]
---
## Objetivo
Expor a tela de saldo para quem for montá-la, via `Dependencies.walletCubit()`, sem rota.

## Detalhes
Adicionar em `Dependencies`, no mesmo padrão de `profileCubit()`:
```dart
/// Cubit da tela de saldo da carteira (já inicia a busca).
WalletCubit walletCubit() => WalletCubit(
  FetchWalletBalanceUseCase(
    WalletRepositoryImpl(WalletRemoteDataSourceImpl(_dio)),
  ),
);
```
- Factory: instância nova por chamada (cada abertura da tela busca o saldo de novo — AC-01).
- **Não** criar rota, item de menu nem alterar timeouts do Dio (fora de escopo).
- Uso esperado pelo chamador: `BlocProvider(create: (_) => deps.walletCubit(), child: const WalletPage())`.

## Pronto da tarefa
- [ ] `sdd check --task T07` verde
