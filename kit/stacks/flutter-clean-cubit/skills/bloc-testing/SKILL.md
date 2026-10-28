---
name: bloc-testing
description: Testes com bloc_test e mocktail, nome de teste com a tag [AC-xx] para rastreabilidade. Use ao escrever ou revisar testes de cubits, usecases e repositories.
---
# Testes (bloc_test + mocktail)

- Confirme `bloc_test` e `mocktail` no `pubspec.yaml` antes de usar.
- **Todo teste que cobre um critério leva a tag no nome**: `'[AC-02] emite Error quando usuário bloqueado'`.
  O gate de rastreabilidade (`sdd check`) procura essas tags.
- Mocks: `class _MockLoginUseCase extends Mock implements LoginUseCase {}`; registre
  `registerFallbackValue` para tipos usados em `any()`.
- Cubit:
  ```dart
  blocTest<LoginCubit, LoginState>(
    '[AC-01] emite Loading e Success',
    build: () {
      when(() => useCase()).thenAnswer((_) async => const Ok(null));
      return LoginCubit(useCase);
    },
    act: (cubit) => cubit.login(),
    expect: () => [const LoginLoading(), const LoginSuccess()],
  );
  ```
  Para estados com dados, use `isA<LoginError>().having(...)`.
- Repository: mocke o datasource; um teste por exception mapeada (`Err` esperado) e um para
  a não mapeada (`Unexpected`).
- Usecase: verifique delegação (`verify(() => repository.x()).called(1)`) e o `Result`.
- very_good_analysis: strings com `$` literal (ex.: `R$`) precisam ser raw (`r'R$ 1,00'`);
  em `group`, prefira `for` a `forEach` para gerar testes.
- Um arquivo de teste por arquivo de produção, espelhando o caminho em
  `{{sdd:project.test_path}}/`.
