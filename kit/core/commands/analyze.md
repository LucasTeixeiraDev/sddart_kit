---
description: Fase 1 do SDD - mapeia o código (explorer), escreve analysis.md com perguntas (analyst) e para para o humano responder e aprovar.
args: <spec>
---
O argumento após o comando é o id da spec (ex.: `0042-login-biometria`, `0042` ou `42`).

1. `sdd status <spec> --json`. Se `analysis.md` já tem respostas e o humano pede aprovação,
   vá ao passo 5.
2. `sdd status set <spec> phase analyze`
3. Dispare `sdd-explorer` com `specs/<spec>/`. Guarde só o retorno compacto.
4. Dispare `sdd-analyst` com o caminho da spec e o retorno do explorer.
5. Mostre ao humano: resumo de 3 linhas, perguntas `Q1..Qn` sem resposta e riscos. **Pare.**
6. Quando o humano responder, registre as respostas em `analysis.md` (abaixo de cada
   pergunta). Com tudo respondido e aprovação explícita:
   `sdd status set <spec> gate analysis_approved`.

Nunca aprove o gate sem confirmação explícita do humano.
