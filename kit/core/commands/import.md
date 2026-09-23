---
description: Importa skills, rules e agentes preexistentes (Claude/Cursor) de um caminho para .sdd/overrides/ do projeto atual.
args: <caminho>
---
O argumento após o comando é o caminho de origem. A origem nunca é modificada.

1. `sdd import scan <caminho> --json` (inventário determinístico).
2. Classifique cada item: **override do projeto** (padrão), **candidato ao kit**,
   **já coberto pelo kit** ou **descartar**, com motivo. Apresente a tabela.
3. **Aguarde aprovação humana** (item a item ou em bloco).
4. Converta os aprovados para o formato canônico em `.sdd/overrides/`, deduplicando versões
   Claude/Cursor do mesmo conteúdo; rode `sdd sync`.
5. Candidatos ao kit não vão para o kit: registre-os em `.sdd/kit-proposals.md`.
