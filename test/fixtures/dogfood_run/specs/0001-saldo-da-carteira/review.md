# Revisão · 0001-saldo-da-carteira

Ciclo 2. Base: `4cd9b70` → `HEAD` (`bbb9827`, ondas 0–4; delta desde o ciclo 1: `a5c3094...HEAD`, só a T08,
que mexeu em `wallet_remote_data_source_test.dart`). `sdd check --spec 0001-saldo-da-carteira --json`:
`ok: true` — format, analyze, test (58 testes), coverage (88.7%, mín. 80%), traceability (16 ACs) todos `pass`.

## Resultado
blockers: 0 · majors: 0 · minors: 5

## Achados
- [resolvido · era major no ciclo 1] test/features/wallet/data/datasources/wallet_remote_data_source_test.dart:8-39 —
  o `_MockDio` deu lugar a `Dio(BaseOptions(baseUrl: ...))` real com o `_FakeAdapter` (`HttpClientAdapter`), que
  responde com `ResponseBody.fromString` + `content-type: application/json`. Agora o teste exercita o
  `validateStatus` real (403 → `DioExceptionType.badResponse`, verificado em :73-74), a decodificação JSON do corpo
  (`{"code": "WLT_403"}` chega como `Map` e casa com o pattern da wallet_remote_data_source.dart:29), o corpo vazio
  de verdade (`''` → `FormatException`, :85-89) e o `GET /wallet/balance` (:52-54). Nenhuma mudança em `lib/` foi
  necessária, o que confirma que a decodificação já estava correta.
- [minor] test/features/wallet/data/datasources/wallet_remote_data_source_test.dart:42 — o teste
  "retorna o DTO do saldo via GET /wallet/balance" agora verifica método e path (parte "uma requisição
  `GET /wallet/balance` é feita" do AC-01), mas continua sem a tag `[AC-01]`; a rastreabilidade do AC-01
  vem só do cubit/página, que não comprovam o endpoint.
- [minor] lib/features/wallet/domain/failures/wallet_failure.dart:4 — `WalletFailure` não tem
  igualdade por valor, então `WalletError` (lib/features/wallet/presentation/cubit/wallet_state.dart:51)
  compara a failure por identidade. O plano diz "estados com igualdade por valor"; hoje só funciona
  com instâncias `const` canonicalizadas (ex.: o `expect` do teste AC-15 do cubit). `WalletError(WalletServerFailure('x'))`
  ≠ outra igual criada em runtime.
- [minor] test/features/wallet/presentation/pages/wallet_page_test.dart:1 — sem teste de widget para
  `WalletUnexpectedFailure` → "Algo deu errado. Tente de novo." (UI do AC-12) nem para AC-08/AC-10 na
  tela. O mapeamento está no `switch` exaustivo e o plano não listava esses ACs na página, mas o
  ramo `WalletUnexpectedFailure` da página não tem teste.
- [minor] test/features/wallet/presentation/cubit/wallet_cubit_test.dart:99 — `Completer` do AC-16
  declarado no escopo de `main`, compartilhado entre execuções; mover para dentro do `build`
  (variável `late` + `setUp`) para isolar o teste.
- [minor] lib/features/wallet/data/datasources/wallet_remote_data_source.dart:28 — `if` aninhados
  (`statusCode == 403` e `case {'code': 'WLT_403'}`) podem ser uma condição só (`if (e.response
  case Response(statusCode: 403, data: {'code': 'WLT_403'}))`).

### Conferência por AC
| AC | Implementação | Teste(s) |
|---|---|---|
| AC-01 | wallet_cubit.dart:14 (busca no construtor), wallet_page.dart:17, data_source.dart:25 | cubit_test `[AC-01]` ×2, page_test `[AC-01]`; data_source "via GET /wallet/balance" (sem tag) |
| AC-02..06 | brl_format.dart:4 | brl_format_test `[AC-02..06]`, page_test `[AC-02]` |
| AC-07 | data_source.dart:28, repository_impl.dart:32, wallet_page.dart:23 | data_source (adapter fake, 403 real) / repository / page `[AC-07]` |
| AC-08 | data_source.dart:33 (rethrow) → repository_impl.dart:38 | data_source `[AC-08]` ×2 (`badResponse` 403 real), repository `[AC-08]` |
| AC-09/10 | repository_impl.dart:17-21,35 | repository `[AC-09]`, `[AC-10]` ×3, page `[AC-09]` |
| AC-11 | repository_impl.dart:38 | repository `[AC-11]` ×3, page `[AC-11]` |
| AC-12 | wallet_balance_dto.dart:10 (pattern matching), repository_impl.dart:39-42 | dto `[AC-12]` ×4, data_source `[AC-12]` ×2 (corpo vazio e malformado via adapter), repository (reporte verificado) |
| AC-13 | repository_impl.dart:27 | repository `[AC-13]`, page `[AC-13]` |
| AC-14/15 | wallet_cubit.dart:23 | cubit `[AC-14]`, `[AC-15]`, page `[AC-14]`, `[AC-15]` |
| AC-16 | wallet_cubit.dart:24 (guard `WalletLoading`), wallet_page.dart:17 (sem botão) | cubit `[AC-16]`, page `[AC-16]` |

Código segue o plano (camadas, nomes, tabela de mapeamento do repository, decisões Q4/Q5/Q6/Q8/Q9/Q10),
e o teste do datasource agora segue o "Dio com adapter fake" da seção Testes do plano.
Domain não importa Flutter/Dio/data; cubit não importa `data/` e não tem `try/catch`; `Dependencies.walletCubit()`
conforme o plano (factory). `.sdd/memory/decisions.md` sem entradas; nada a contradizer.

## Checklist de DoD
- Nenhuma exception atravessa a fronteira do repository — ok: lib/features/wallet/data/repositories/wallet_repository_impl.dart:25-42
  (`on WalletBlockedException`, `on DioException`, `on Exception` final; `Error` não capturado).
  Teste: repository_impl_test "StateError do datasource propaga" e `[AC-12]`.
- Erros não mapeados continuam chegando ao Crashlytics — ok: wallet_repository_impl.dart:40
  (`FlutterError.reportError`); `Error` segue ao handler global; DTO usa pattern matching (wallet_balance_dto.dart:10)
  para não gerar `TypeError` engolido pelo estado de carregamento. Teste `[AC-12]` verifica `reported` com 1 item;
  datasource confirma, com Dio real, que corpo vazio/malformado vira `FormatException` (e não `TypeError`).
- Failures de negócio do backend estão mapeados para Failures da feature — ok: 403+`WLT_403` →
  `WalletBlockedException` (wallet_remote_data_source.dart:28-31, agora testado com resposta HTTP real) →
  `WalletBlockedFailure` (wallet_repository_impl.dart:32); moeda ≠ BRL → `WalletUnsupportedCurrencyFailure` (:27), não `Unexpected`.
- `sdd check --spec 0001-saldo-da-carteira --json` — verde (5/5 gates).

## Lições candidatas
- Datasource Dio testado com `HttpClientAdapter` fake, não com `Dio` mockado, para exercitar status/corpo reais → kit (skill `dio-datasource` + brick `datasource` com teste de adapter).
- Failures seladas com igualdade por valor (ou estados de erro comparando por tipo + message) → kit (brick `failure`).
- Teste de widget cobre todos os ramos do `switch` de Failure → mensagem, inclusive `Unexpected` → kit (skill `bloc-testing` / template de plan, seção Testes).
- Teste que comprova o endpoint chamado (método + path no adapter) leva a tag do AC de carregamento → projeto (rule `sdd-tests`).
- Fixtures assíncronas (`Completer`) criadas por teste, nunca no escopo de `main` → lint (regra customizada) ou kit (skill `bloc-testing`).
