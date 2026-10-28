# Análise · 0001-saldo-da-carteira

## Resumo
Nova tela que mostra o saldo atual da carteira (`GET /wallet/balance`), formatado em reais ("R$ 123,45"), com atualização manual. Dois erros têm mensagem definida: carteira bloqueada (HTTP 403 + `WLT_403`) e sem conexão. Outros cenários não estão especificados: outros erros, carregamento e como o usuário chega à tela.

## Features impactadas
- `wallet` (nova).
- Contratos existentes reutilizados: `lib/core/result/result.dart` (`Result<T, E>`) e `lib/core/di/dependencies.dart` (registro de dependências).
- `profile` serve só de referência de padrão e não é alterada.

## Ambiguidades
- O ponto de entrada da tela não está definido (menu, rota, deep link ou botão em outra tela).
- "Atualização manual" não diz qual é o gesto (pull-to-refresh, botão ou ambos) nem se o saldo anterior continua visível durante a atualização.
- Só dois erros têm mensagem. Não há texto para 401, 5xx, timeout, 403 sem `WLT_403` ou resposta malformada.
- Não está dito se o saldo é carregado automaticamente ao abrir a tela.
- Não há exemplos de saldo negativo, zero ou valores grandes (separador de milhar).
- `currency` vem na resposta, mas o PRD só fala em BRL. Não está definido o que acontece se vier outra moeda.
- Não está dito se o estado "carteira bloqueada" oferece alguma ação (contato com o suporte) ou só texto, nem se a nova tentativa continua disponível nesse estado.

## Perguntas
Q1 · Por onde o usuário chega à tela de saldo (rota, item de menu, botão em outra tela)? — impacto: sem isso a tela fica inacessível ou o ponto de navegação é escolhido sem aval.
Resposta: navegação fica fora desta spec. A tela é exposta via `Dependencies.walletCubit()` + `WalletPage`; o ponto de entrada vem em outra spec.

Q2 · A atualização manual é por pull-to-refresh, por botão ou pelos dois? — impacto: define a interação e os testes de widget; se a escolha estiver errada, a UI precisa ser refeita.
Resposta: botão "Atualizar".

Q3 · Durante a atualização, o saldo anterior continua visível (com indicador) ou a tela volta ao estado de carregamento? — impacto: muda os estados da tela e a experiência depois de uma recarga.
Resposta: volta ao estado de carregamento (mais simples).

Q4 · O saldo é buscado automaticamente ao abrir a tela? — impacto: sem resposta, a tela pode abrir vazia ou fazer uma chamada indesejada.
Resposta: sim, ao criar o cubit da tela.

Q5 · Qual mensagem mostrar para erros não listados (5xx, timeout, resposta inválida, 403 sem `WLT_403`)? — impacto: um texto genérico é inventado ou um erro técnico aparece para o usuário.
Resposta: "Algo deu errado. Tente de novo." (timeout: ver Q10).

Q6 · HTTP 401 (sessão expirada) deve levar ao login ou cair no erro genérico? — impacto: pode ficar inconsistente com o resto do app.
Resposta: erro genérico; sessão está fora de escopo.

Q7 · No estado "Carteira bloqueada", o usuário ainda pode tentar atualizar? Há alguma ação de contato com o suporte? — impacto: a UI e o fluxo do estado bloqueado ficam indefinidos.
Resposta: pode atualizar; sem ação de suporte, só o texto.

Q8 · O que fazer se `currency` vier diferente de "BRL"? — impacto: o valor pode aparecer errado (dólares formatados como reais) ou dar uma falha não tratada.
Resposta: tratar como erro genérico (moeda não suportada), sem exibir valor.

Q9 · Como exibir saldo negativo e valores acima de R$ 999,99 (ex.: "R$ 1.234,56", "-R$ 10,00")? — impacto: a formatação pode divergir da que o produto espera.
Resposta: "R$ 1.234,56" e "-R$ 10,00". Formatar a partir dos centavos (int), sem double e sem dependência nova.

Q10 · A mensagem "Sem conexão" vale só para falta de rede ou também para timeout? — impacto: os erros são classificados de outro jeito e os textos ficam trocados.
Resposta: também para timeout.

## Riscos
- R1 · Mapeamento do 403: se depender só do status HTTP, qualquer outro 403 vira "Carteira bloqueada". Se depender só do `code`, o corpo das respostas de erro precisa ser lido.
- R2 · Formatação BRL: depende do locale `pt_BR`. Com outro locale no dispositivo, ou com conversão em ponto flutuante, o valor ou os separadores podem sair errados.
- R3 · Refresh manual: toques repetidos podem disparar requisições simultâneas, e a resposta mais antiga pode ser a última exibida.
- R4 · Cache/sessão: se a tela ficar em memória entre navegações, o saldo pode ficar desatualizado. Isso afeta a história "acabei de fazer uma recarga".

## Fora de escopo sugerido
- Extrato, recarga, transferências e múltiplas moedas (já estão no PRD).
- Atualização automática, periódica ou em tempo real (push/websocket).
- Guardar o último saldo para uso offline.
- Ocultar/mostrar o saldo (modo privacidade).
- Navegação até a tela (Q1).
