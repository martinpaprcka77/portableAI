# 04 — Architektura

## Vrstvy

```
                       ┌──────────────────────────────────────┐
   uživatel ──────────►│  launcher/Start-PortableAI.cmd       │  tenká vrstva
                       │  launcher/Launch-*.cmd               │  (.cmd, CRLF)
                       └───────────────┬──────────────────────┘
                                       │ spustí
                                       ▼
                       ┌──────────────────────────────────────┐
                       │  launcher/Menu.ps1                   │  orchestrace
                       │  - volba z menu, PATH pro lokální    │
                       │    npm prefix, načtení .env          │
                       └───────────────┬──────────────────────┘
                                       │ volá
        ┌──────────────────────────────┼──────────────────────────────┐
        ▼                              ▼                              ▼
┌──────────────────┐        ┌──────────────────┐         ┌──────────────────┐
│ Setup-DeepSeek   │        │ Get-AiStackInfo  │         │ Test-Workspace   │
│ Setup-*.ps1      │        │ -*.ps1           │         │ Repair-Repo.ps1  │
│ (mění stav)      │        │ (read-only)      │         │ (mění stav)      │
└────────┬─────────┘        └────────┬─────────┘         └────────┬─────────┘
         │                           │                            │
         └───────────────┬───────────┴────────────────────────────┘
                         ▼
              ┌────────────────────────────┐
              │  scripts/_common.ps1       │  sdílené jádro
              │  Get-WorkspaceRoot         │
              │  Get-WorkspaceManifest     │  ← jediný zdroj pravdy
              │  Write-Log / Write-Banner  │     o struktuře
              │  Test-Command / Test-IsAdmin│
              │  Import-DotEnv             │
              │  Get-MaskedValue           │
              └────────────────────────────┘
```

## Tok dat

```
env/.env ──Import-DotEnv──► proměnné prostředí procesu ──► AI agenti
                                    │
                                    └──► Get-AiStackInfo (maskovaný výpis)

.env.example ──vzor──► env/.env ──► uživatel vyplní klíč
gists/snippets/*.toml ──seed──► data/reasonix/config.toml

launcher ──► scripts ──► logs/*.log  (každý běh zapisuje, co dělal)
```

## Komponenty

| Komponenta | Odpovědnost | Mění stav? |
| --- | --- | --- |
| `_common.ps1` | sdílené funkce, manifest, katalog komponent, logování | ne |
| `Setup-DeepSeekStack.ps1` | instalace nástrojů a seed konfigurace | ano (`-WhatIf`) |
| `Get-AiStackInfo.ps1` | diagnostický snapshot | ne |
| `Repair-Repo.ps1` | git atributy, koncovky, untrack | ano (`-WhatIf`) |
| `Test-Workspace.ps1` | self-test šestnácti oblastí | jen s `-Fix` |
| `Menu.ps1` | interaktivní rozcestník | ne |
| `.github/workflows/ci.yml` | CI: SelfHeal → Setup → Test-Workspace na Windows runneru | ne (běží na GitHubu) |

## Rozhodovací pravidla

1. **Kořen workspace** se vždy odvozuje z `$PSScriptRoot` v `_common.ps1`.
   Nikdy není hardcoded, takže workspace funguje z libovolné cesty.
2. **Manifest** (`Get-WorkspaceManifest`) je jediný zdroj pravdy o tom, co má
   existovat. Diagnostika i self-test ho sdílejí — nemohou se rozejít.
3. **Encoding** je vynucený: `.ps1` = UTF-8 s BOM + CRLF, ostatní texty = UTF-8
   bez BOM + LF. Důvod: PowerShell potřebuje BOM kvůli diakritice, git a
   Markdown naopak LF.
4. **Nic se neinstaluje globálně.** Lokální npm prefix `bin/npm-global` drží
   nástroje uvnitř workspace, takže přežijí reinstalaci systému. Nalezení
   nástroje v globálním `PATH` proto není důvod instalaci vynechat
   (`-UseGlobalIfPresent` je jen vědomá výjimka).
5. **Kategorie komponent** (`Get-ComponentCatalog`) určují, co je povinné:
   `Required` (`reasonix`) musí být vždy v `bin/npm-global`, `Recommended`
   (`pi`) se instaluje standardně, `Optional` (`claude`, `dsh`) jen na
   vyžádání. Stejná data čte setup, diagnostika i self-test.
6. **Logování je opt-in do souboru.** Diagnostika nezapisuje do `logs/`, pokud
   jí to neřeknete přes `-LogFile`.

## Životní cyklus

```
rozbalení ZIP
     │
     ▼
Test-Workspace.ps1 -Fix ──► BOM, CRLF, git init
     │
     ▼
Setup-DeepSeekStack.ps1 ──► env/.env, npm prefix, seed konfigurace
     │
     ▼
Get-AiStackInfo.ps1 ──► OK / WARN / FAIL
     │
     ▼
běžná práce (Menu.ps1)
     │
     ▼
Repair-Repo.ps1 (po změnách struktury nebo problémech s gitem)
```

## Rozšíření

Nový skript přidávejte takto:

1. Založte `scripts/<Verb>-<Noun>.ps1` se schváleným slovesem.
2. Na začátku dot-sourceujte `_common.ps1` a použijte `Get-WorkspaceRoot`.
3. Přidejte comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`).
4. Pokud mění stav, přidejte `SupportsShouldProcess` a obalte změny
   `$PSCmdlet.ShouldProcess()`.
5. Zaregistrujte skript v `Get-WorkspaceManifest` (sekce `PowerShellScripts`)
   a v `launcher/Menu.ps1`.
6. Spusťte `Test-Workspace.ps1` — musí zůstat PASS.

Detaily rozhodnutí: [adr/](adr/).
