# Spec · 0001-login-biometria

## Critérios de aceite
AC-01 · Login com digital
Given usuário com biometria cadastrada
When toca no sensor
Then entra no app

AC-02 · Usuário bloqueado
Given usuário bloqueado no backend
When tenta logar
Then vê a mensagem de bloqueio

AC-03 · Sem biometria
Given aparelho sem biometria
When abre o login
Then o botão de biometria não aparece
