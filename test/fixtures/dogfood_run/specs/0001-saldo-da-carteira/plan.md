# Plano · 0001-saldo-da-carteira

## Visão geral
Nova feature `lib/features/wallet/`, no mesmo padrão da `profile`:
`WalletCubit → FetchWalletBalanceUseCase → WalletRepository → WalletRepositoryImpl → WalletRemoteDataSource (Dio)`.
Erros com `Result<T, E>` (`package:loja_app/core/result/result.dart`) e `sealed class WalletFailure`.
Nenhuma dependência nova: a formatação BRL é feita à mão a partir dos centavos (`int`), sem
`double` e sem `intl` (Q9). A tela é exposta por `Dependencies.walletCubit()` + `WalletPage`, sem
rota (Q1).

Bricks aplicáveis (`sdd scaffold <brick> --vars feature=wallet name=<n>`):
`feature` (wallet), `failure` (wallet), `usecase` (fetch_wallet_balance), `repository` (wallet),
`datasource` (wallet_remote), `cubit` (wallet).

## Domain
`lib/features/wallet/domain/`

- `entities/wallet_balance.dart`
  ```dart
  final class WalletBalance {
    const WalletBalance({required this.amountCents}); // sempre BRL
    final int amountCents;
  }
  ```
  Igualdade por valor (`==`/`hashCode`) para facilitar `bloc_test`.
- `repositories/wallet_repository.dart`
  ```dart
  abstract interface class WalletRepository {
    /// Busca o saldo atual. Nunca lança.
    Future<Result<WalletBalance, WalletFailure>> fetchBalance();
  }
  ```
- `usecases/fetch_wallet_balance_use_case.dart`
  ```dart
  class FetchWalletBalanceUseCase {
    const FetchWalletBalanceUseCase(this._repository);
    final WalletRepository _repository;
    Future<Result<WalletBalance, WalletFailure>> call() => _repository.fetchBalance();
  }
  ```
- `failures/wallet_failure.dart` (todas as subclasses no mesmo arquivo)
  ```dart
  sealed class WalletFailure { const WalletFailure([this.message]); final String? message; }
  final class WalletBlockedFailure extends WalletFailure {}              // 403 + WLT_403 (negócio)
  final class WalletNetworkFailure extends WalletFailure {}              // sem conexão / timeout
  final class WalletUnsupportedCurrencyFailure extends WalletFailure {}  // currency != "BRL" (message = moeda recebida)
  final class WalletServerFailure extends WalletFailure {}               // demais respostas HTTP / erros Dio
  final class WalletUnexpectedFailure extends WalletFailure {}           // Exception não mapeada (reportada)
  ```
  (todas com construtor `const ...([super.message])`).

## Data
`lib/features/wallet/data/`

- `models/wallet_balance_dto.dart`
  ```dart
  class WalletBalanceDto {
    const WalletBalanceDto({required this.amountCents, required this.currency});
    /// Lança FormatException (Exception, não Error) se o corpo não for
    /// {"amount_cents": int, "currency": String}, inclusive corpo nulo.
    factory WalletBalanceDto.fromJson(Object? json);
    final int amountCents;
    final String currency;
    WalletBalance toEntity() => WalletBalance(amountCents: amountCents);
  }
  ```
  `fromJson` usa pattern matching (`if (json case {'amount_cents': final int a, 'currency': final String c})`)
  em vez de `as`, para que corpo malformado não vire `TypeError` (que escaparia do repository e
  deixaria a tela presa no carregamento).
- `datasources/wallet_remote_data_source.dart`
  ```dart
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
  Implementação: `_dio.get<Object?>('/wallet/balance')` → `WalletBalanceDto.fromJson(response.data)`
  (sem `!`). No `on DioException catch (e)`: se `e.response?.statusCode == 403` **e**
  `e.response?.data case {'code': 'WLT_403'}` → `throw WalletBlockedException()`; senão `rethrow`.
- `repositories/wallet_repository_impl.dart` — fronteira de erro, captura só `Exception`:

  | Origem | Condição | Result |
  |---|---|---|
  | datasource | `WalletBlockedException` | `Err(WalletBlockedFailure())` |
  | Dio | `DioException` com `type` em `connectionError`, `connectionTimeout`, `sendTimeout`, `receiveTimeout` | `Err(WalletNetworkFailure(e.message))` |
  | Dio | demais `DioException` (`badResponse` — 401, 5xx, 403 sem `WLT_403` —, `cancel`, `badCertificate`, `unknown`) | `Err(WalletServerFailure(e.message))` |
  | DTO ok | `dto.currency != 'BRL'` | `Err(WalletUnsupportedCurrencyFailure(dto.currency))` |
  | qualquer outra `Exception` (inclui `FormatException` do DTO) | — | `FlutterError.reportError(...)` + `Err(WalletUnexpectedFailure(e.toString()))` |
  | `Error` (`TypeError`, `StateError`...) | — | não capturado; segue ao handler global (Crashlytics) |

  A checagem de moeda fica no repository (não no DTO) porque é regra de negócio, não de formato.

## Presentation
`lib/features/wallet/presentation/`

- `cubit/wallet_state.dart` (`part of 'wallet_cubit.dart'`)
  ```dart
  sealed class WalletState { const WalletState(); }
  final class WalletLoading extends WalletState {}
  final class WalletLoaded extends WalletState { final WalletBalance balance; }
  final class WalletError extends WalletState { final WalletFailure failure; }
  ```
  Sem estado `Initial`: a busca começa na criação do cubit (Q4). Estados com igualdade por valor.
- `cubit/wallet_cubit.dart`
  ```dart
  class WalletCubit extends Cubit<WalletState> {
    /// Começa em WalletLoading e já dispara a busca (Q4).
    WalletCubit(this._fetchBalance) : super(const WalletLoading()) { _load(); }
    final FetchWalletBalanceUseCase _fetchBalance;

    /// Botão "Atualizar". Ignorado se o estado atual for WalletLoading (R4/AC-16).
    Future<void> refresh();   // emit(WalletLoading()) e _load()

    Future<void> _load();     // await usecase; if (isClosed) return; switch exaustivo Ok/Err
  }
  ```
  Sem `try/catch` no cubit. O guard `state is WalletLoading` cobre a concorrência (R3 da análise):
  como cada busca começa emitindo `WalletLoading`, nunca há duas em andamento.
- `pages/wallet_page.dart` — `WalletPage` (`StatelessWidget`) com `BlocBuilder<WalletCubit, WalletState>`
  e `switch` exaustivo:
  - `WalletLoading` → `CircularProgressIndicator`, sem botão.
  - `WalletLoaded` → texto `formatBrlCents(balance.amountCents)` + botão "Atualizar".
  - `WalletError` → mensagem + botão "Atualizar":
    - `WalletBlockedFailure` → "Carteira bloqueada. Fale com o suporte."
    - `WalletNetworkFailure` → "Sem conexão. Tente de novo."
    - `WalletUnsupportedCurrencyFailure`, `WalletServerFailure`, `WalletUnexpectedFailure` → "Algo deu errado. Tente de novo."
  Botão chama `context.read<WalletCubit>().refresh()`. A página não cria o cubit; quem a usa
  fornece um `BlocProvider(create: (_) => deps.walletCubit())`.
- `widgets/brl_format.dart` — função pura `String formatBrlCents(int cents)`:
  sinal à frente do prefixo (`-R$ 10,00`), espaço comum (U+0020) após "R$", milhar com ".",
  centavos com 2 dígitos. Usa `abs()` sobre `int` (sem `double`, sem `intl`).

## Integração
- `lib/core/di/dependencies.dart`: novo método
  ```dart
  /// Cubit da tela de saldo da carteira (já inicia a busca).
  WalletCubit walletCubit() => WalletCubit(
    FetchWalletBalanceUseCase(
      WalletRepositoryImpl(WalletRemoteDataSourceImpl(_dio)),
    ),
  );
  ```
  Uma instância nova por chamada (factory): cada abertura da tela busca o saldo de novo, o que
  evita saldo desatualizado entre navegações (R4 da análise).
- Rotas: nenhuma (fora de escopo, Q1).
- Timeouts: usa os do `Dio` injetado; esta spec não os altera.

## Testes (rastreabilidade)
Espelhando `test/features/wallet/...`, nomes com `[AC-xx]`:
- `formatBrlCents`: AC-02, AC-03, AC-04, AC-05, AC-06.
- `WalletRemoteDataSourceImpl` (Dio com adapter fake): AC-07 (403+WLT_403 → `WalletBlockedException`), AC-08 (403 sem código → rethrow), AC-12 (corpo malformado/nulo → `FormatException`).
- `WalletRepositoryImpl`: AC-07, AC-08, AC-09, AC-10 (um teste por tipo de timeout), AC-11, AC-12 (Unexpected + `FlutterError.reportError` chamado), AC-13.
- `WalletCubit` (`bloc_test`): AC-01 (estado inicial `WalletLoading` + usecase chamado na criação), AC-14, AC-15, AC-16 (`refresh` durante `WalletLoading` não chama o usecase de novo).
- `WalletPage` (widget): AC-01, AC-02, AC-07, AC-09, AC-11, AC-13, AC-14, AC-15, AC-16 (sem botão no carregamento).

## Decisões
- **Bloqueio exige status 403 e `code` `WLT_403`** (risco R1 da análise). Alternativas: só status
  (qualquer 403 viraria "bloqueada") ou só `code`. Motivo: Q5 manda 403 sem `WLT_403` para o genérico.
- **Timeout = sem conexão** (Q10): `connectionTimeout`, `sendTimeout` e `receiveTimeout` → `WalletNetworkFailure`.
  `DioExceptionType.unknown` vai para `WalletServerFailure` (genérico), não para "Sem conexão".
- **401 e 5xx → `WalletServerFailure`** (Q6): não reportados ao Crashlytics, pois são respostas
  esperadas do servidor, não bugs.
- **Moeda ≠ BRL → `WalletUnsupportedCurrencyFailure`** (Q8): Failure específica (não `Unexpected`)
  e **não reportada** ao Crashlytics; a UI mostra o texto genérico. Alternativa: tratar como
  `Unexpected` e reportar, o que daria visibilidade a uma mudança de contrato no backend.
- **Resposta malformada → `FormatException` → `WalletUnexpectedFailure` reportada** (Q5/R8): o DTO
  valida com pattern matching para não gerar `TypeError`, que pela regra do kit não é capturado
  e deixaria a tela em carregamento.
- **Formatação manual em `presentation/widgets/brl_format.dart`** (Q9, risco R2): não depende de
  locale do dispositivo nem de `intl`. Usa espaço comum após "R$" (o `intl` usaria espaço
  não separável), para bater literalmente com "R$ 123,45" do PRD.
- **Busca disparada no construtor do cubit** (Q4), com estado inicial `WalletLoading` e sem
  `Initial`. Alternativa: `Dependencies` chamar `..load()`; descartada para que o comportamento
  seja testável no próprio cubit.
- **Atualizar volta ao carregamento e é ignorado durante uma busca** (Q2, Q3, risco R3).
- `.sdd/memory/decisions.md` não tem entradas; nada a contradizer. Nenhuma decisão desta spec é
  transversal o bastante para virar `D-NNN` agora.

### Decisões que pedem aprovação humana
1. Moeda ≠ BRL não reportada ao Crashlytics (vs. reportar como `Unexpected`).
2. `DioExceptionType.unknown` como erro genérico, não "Sem conexão".
3. Espaço comum (U+0020) em "R$ 123,45", em vez do espaço não separável do `intl`.
4. Busca no construtor do `WalletCubit` (estado inicial `WalletLoading`).
