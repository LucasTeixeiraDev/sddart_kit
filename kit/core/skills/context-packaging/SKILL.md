---
name: context-packaging
description: Como montar o contexto mínimo de uma tarefa (reads, exemplar, detalhes) para o implementer trabalhar sem explorar o repositório. Use ao escrever tarefas.
---
# Pacote de contexto da tarefa

O implementer lê **só** a tarefa, `reads`, `exemplar` e os `owns` existentes. Então:

- Coloque em `## Detalhes` o que ele não pode deduzir: assinaturas exatas do contrato,
  nomes de Failures, regras de negócio, valores e mensagens.
- Prefira citar o trecho relevante do `plan.md` a mandar ler o plano inteiro.
- Em `reads`, liste contratos, não implementações. Nunca liste diretórios.
- Escolha um único `exemplar`, o mais parecido possível (mesma camada e padrão).
- Se a tarefa precisar de mais de ~6 arquivos de contexto, ela está grande: divida.
