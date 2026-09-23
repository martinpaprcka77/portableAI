# Gisty

Znovupoužitelné snippety, one-linery a konfigurační šablony. Každý gist je
samostatný — dá se zkopírovat bez čtení ostatních.

## Index

| # | Gist | Co řeší |
| --- | --- | --- |
| [0001](0001-env-detection.md) | Detekce `.env` | jak najít `.env` napříč Windows cestami |
| [0002](0002-reasonix-config.md) | Reasonix konfigurace | minimální `config.toml` s DeepSeek backendem |
| [0003](0003-claude-deepseek.md) | Claude Code + DeepSeek | proměnné prostředí pro Claude Code |
| [0004](0004-pi-reasonix.md) | Pi + reasonix | instalace a konfigurace rozšíření |
| [0005](0005-utf8-console.md) | UTF-8 konzole | oprava diakritiky v PowerShellu |

## Hotové soubory

Složka [`snippets/`](snippets/) obsahuje konfigurační soubory ke zkopírování:

| Soubor | Cíl |
| --- | --- |
| [`.env.example`](snippets/.env.example) | `env\.env` |
| [`reasonix.toml`](snippets/reasonix.toml) | `data\reasonix\config.toml`, odtud do `<Reasonix home>\config.toml` |
| [`models.json`](snippets/models.json) | `data\reasonix\models.json` |
| [`settings.json`](snippets/settings.json) | `.vscode\settings.json` |

`scripts/Setup-DeepSeekStack.ps1` tyto soubory seeduje automaticky, pokud
v cíli ještě neexistují. Existující konfiguraci nikdy nepřepíše.

## Jak gist použít

1. Otevřete soubor a přečtěte sekci **Kdy to použít**.
2. Zkopírujte blok kódu.
3. Pokud jde o konfiguraci, ověřte cesty vůči `scaffold/directory-tree.txt`.
4. Po změně konfigurace spusťte `scripts\Get-AiStackInfo.ps1`.
