# 05 — Bezpečnost

## Kde se ukládají secrets

| Místo | Obsah | V gitu? |
| --- | --- | --- |
| `env/.env` | `DEEPSEEK_API_KEY` a další hodnoty | **ne** — v `.gitignore` |
| `.env` (kořen) | alternativní umístění, stejná pravidla | **ne** — v `.gitignore` |
| `env/.env.example` | pouze vzor s `sk-xxxxxxxx` | ano |
| `logs/*.log` | logy běhů | **ne** — v `.gitignore` |
| `data/` | runtime konfigurace | **ne** — v `.gitignore` |

Jediné povolené místo pro skutečný klíč je `env/.env` (nebo `.env`).
Nikdy neukládejte klíč do:

- shell profilu (`$PROFILE`)
- systémových proměnných prostředí nastavených přes `setx`
- argumentů příkazové řádky (jsou vidět v historii a v seznamu procesů)
- `settings.json`, `tasks.json`, `config.toml` nebo jakéhokoli souboru v gitu

## Jak maskovat hodnoty v lozích

`Get-MaskedValue` vrací bezpečnou podobu hodnoty:

```powershell
Get-MaskedValue -Value 'sk-abcdef1234567890'
# sk-a...7890

Get-MaskedValue -Value 'krátké'
# <nastaveno, skryto>

Get-MaskedValue -Value $null
# <nenastaveno>
```

Pravidla:

1. Do logu nikdy nepište celou hodnotu klíče — vždy přes `Get-MaskedValue`.
2. `Get-AiStackInfo.ps1 -Json` je bezpečný ke sdílení: klíč vrací maskovaný.
3. Cizí URL a modely se maskují zbytečně — maskujte pouze skutečná tajemství.
4. Když si nejste jistí, jestli je hodnota citlivá, maskujte ji.

Rychlá kontrola, že v repu nejsou klíče:

```powershell
git grep -nE 'sk-[A-Za-z0-9]{16,}'
Get-ChildItem -Recurse -File -Include *.md,*.json,*.ps1,*.toml |
    Select-String -Pattern 'sk-[A-Za-z0-9]{16,}'
```

## Co nikdy necommitovat

- `.env` v jakékoli podobě (kromě `.env.example` bez hodnot)
- `logs/` a `data/` (obsahují stopy běhů a konfiguraci)
- `bin/` (`node_modules`, binárky)
- `node_modules/` kdekoliv
- exporty diagnostiky s nemaskovanými hodnotami
- privátní klíče, certifikáty, `*.pem`, `*.pfx`

`.gitignore` tyto cesty pokrývá. Po jeho změně ověřte:

```powershell
pwsh -File scripts\Test-Workspace.ps1   # kontrola "Secrets (.env)" musí být OK
```

## Rotace klíčů

Kdy rotovat:

- klíč unikl (log, screenshot, commit, chat)
- pravidelná rotace podle interní politiky
- klíč byl použit na cizím nebo veřejném stroji
- při předání workspace jiné osobě

Postup:

1. Vygenerujte nový klíč na https://platform.deepseek.com/api_keys.
2. Aktualizujte `env\.env`.
3. **Zneplatněte starý klíč** v konzoli poskytovatele.
4. Ověřte: `pwsh -File scripts\Get-AiStackInfo.ps1` → `DEEPSEEK_API_KEY: ...` OK.
5. Pokud klíč unikl do gitu, přepište historii (`git filter-repo`) — smazání
   souboru v novém commitu nestačí.

## Další zásady

- **Nejmenší privilegium.** Workspace nikdy nevyžaduje admin. Pokud vám nějaký
  krok admin práva nabízí, něco je špatně.
- **Žádná elevace v launcheru.** `launcher/*.cmd` nikdy nevolá `runas`.
- **Ověřujte před instalací.** `Setup-DeepSeekStack.ps1` instaluje balíčky
  z npm; názvy jsou v `$ComponentCatalog` — zkontrolujte je, než spustíte
  instalaci bez `-WhatIf`.
- **`-WhatIf` napřed.** Všechny skripty měnící stav podporují `-WhatIf`.
- **Kontrola po přesunu.** Po zkopírování workspace na jiný stroj spusťte
  `Test-Workspace.ps1`, ať víte, že se nic nerozbilo.
- **Logy jsou citlivé.** Mohou obsahovat cesty, uživatelská jména a části
  konfigurace. Nesdílejte je bez kontroly.
