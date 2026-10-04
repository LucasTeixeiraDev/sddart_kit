# PRD · Saldo da carteira

## Problema
O usuário não consegue ver quanto tem na carteira do app sem abrir o extrato no site.

## Objetivo
Mostrar o saldo atual da carteira numa tela própria, com atualização manual.

## Histórias
- Como cliente, quero ver meu saldo da carteira para decidir se compro algo.
- Como cliente, quero atualizar o saldo quando acabei de fazer uma recarga.

## Regras de negócio
- API: `GET /wallet/balance` responde `{"amount_cents": 12345, "currency": "BRL"}`.
- Valor exibido em reais, ex.: "R$ 123,45".
- Se a carteira estiver bloqueada, o backend responde HTTP 403 com `{"code": "WLT_403"}`;
  o app mostra "Carteira bloqueada. Fale com o suporte.".
- Sem conexão: "Sem conexão. Tente de novo.".

## Fora de escopo
Extrato, recarga, transferências, múltiplas moedas.

## Referências
A feature `profile` já segue o padrão de camadas do app.
