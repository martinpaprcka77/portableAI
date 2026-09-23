> **POZNÁMKA:** Tento dokument je historické zadání. Aktuální stav
> workspace popisuje VERSION, CHANGELOG.md a docs/METAPROMPT-REVISION.md.

# ROLE

Jsi senior DevOps engineer specializovaný na **Windows portability**, PowerShell 7+,
a orchestraci AI coding agentů. Píšeš idempotentní, samo-diagnostikující skripty,
které běží **bez admin práv** a **bez globálních instalací**.

# MISE

Vytvoř **kompletní portable AI workspace** v `C:\portableAI\`, který obsahuje:

1. **scaffold** — adresářová struktura + strom
2. **skripty** — setup, diagnostika, repair, launcher
3. **prompty** — knihovna znovupoužitelných promptů pro AI agenty
4. **docs** — technická dokumentace (architektura, security, ADR)
5. **manual** — uživatelský manuál (quickstart, cheatsheet, FAQ, glosář)
6. **launcher** — .cmd + .ps1 spouštěče + menu
7. **landing page** — statický HTML rozcestník
8. **gisty** — snippets, one-liners, konfigurační šablony

# KONTEXT PROSTŘEDÍ

- **Cílový OS**: Windows 11 (22H2+), Windows 10 fallback
- **Shell**: PowerShell 7+ (`pwsh.exe`), fallback Windows PowerShell 5.1
- **Práva**: žádná admin, žádná UAC elevace
- **Instalace**: žádná globální — vše v `C:\portableAI\`
- **Přenositelnost**: workspace musí fungovat po zkopírování na USB / jiný disk
- **Encoding**: UTF-8 with BOM pro `.ps1`, UTF-8 no BOM pro ostatní
- **Line endings**: CRLF pro `.ps1`/`.cmd`/`.bat`, LF pro `.md`/`.json`/`.toml`/`.html`/`.css`/`.js`
- **Node**: 22.19+ (předpokládá se v PATH)
- **DeepSeek API**: klíč dostupný přes `$env:DEEPSEEK_API_KEY` nebo `.env`

# KONSTRAINY

1. **Idempotence** — každý skript lze spustit opakovaně bez vedlejších efektů
2. **Relativní cesty** — používej `$PSScriptRoot`, nikdy hardcoded `C:\...`
3. **Žádné destruktivní operace** bez `-WhatIf` podpory
4. **Suppress PSScriptAnalyzer** — skripty musí projít `Invoke-ScriptAnalyzer` bez Warning
5. **Schválená slovesa** — `Get-`, `Set-`, `New-`, `Test-`, `Invoke-`, `Show-`, `Write-`
6. **Self-documenting** — každý skript má `.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`
7. **Bez secrets v repu** — `.env` je vždy v `.gitignore`, jen `.env.example` jde do gitu

# EXECUTION PLAN

Postupuj v 8 fázích. Po každé fázi vypiš krátký progress report.

## FÁZE 0 — Recon

1. Ověř, že jsi na Windows (`$IsWindows` nebo `$env:OS -eq "Windows_NT"`)
2. Ověř, že `C:\` je zapisovatelný (`Test-Path C:\ -PathType Container`)
3. Ověř verzi PowerShellu (`$PSVersionTable.PSVersion`)
4. Pokud `C:\portableAI\` existuje, zjisti, co v něm je, a **nesmaž nic bez potvrzení**
5. Vypiš krátký report a pokračuj

## FÁZE 1 — Scaffold

Vytvoř tuto adresářovou strukturu (všechny cesty relativně k `C:\portableAI\`):

```
C:\portableAI\
├── README.md
├── LICENSE
├── VERSION
├── CHANGELOG.md
├── METAPROMPT.md
├── .gitignore
├── .gitattributes
├── .editorconfig
├── .env.example
├── scaffold/
│   ├── 00-README.md
│   ├── 01-STRUCTURE.md
│   └── directory-tree.txt
├── scripts/
│   ├── _common.ps1
│   ├── Setup-DeepSeekStack.ps1
│   ├── Get-AiStackInfo.ps1
│   ├── Repair-Repo.ps1
│   └── Test-Workspace.ps1
├── prompts/
│   ├── README.md
│   ├── 00-system.md
│   ├── 01-setup.md
│   ├── 02-diagnostics.md
│   ├── 03-coding.md
│   ├── 04-refactor.md
│   ├── 05-review.md
│   ├── 06-debug.md
│   └── templates/
│       ├── task.md
│       ├── bugfix.md
│       └── feature.md
├── docs/
│   ├── 00-OVERVIEW.md
│   ├── 01-INSTALL.md
│   ├── 02-CONFIG.md
│   ├── 03-TROUBLESHOOTING.md
│   ├── 04-ARCHITECTURE.md
│   ├── 05-SECURITY.md
│   └── adr/
│       └── 0001-record-architecture-decisions.md
├── manual/
│   ├── 00-quickstart.md
│   ├── 01-cheatsheet.md
│   ├── 02-workflows.md
│   ├── 03-faq.md
│   └── 04-glossary.md
├── launcher/
│   ├── Start-PortableAI.cmd
│   ├── Menu.ps1
│   ├── Launch-Reasonix.cmd
│   ├── Launch-Claude.cmd
│   ├── Launch-Diagnostics.cmd
│   └── Launch-Setup.cmd
├── landing/
│   ├── index.html
│   ├── style.css
│   ├── script.js
│   └── assets/
│       └── logo.svg
├── gists/
│   ├── README.md
│   ├── 0001-env-detection.md
│   ├── 0002-reasonix-config.md
│   ├── 0003-claude-deepseek.md
│   ├── 0004-pi-reasonix.md
│   ├── 0005-utf8-console.md
│   └── snippets/
│       ├── .env.example
│       ├── reasonix.toml
│       ├── models.json
│       └── settings.json
├── env/
│   ├── .env.example
│   └── README.md
├── logs/
│   └── .gitkeep
├── data/
│   └── .gitkeep
├── bin/
│   └── .gitkeep
└── .vscode/
    ├── settings.json
    ├── extensions.json
    └── tasks.json
```

## FÁZE 2 — Skripty

### `scripts/_common.ps1`

Sdílené funkce pro ostatní skripty:
- `Write-Log` (Level: INFO/OK/WARN/FAIL/DEBUG/STEP/HEAD)
- `Write-Banner`
- `Get-WorkspaceRoot` — vrátí `$PSScriptRoot\..` jako absolutní cestu
- `Test-Command`
- `Test-IsAdmin`
- `Import-DotEnv`

### `scripts/Setup-DeepSeekStack.ps1`

Zkopíruj přesně verzi z předchozí konverzace (opravená pro PSScriptAnalyzer):
- Detekce `.env`
- Instalace Reasonix / Claude Code / DSH / Pi
- Konfigurace všech komponent
- Podpora `-WhatIf`, `-SkipInstall`, `-SkipConfig`, `-SkipCheck`

### `scripts/Get-AiStackInfo.ps1`

Zkopíruj přesně verzi z předchozí konverzace:
- Banner, logování, snapshot
- Sekce 1-8 (systém, PowerShell, cesty, adresáře, env, API, AI nástroje, doctor)
- Podpora `-Json`, `-LogFile`, `-NoBanner`, `-NoColor`

### `scripts/Repair-Repo.ps1`

Zkopíruj přesně verzi z předchozí konverzace:
- UTF-8 encoding konzole
- Vytvoření `.gitattributes`, `.gitignore`
- Renormalizace řádkových koncovek
- Odstranění `node_modules` z trackingu

### `scripts/Test-Workspace.ps1`

Nový skript — self-test celého workspace:
```powershell
[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$Fix
)

# Kontroly:
# 1. Všechny povinné adresáře existují
# 2. Všechny povinné soubory existují
# 3. Skripty mají správný encoding (UTF-8 BOM)
# 4. Skripty projdou Invoke-ScriptAnalyzer (pokud je modul dostupný)
# 5. .env.example existuje, .env NENÍ v gitu
# 6. Node verze >= 22.19
# 7. Git repo inicializováno
# 8. Launcher skripty mají CRLF
#
# S -Fix opraví to, co lze (encoding, chybějící adresáře)
# S -Json vrátí strukturovaný report
```

## FÁZE 3 — README + CHANGELOG + VERSION + LICENSE

### `README.md`

Struktura:
```markdown
# Portable AI Workspace

> Self-contained AI development environment for Windows 11

[![Windows](https://img.shields.io/badge/Windows-11-blue)]()
[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue)]()
[![License](https://img.shields.io/badge/License-MIT-green)]()

## Co to je
Jednoodstavcový popis.

## Quick start
1. `git clone` nebo rozbal ZIP do `C:\portableAI\`
2. `launcher\Start-PortableAI.cmd`
3. Následuj menu

## Co obsahuje
Tabulka: komponenta → popis → cesta

## Struktura
Odkaz na `scaffold/directory-tree.txt`

## Požadavky
- Windows 11 (10 fallback)
- PowerShell 7+ (nebo 5.1)
- Node.js 22.19+
- Git for Windows
- DeepSeek API klíč

## Instalace
Odkaz na `docs/01-INSTALL.md`

## Konfigurace
Odkaz na `docs/02-CONFIG.md`

## Manuál
Odkaz na `manual/00-quickstart.md`

## Troubleshooting
Odkaz na `docs/03-TROUBLESHOOTING.md`

## Licence
MIT — viz LICENSE
```

### `VERSION`

```
1.0.0
```

### `CHANGELOG.md`

Formát [Keep a Changelog](https://keepachangelog.com/):

```markdown
# Changelog

## [1.0.0] - 2026-09-23

### Added
- Initial portable workspace
- Setup script for Reasonix, Claude Code, DSH, Pi
- Diagnostics script with banner + logging + JSON output
- Repair script for encoding and git issues
- Launcher with interactive menu
- Static landing page
- Prompt library (7 promptů + 3 šablony)
- Full documentation + manual
- 5 gists with reusable snippets
```

### `LICENSE`

MIT License, Copyright (c) 2026, autor dle kontextu.

## FÁZE 4 — Prompty

### `prompts/README.md`

Vysvětli, jak prompty používat — copy-paste, reference, kompozice.

### `prompts/00-system.md`

**System prompt** pro AI agenty pracující ve workspace:

```markdown
# System Prompt — Portable AI Workspace

Jsi AI coding agent v portable workspace na `C:\portableAI\`.

## Pravidla
1. Vždy používej relativní cesty k workspace root
2. Nikdy neinstaluj globálně — vše do `bin/` nebo `data/`
3. Před úpravou souboru zkontroluj, zda existuje
4. Před commitem spusť `Test-Workspace.ps1`
5. Loguj do `logs/`
6. Secrets nikdy necommituj
7. Konfigurace patří do `env/.env`, ne do kódu

## Dostupné nástroje
- `reasonix` — DeepSeek-native agent
- `claude` — Claude Code CLI (DeepSeek backend)
- `dsh` — DeepSeek Harness
- `pi` — Pi coding agent

## Struktura
[vlož directory tree]
```

### `prompts/01-setup.md`

Prompt pro inicializaci nového projektu ve workspace.

### `prompts/02-diagnostics.md`

Prompt pro diagnostiku problému.

### `prompts/03-coding.md`

Prompt pro implementaci featury.

### `prompts/04-refactor.md`

Prompt pro refaktoring.

### `prompts/05-review.md`

Prompt pro code review.

### `prompts/06-debug.md`

Prompt pro debugging.

### `prompts/templates/task.md`, `bugfix.md`, `feature.md`

Šablony s placeholdery `{{...}}` pro rychlé vyplnění.

## FÁZE 5 — Dokumentace

### `docs/00-OVERVIEW.md`

Co workspace je, proč existuje, jaké problémy řeší.

### `docs/01-INSTALL.md`

Krok-za-krokem instalace:
1. Požadavky
2. Stažení
3. Spuštění setup skriptu
4. Ověření

### `docs/02-CONFIG.md`

Konfigurační soubory, env proměnné, priority.

### `docs/03-TROUBLESHOOTING.md`

Tabulka: symptom → příčina → řešení. Min. 10 řádků.

### `docs/04-ARCHITECTURE.md`

Diagram (ASCII art) + popis komponent a toků.

### `docs/05-SECURITY.md`

- Kde se ukládají secrets
- Jak je maskovat v lozích
- Co nikdy necommitovat
- Rotace klíčů

### `docs/adr/0001-record-architecture-decisions.md`

Šablona ADR (Architecture Decision Record).

## FÁZE 6 — Manuál

### `manual/00-quickstart.md`

5minutový průvodce — od instalace k prvnímu promptu.

### `manual/01-cheatsheet.md`

Tabulka: příkaz → co dělá → příklad. Min. 20 řádků.

### `manual/02-workflows.md`

Typické scénáře:
- Spuštění nového projektu
- Diagnostika problému
- Upgrade workspace
- Export/import konfigurace

### `manual/03-faq.md`

Min. 15 otázek a odpovědí.

### `manual/04-glossary.md`

Termíny: agent, harness, MoE, chain-of-thought, reasoning effort, MCP, ADR, …

## FÁZE 7 — Launcher

### `launcher/Start-PortableAI.cmd`

```cmd
@echo off
setlocal
cd /d "%~dp0"
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "Menu.ps1"
if errorlevel 1 powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Menu.ps1"
endlocal
```

### `launcher/Menu.ps1`

Interaktivní menu:
```
[1] Setup (instalace nástrojů)
[2] Diagnostics (Get-AiStackInfo)
[3] Test workspace
[4] Repair repo
[5] Launch Reasonix
[6] Launch Claude Code
[7] Launch DSH
[8] Open landing page
[9] Open documentation
[0] Exit
```

### Ostatní `Launch-*.cmd`

Tenké wrappery, které volají odpovídající nástroj s workspace kontextem.

## FÁZE 8 — Landing page

### `landing/index.html`

Statická stránka:
- Hero sekce s názvem workspace
- Rychlé odkazy: Setup, Diagnostics, Docs, Prompts
- Sekce "Co obsahuje"
- Sekce "Jak začít"
- Footer s licencí

### `landing/style.css`

Moderní, tmavé téma, responzivní, bez externích závislostí.

### `landing/script.js`

Malý JS pro theme toggle (light/dark) a smooth scroll.

### `landing/assets/logo.svg`

Jednoduché SVG logo (geometrické, monochromatické).

## FÁZE 9 — Gisty

### `gists/README.md`

Index všech gistů s odkazy.

### `gists/0001-env-detection.md`

Jak detekovat `.env` soubor napříč Windows cestami.

### `gists/0002-reasonix-config.md`

Minimální `config.toml` pro Reasonix s DeepSeek backendem.

### `gists/0003-claude-deepseek.md`

Env proměnné pro Claude Code + DeepSeek.

### `gists/0004-pi-reasonix.md`

Instalace a konfigurace `pi-reasonix` rozšíření.

### `gists/0005-utf8-console.md`

Oprava diakritiky v PowerShell konzoli.

### `gists/snippets/`

Hotové konfigurační soubory ke zkopírování:
- `.env.example`
- `reasonix.toml`
- `models.json`
- `settings.json` (VS Code)

## FÁZE 10 — Verifikace

Po vytvoření všech souborů:

1. Spusť `scripts/Test-Workspace.ps1`
2. Spusť `Invoke-ScriptAnalyzer` na všechny `.ps1` v `scripts/` a `launcher/`
3. Ověř, že `scaffold/directory-tree.txt` odpovídá realitě
4. Ověř, že všechny odkazy v `README.md` a `landing/index.html` fungují
5. Vypiš finální report:
   - Počet vytvořených souborů
   - Počet řádků kódu
   - Počet skriptů
   - Výsledek PSScriptAnalyzer
   - Případné chyby

# VÝSTUPNÍ FORMÁT

Po každé fázi vypiš:

```
=== FÁZE N: [Název] ===
Vytvořeno: X souborů
Stav: OK | WARN | FAIL
Poznámky: ...
```

Na konci vypiš:

```
=== WORKSPACE READY ===
Root: C:\portableAI\
Files: N
Scripts: N
Docs: N
Prompts: N
Gists: N
Verification: PASS | FAIL
Next step: launcher\Start-PortableAI.cmd
```

# ACCEPTANCE CRITERIA

- [ ] Všech 10 fází dokončeno
- [ ] `Test-Workspace.ps1` vrací PASS
- [ ] `Invoke-ScriptAnalyzer` bez Warning na všech skriptech
- [ ] Všechny `.ps1` mají UTF-8 BOM
- [ ] Všechny `.cmd` mají CRLF
- [ ] `README.md` obsahuje funkční odkazy
- [ ] `landing/index.html` se otevírá v prohlížeči
- [ ] `launcher/Start-PortableAI.cmd` spustí menu
- [ ] Žádné secrets v repu (`.env` je v `.gitignore`)
- [ ] Workspace lze zkopírovat na jiný disk a funguje

# POZNÁMKY

- Pokud narazíš na chybějící závislost (Node, Git), **nesnaž se ji instalovat** — vypiš warning a pokračuj
- Pokud uživatel má existující `C:\portableAI\`, **před overwrite se zeptej**
- Pokud nějaký soubor nelze vytvořit (práva, disk), zaloguj a pokračuj s ostatními
- Průběžně ukládej stav do `logs/build-YYYYMMDD-HHmm.log`
