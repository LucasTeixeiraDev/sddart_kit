---
name: api-errors
description: Códigos de erro da API interna e como mapeá-los para Failures.
---
O backend responde erros com o campo code.
USR_404 vira UserNotFoundFailure.
USR_423 vira BlockedUserFailure.
Qualquer outro código vira UnexpectedFailure.
