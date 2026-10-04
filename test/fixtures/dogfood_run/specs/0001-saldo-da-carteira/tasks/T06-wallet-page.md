---
id: T06
title: WalletPage (carregamento, saldo, mensagens de erro e botão Atualizar)
wave: 2
depends_on: [T03, T04]
tier: standard
agent: implementer
owns:
  - lib/features/wallet/presentation/pages/wallet_page.dart
  - test/features/wallet/presentation/pages/wallet_page_test.dart
reads:
  - lib/features/wallet/domain/failures/wallet_failure.dart
  - lib/features/wallet/presentation/cubit/wallet_state.dart
  - lib/features/wallet/presentation/cubit/wallet_cubit.dart
  - lib/features/wallet/presentation/widgets/brl_format.dart
exemplar: lib/features/profile/presentation/pages/profile_page.dart
acceptance: [AC-01, AC-02, AC-07, AC-09, AC-11, AC-13, AC-14, AC-15, AC-16]
---
## Objetivo
Criar a tela de saldo, que só lê o `WalletCubit` e chama `refresh()`.

## Detalhes
Leia a skill `sdd-cubit-patterns` (seção de UI/BlocBuilder). `WalletPage` é `StatelessWidget` com
`const WalletPage({super.key})`; **não cria o cubit** (quem usa fornece `BlocProvider`).

`BlocBuilder<WalletCubit, WalletState>` com `switch` exaustivo:
- `WalletLoading` → `CircularProgressIndicator`, **sem** botão "Atualizar" (AC-16).
- `WalletLoaded` → `Text(formatBrlCents(balance.amountCents))` + botão "Atualizar".
- `WalletError` → mensagem + botão "Atualizar", com `switch` exaustivo sobre a failure:
  - `WalletBlockedFailure` → `Carteira bloqueada. Fale com o suporte.`
  - `WalletNetworkFailure` → `Sem conexão. Tente de novo.`
  - `WalletUnsupportedCurrencyFailure`, `WalletServerFailure`, `WalletUnexpectedFailure` → `Algo deu errado. Tente de novo.`
- Botão: `context.read<WalletCubit>().refresh()`. Nenhum valor de saldo em estado de erro.

Teste de widget com `MockCubit<WalletState>` (`bloc_test`) + `whenListen`/`when(() => cubit.state)`
(tags no nome):
- `[AC-01]` `WalletLoading` → indicador, sem botão. `[AC-16]` mesmo cenário: sem botão "Atualizar".
- `[AC-02]` `WalletLoaded(12345)` → `R$ 123,45` e botão.
- `[AC-07]` `WalletError(WalletBlockedFailure())` → texto de bloqueio + botão, sem `R$`.
- `[AC-09]` `WalletNetworkFailure` → `Sem conexão. Tente de novo.` + botão.
- `[AC-11]` `WalletServerFailure` → `Algo deu errado. Tente de novo.` + botão.
- `[AC-13]` `WalletUnsupportedCurrencyFailure('USD')` → texto genérico, sem `R$`.
- `[AC-14]` com `WalletLoaded`, tocar "Atualizar" chama `refresh()`; sequência Loading → `R$ 200,00` renderizada.
- `[AC-15]` com erro, tocar "Atualizar" chama `refresh()`; após `WalletLoaded(12345)` mostra `R$ 123,45`.

## Pronto da tarefa
- [ ] `sdd check --task T06` verde
