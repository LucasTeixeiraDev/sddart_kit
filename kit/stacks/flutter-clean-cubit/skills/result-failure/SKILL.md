---
name: result-failure
description: Tratamento de erro funcional com Result (Ok/Err) e Failure selado por feature, mapeamento Exception → Failure na fronteira do repository, preservação do Crashlytics e caso SignalR. Use ao criar ou revisar repositories, usecases e cubits.
---
# Result e Failure

## Contrato
- `Result<T, E>` selado com `Ok(value)` e `Err(error)` (import em `scaffold.vars.result_import`).
- Cada feature tem `sealed class <Feature>Failure` em `domain/failures/`, com subclasses
  `final` (ex.: `<Feature>UnexpectedFailure`, `UserNotFoundFailure`). Subclasses ficam no
  mesmo arquivo (exigência de `sealed`).

## Fronteira: o repository
- Datasources podem lançar exceptions técnicas (Dio) e de negócio (ex.: `UserNotFoundException`).
- O `RepositoryImpl` captura **apenas `Exception`** e retorna `Result`. Nenhuma exception
  atravessa o repository.
  ```dart
  try {
    return Ok(await _dataSource.fetch());
  } on UserNotFoundException {
    return const Err(UserNotFoundFailure());   // negócio do backend → Failure da feature
  } on DioException catch (e) {
    return Err(AuthNetworkFailure(e.message));
  } on Exception catch (e, s) {
    // Não mapeada: não engolir. Chega ao FlutterError.onError (Crashlytics).
    FlutterError.reportError(FlutterErrorDetails(exception: e, stack: s));
    return Err(AuthUnexpectedFailure(e.toString()));
  }
  ```
- `Error` (bug: `TypeError`, `StateError`...) **nunca** é capturado: segue para o handler
  global (`FlutterError.onError` / `runZonedGuarded`) e chega ao Crashlytics.
- Erros de regra de negócio do backend viram Failures **específicos** da feature, nunca
  `Unexpected`.

## Usecase e cubit
- Usecase devolve o `Result` do repository (pode compor, nunca lança).
- Cubit faz `switch` exaustivo no `Result`/Failure e emite estados; nada de `try/catch` no cubit.

## Streams realtime (SignalR)
Decisão configurável, registrada em `.sdd/memory/decisions.md`: por padrão o stream emite
eventos de domínio e a **conexão** (falhas de transporte) é exposta como
`Stream<<Feature>ConnectionState>` separado; não force `Result` por evento.

## Testes
Para cada exception mapeada, um teste `[AC-xx]` verificando o `Err` correto; um teste para a
não mapeada verificando `Unexpected` e o reporte.
