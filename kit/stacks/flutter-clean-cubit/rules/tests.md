---
description: Testes - nome com a tag do AC, bloc_test e mocktail, caminho espelhado.
globs: ["{{sdd:project.test_path}}/**"]
---
- Teste que cobre um critério leva a tag no nome: `'[AC-02] ...'` (rastreabilidade do `sdd check`).
- Cubits com `blocTest`; dependências com `mocktail` (`class _MockX extends Mock implements X {}`).
- Caminho espelha o de produção; um arquivo de teste por arquivo de produção.
