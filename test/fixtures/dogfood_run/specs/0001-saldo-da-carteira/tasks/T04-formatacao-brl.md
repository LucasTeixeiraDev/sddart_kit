---
id: T04
title: Formatação de centavos em reais (formatBrlCents)
wave: 1
depends_on: []
tier: standard
agent: implementer
owns:
  - lib/features/wallet/presentation/widgets/brl_format.dart
  - test/features/wallet/presentation/widgets/brl_format_test.dart
reads: []
acceptance: [AC-02, AC-03, AC-04, AC-05, AC-06]
---
## Objetivo
Criar a função pura que converte centavos (`int`) no texto em reais exibido na tela.

## Detalhes
Assinatura: `String formatBrlCents(int cents)` em `lib/features/wallet/presentation/widgets/brl_format.dart`
(função top-level com doc comment; sem imports).

Regras (plan.md · Presentation e Decisões):
- Prefixo `"R$ "` com **espaço comum U+0020** (não o não separável do `intl`).
- Sinal antes do prefixo: `-R$ 10,00`.
- Milhar com `.`, decimal com `,` e sempre 2 dígitos de centavos.
- Só aritmética de `int` (`abs()`, `~/`, `%`, `padLeft`): **sem `double` e sem `intl`**.

Testes (um por AC, com a tag no nome):
- `[AC-02]` 12345 → `R$ 123,45`
- `[AC-03]` 123456789 → `R$ 1.234.567,89`
- `[AC-04]` -1000 → `-R$ 10,00`
- `[AC-05]` 0 → `R$ 0,00`
- `[AC-06]` 5 → `R$ 0,05`
- extra: 100000 → `R$ 1.000,00`; -5 → `-R$ 0,05`.

## Pronto da tarefa
- [ ] `sdd check --task T04` verde
