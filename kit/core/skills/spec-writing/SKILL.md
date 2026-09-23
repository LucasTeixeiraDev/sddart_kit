---
name: spec-writing
description: Como escrever spec.md - requisitos, critérios de aceite AC-xx testáveis em Given/When/Then e fora de escopo explícito. Use ao criar ou revisar uma spec.
---
# Escrita de spec

## Estrutura de `spec.md`
1. **Contexto** (3 a 5 linhas): problema e resultado esperado.
2. **Requisitos**: `R1`, `R2`... frases no imperativo, uma por comportamento.
3. **Critérios de aceite**: `AC-01`, `AC-02`... (dois dígitos ou mais), cada um:
   ```
   AC-01 · <título curto>
   Given <estado inicial>
   When <ação>
   Then <resultado observável>
   ```
4. **Fora de escopo**: lista explícita do que não será feito.
5. **Questões abertas**: deve estar vazia quando a spec for aprovada.

## Regras
- Cada AC é testável por um teste automatizado; o nome do teste terá `[AC-xx]`.
- Um AC por comportamento; erros e casos de borda também são ACs.
- Não descreva implementação (classes, pacotes) na spec; isso vai no `plan.md`.
- IDs de AC nunca são renumerados depois de aprovados; novos ACs recebem o próximo número.
