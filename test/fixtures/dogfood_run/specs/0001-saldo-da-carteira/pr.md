# Saldo da carteira (0001)

## Resumo
Nova feature `wallet`: tela com o saldo da carteira (`GET /wallet/balance`) em reais, botão
Atualizar e mensagens para carteira bloqueada (403 `WLT_403`), sem conexão e erro genérico.
Exposta via `Dependencies.walletCubit()` + `WalletPage` (navegação fica para outra spec).

## ACs cobertos
AC-01 a AC-16, todos com testes marcados `[AC-xx]` (58 testes; cobertura 88,7% em domain e
cubits). Mapa AC → teste em `review.md`.

## Decisões
- Formatação BRL a partir de centavos `int`, sem dependência nova (`formatBrlCents`).
- Moeda ≠ BRL → `WalletUnsupportedCurrencyFailure` (não reportada ao Crashlytics).
- `DioExceptionType.unknown` → erro genérico; timeouts → "Sem conexão".
- Busca no construtor do cubit; `refresh()` ignorado durante o carregamento.

## Minors conhecidos
Ver `review.md` (ciclo 2): igualdade de `WalletFailure`, testes de widget para AC-08/10/12,
tag `[AC-01]` no teste do endpoint, `Completer` no escopo de `main`.

## Como testar
`flutter test test/features/wallet` · `sdd check --spec 0001`
