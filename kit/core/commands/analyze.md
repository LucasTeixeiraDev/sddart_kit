---
description: Analisa o PRD de uma spec (explorer → analyst) e para com perguntas para o humano.
args: <spec>
---
O argumento após o comando é o id da spec (ex.: `0042-login-biometria`).

1. `sdd status set <spec> phase analyze`
2. Dispare `sdd-explorer` com o caminho `specs/<spec>/`.
3. Dispare `sdd-analyst` com o retorno do explorer.
4. Mostre ao humano as perguntas de `analysis.md` e **pare**.

Após as respostas estarem registradas em `analysis.md`, o humano aprova com
`sdd status set <spec> gate analysis_approved`.
