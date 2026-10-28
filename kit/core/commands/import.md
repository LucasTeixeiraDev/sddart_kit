---
description: Importa skills, rules, agentes e comandos preexistentes (Claude/Cursor) de um caminho para .sdd/overrides/ do projeto atual, com aprovação humana.
args: <caminho>
---
O argumento após o comando é o caminho de origem. A origem nunca é modificada.

1. Rode `sdd import scan <caminho> --json` (inventário determinístico com duplicatas).
2. Dispare `sdd-importer` em **modo classificar** com o JSON; mostre a tabela ao humano.
3. **Pare e aguarde aprovação** (item a item ou em bloco; o humano pode mudar a classe).
4. Dispare `sdd-importer` em **modo converter** só com os itens aprovados.
5. Rode `sdd sync` e mostre o resumo.
6. Se houver propostas para o kit, avise que estão em `.sdd/kit-proposals.md` para revisão
   manual no repositório do `flutter_sdd`.
