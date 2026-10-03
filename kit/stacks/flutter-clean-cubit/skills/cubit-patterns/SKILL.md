---
name: cubit-patterns
description: Padrões de Cubit - estados selados, emissões, injeção de usecases e nenhuma lógica de negócio no widget. Use ao criar ou revisar cubits, states e pages.
---
# Padrões de Cubit

- Um cubit por tela/fluxo em `presentation/cubit/`, com estado em `<nome>_state.dart` (`part of`).
- Estado `sealed`: `<Nome>Initial`, `<Nome>Loading`, `<Nome>Success(...)`, `<Nome>Error(failure)`.
  Estados sem dados são `const` (igualdade por identidade nos testes).
- Recebe **usecases** no construtor (nunca repository nem datasource).
- Métodos públicos são intenções do usuário (`login()`, `refresh()`); retornam `Future<void>`.
- Emissão: `Loading` → resultado do usecase via `switch` exaustivo no `Result`.
- Nada de `try/catch` (o repository já devolve `Result`) e nada de `BuildContext` no cubit.
- Widget só lê estado (`BlocBuilder`/`BlocListener`) e chama métodos do cubit: nenhuma
  regra de negócio, formatação de domínio ou chamada de usecase no widget.
- Verifique `isClosed` antes de emitir após `await` longo, se o cubit puder ser fechado.
