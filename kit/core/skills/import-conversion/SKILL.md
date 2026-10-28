---
name: import-conversion
description: Formato canônico do kit sdd (agentes, skills, rules, comandos) e como converter arquivos de Claude Code e Cursor para ele. Use ao importar ou escrever overrides.
---
# Formatos canônicos (`.sdd/overrides/`)

## Agente: `agents/<nome>.md`
```yaml
description: <quando usar; específico>
tier: deep | standard | fast          # nunca nome de modelo
tools: [read, search, edit, write, bash]
readonly: false
skills: [<nome canônico>]              # opcional
bash_allow: ["sdd check"]              # opcional: restringe Bash (Claude)
```
Para só acrescentar skills/texto a um agente do kit: `extend: true` + `skills` + corpo.

| Origem | Canônico |
|---|---|
| Claude `model: opus` / Cursor `claude-opus-*` | `tier: deep` |
| `sonnet` / `claude-sonnet-*` | `tier: standard` |
| `haiku` / modelos rápidos | `tier: fast` |
| Claude `tools: Read, Grep, Glob` | `[read, search]` (`Edit`→edit, `Write`→write, `Bash`→bash) |
| Cursor `readonly: true` | `readonly: true` e sem edit/write |

## Skill: `skills/<nome>/SKILL.md` (+ arquivos de apoio)
Frontmatter `description` (obrigatório). Copie os arquivos de apoio junto.

## Rule: `rules/<nome>.md`
```yaml
description: <resumo>
globs: ["lib/**/domain/**"]            # lista; Cursor usa string separada por vírgula
always: false                           # Cursor alwaysApply
```
Claude `paths:` → `globs`. Rule sem globs e não `always` vira skill (é "aplicar quando relevante").

## Comando: `commands/<nome>.md`
```yaml
description: <o que faz>
args: <spec>                            # opcional
```
Troque `$ARGUMENTS`/`$1` por texto neutro ("o argumento após o comando é ...").

## Regras gerais
- Nomes: `a-z`, `0-9`, `-`; sem prefixo `sdd-` (é aplicado na geração).
- Remova referências a modelos, caminhos absolutos e segredos.
- Corpo curto: o que fazer, o que ler, o que produzir, o que é proibido.
