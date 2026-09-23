# flutter_sdd

CLI `sdd` + kit de **Spec-Driven Development** para apps Flutter, gerando configuração
para Claude Code e Cursor. Em desenvolvimento: veja `docs/milestones.md`.

## Instalação

```sh
dart pub global activate --source git https://github.com/LucasTeixeiraDev/sddart_kit.git
```

Com um executável compilado (`dart compile exe bin/sdd.dart`), aponte para o kit com
`--kit-path <dir>` ou `SDD_KIT_PATH`.

## Comandos disponíveis

| Comando | Função |
|---|---|
| `sdd init [--stack <nome>] [--yes] [--force]` | Detecta o projeto e cria `.sdd/` |
| `sdd doctor` | Verifica ambiente, config, kit e `kit.lock` |

Flags globais: `--json`, `--verbose`, `--kit-path <dir>`, `--version`.
Exit codes: `0` ok, `1` falha de gate/validação, `2` erro de uso/config.
