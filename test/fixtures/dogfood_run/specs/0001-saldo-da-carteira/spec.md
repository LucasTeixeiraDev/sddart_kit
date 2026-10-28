# Spec · 0001-saldo-da-carteira

## Contexto
Hoje o cliente só vê o saldo da carteira abrindo o extrato no site. Esta spec cria uma tela no
app que mostra o saldo atual (`GET /wallet/balance`) em reais. O saldo é carregado ao abrir a
tela e pode ser atualizado com um botão "Atualizar". Carteira bloqueada, falta de conexão e
demais erros têm mensagens próprias. O ponto de entrada da tela (rota, menu) fica para outra spec.

## Requisitos
- R1 · Buscar o saldo automaticamente quando a tela é aberta, mostrando um indicador de carregamento enquanto a busca não termina.
- R2 · Exibir o saldo em reais a partir do valor em centavos: prefixo "R$ ", ponto como separador de milhar, vírgula e dois dígitos para os centavos; negativo como "-R$ 10,00".
- R3 · Oferecer o botão "Atualizar" com o saldo exibido e em qualquer estado de erro; ao tocar, voltar ao estado de carregamento e buscar o saldo de novo.
- R4 · Não iniciar uma nova busca enquanto outra estiver em andamento.
- R5 · Quando o backend responder HTTP 403 com `code` igual a `WLT_403`, mostrar "Carteira bloqueada. Fale com o suporte.", sem outra ação além de "Atualizar".
- R6 · Quando não houver conexão ou a requisição exceder o tempo limite, mostrar "Sem conexão. Tente de novo.".
- R7 · Em qualquer outro erro (HTTP 401, 5xx, 403 sem `WLT_403`, resposta malformada ou moeda diferente de BRL), mostrar "Algo deu errado. Tente de novo." sem exibir valor.
- R8 · Registrar para diagnóstico (Crashlytics) as falhas inesperadas, como resposta malformada.

## Critérios de aceite
AC-01 · Carregamento automático ao abrir
Given a API de saldo ainda não respondeu
When a tela de saldo é aberta
Then o indicador de carregamento é exibido e uma requisição `GET /wallet/balance` é feita

AC-02 · Saldo exibido em reais
Given a API responde `{"amount_cents": 12345, "currency": "BRL"}`
When a tela de saldo termina de carregar
Then o texto "R$ 123,45" é exibido

AC-03 · Separador de milhar
Given a API responde `{"amount_cents": 123456789, "currency": "BRL"}`
When a tela de saldo termina de carregar
Then o texto "R$ 1.234.567,89" é exibido

AC-04 · Saldo negativo
Given a API responde `{"amount_cents": -1000, "currency": "BRL"}`
When a tela de saldo termina de carregar
Then o texto "-R$ 10,00" é exibido

AC-05 · Saldo zero
Given a API responde `{"amount_cents": 0, "currency": "BRL"}`
When a tela de saldo termina de carregar
Then o texto "R$ 0,00" é exibido

AC-06 · Saldo menor que um real
Given a API responde `{"amount_cents": 5, "currency": "BRL"}`
When a tela de saldo termina de carregar
Then o texto "R$ 0,05" é exibido

AC-07 · Carteira bloqueada
Given a API responde HTTP 403 com `{"code": "WLT_403"}`
When a tela de saldo termina de carregar
Then o texto "Carteira bloqueada. Fale com o suporte." e o botão "Atualizar" são exibidos, e nenhum valor de saldo é exibido

AC-08 · 403 sem código de bloqueio
Given a API responde HTTP 403 sem `code` igual a `WLT_403`
When a tela de saldo termina de carregar
Then o texto "Algo deu errado. Tente de novo." é exibido

AC-09 · Sem conexão
Given o dispositivo não consegue conectar ao servidor
When a tela de saldo termina de carregar
Then o texto "Sem conexão. Tente de novo." e o botão "Atualizar" são exibidos

AC-10 · Tempo limite excedido
Given a requisição de saldo excede o tempo limite de conexão, envio ou recebimento
When a tela de saldo termina de carregar
Then o texto "Sem conexão. Tente de novo." é exibido

AC-11 · Erro HTTP do servidor ou sessão
Given a API responde HTTP 500 (ou HTTP 401)
When a tela de saldo termina de carregar
Then o texto "Algo deu errado. Tente de novo." e o botão "Atualizar" são exibidos

AC-12 · Resposta malformada
Given a API responde 200 com corpo sem `amount_cents` inteiro (ex.: `{"amount_cents": "12,34", "currency": "BRL"}` ou corpo vazio)
When a tela de saldo termina de carregar
Then o texto "Algo deu errado. Tente de novo." é exibido e o erro é registrado para diagnóstico

AC-13 · Moeda não suportada
Given a API responde `{"amount_cents": 12345, "currency": "USD"}`
When a tela de saldo termina de carregar
Then o texto "Algo deu errado. Tente de novo." é exibido e nenhum valor de saldo é exibido

AC-14 · Atualizar com saldo exibido
Given a tela exibe "R$ 123,45" e a API passa a responder `{"amount_cents": 20000, "currency": "BRL"}`
When o usuário toca em "Atualizar"
Then o indicador de carregamento é exibido no lugar do saldo e, ao terminar, o texto "R$ 200,00" é exibido

AC-15 · Atualizar a partir de um erro
Given a tela exibe "Carteira bloqueada. Fale com o suporte." (ou outra mensagem de erro) e a API passa a responder `{"amount_cents": 12345, "currency": "BRL"}`
When o usuário toca em "Atualizar"
Then o texto "R$ 123,45" é exibido

AC-16 · Sem busca simultânea
Given uma busca de saldo está em andamento
When uma nova atualização é solicitada
Then nenhuma requisição adicional é feita e o botão "Atualizar" não é exibido enquanto a busca não termina

## Fora de escopo
- Navegação até a tela (rota, item de menu, deep link, botão em outra tela).
- Extrato, recarga e transferências.
- Múltiplas moedas e conversão de câmbio.
- Pull-to-refresh, atualização automática, periódica ou em tempo real (push/websocket).
- Guardar o último saldo para uso offline ou manter o saldo anterior visível durante a atualização.
- Tratamento de sessão expirada (redirecionar ao login no HTTP 401).
- Ação de contato com o suporte no estado de carteira bloqueada.
- Ocultar/mostrar o saldo (modo privacidade).

## Questões abertas
