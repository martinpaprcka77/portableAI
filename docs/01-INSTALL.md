# 01 — Instalace

Návod krok za krokem. Předpokládaná doba: 10 minut (z toho 5 minut čekání na npm).

## 1. Požadavky

| Nástroj | Minimální verze | Jak ověřit | Poznámka |
| --- | --- | --- | --- |
| Windows | 11 22H2+ (10 funguje) | `winver` | bez admin práv |
| PowerShell | 5.1 (doporučeno 7+) | `$PSVersionTable.PSVersion` | `pwsh.exe` v `PATH` |
| Node.js | 22.19 | `node --version` | musí být v `PATH` |
| Git for Windows | libovolná recent | `git --version` | kvůli `Repair-Repo.ps1` |
| DeepSeek API klíč | — | — | https://platform.deepseek.com/api_keys |

> **Workspace nic z toho neinstaluje sám.** Chybějící závislost ohlásí jako
> `WARN` a pokračuje. Důvod: instalace by vyžadovala admin práva nebo globální
> zápis, což je proti návrhu workspace.

Ověření požadavků jedním příkazem:

```powershell
pwsh -File scripts\Test-Workspace.ps1
```

## 2. Stažení

**Varianta A — ZIP:**

1. Rozbalte archiv tak, aby vznikl `C:\portableAI\` s `README.md` v kořeni.
2. Pokud už `C:\portableAI\` existuje, **rozbalte do nové složky** a obsah
   sloučte ručně — workspace nepřepisuje existující soubory sám.

**Varianta B — git:**

```powershell
git clone <URL> C:\portableAI
```

**Varianta C — jiný disk / USB:**

Workspace funguje z libovolné cesty (`D:\tools\portableAI`, `E:\ai`).
Všechny skripty si kořen odvozují z vlastní pozice, takže stačí složku
zkopírovat. Po přesunu spusťte `scripts\Test-Workspace.ps1 -Fix`.

## 3. První spuštění

```powershell
cd C:\portableAI
pwsh -File launcher\Menu.ps1
```

Nebo dvojklikem na `launcher\Start-PortableAI.cmd`.

Menu nabídne:

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

Nejdřív zvolte `[1] Setup` — teprve pak má smysl diagnostika.

### Co Setup instaluje

Komponenty mají kategorie (viz [02-CONFIG.md](02-CONFIG.md), sekce
„Kategorie komponent a výběr instalace“):

| Kategorie | Komponenty | Kdy se instaluje |
| --- | --- | --- |
| Required | `reasonix` | vždy |
| Recommended | `pi` | vždy, kromě `-SkipOptional` |
| Optional | `claude`, `dsh` | jen s `-InstallOptional <jméno>` |

Vše se instaluje do `bin/npm-global`. Když je nástroj nalezený jen
v globálním `PATH` (typicky `%APPDATA%\npm`), **instalace do workspace se
přesto provede** — jinak by workspace po přesunu na jiný stroj nefungoval.
Kdo chce globální instalaci vědomě použít, přidá `-UseGlobalIfPresent`.

```powershell
pwsh -File scripts\Setup-DeepSeekStack.ps1                  # reasonix + pi
pwsh -File scripts\Setup-DeepSeekStack.ps1 -SkipOptional     # jen reasonix
pwsh -File scripts\Setup-DeepSeekStack.ps1 -InstallOptional claude,dsh
pwsh -File scripts\Setup-DeepSeekStack.ps1 -WhatIf           # jen plán
```

## 4. Konfigurace klíče

1. Setup při prvním běhu vytvoří `env\.env` ze vzoru `env\.env.example`.
2. Otevřete `env\.env` a nahraďte `sk-xxxxxxxx...` skutečným klíčem.
3. Spusťte `[1] Setup` znovu — ověří, že klíč je nastavený.

Alternativa bez editace souboru (platí jen pro aktuální session):

```powershell
$env:DEEPSEEK_API_KEY = 'sk-...'
pwsh -File scripts\Get-AiStackInfo.ps1
```

## 5. Ověření instalace

```powershell
pwsh -File scripts\Test-Workspace.ps1        # očekáváno: WORKSPACE TEST: PASS (16 kontrol)
pwsh -File scripts\Get-AiStackInfo.ps1       # očekáváno: CELKOVÝ STAV: OK
```

Kontrola 16 ověřuje, že `Required` komponenta `reasonix` je v `bin/npm-global`
(tedy přenositelná s workspace). Když hlásí `FAIL`, doinstalujte ji:

```powershell
pwsh -File scripts\Setup-DeepSeekStack.ps1 -WhatIf   # co se nainstaluje
pwsh -File scripts\Setup-DeepSeekStack.ps1           # proveď instalaci
```

Když self-test hlásí `FAIL`, spusťte:

```powershell
pwsh -File scripts\Test-Workspace.ps1 -Fix -WhatIf   # co by se opravilo
pwsh -File scripts\Test-Workspace.ps1 -Fix           # proveď opravy
```

## 6. Volitelně: git repozitář

Pokud plánujete verzovat vlastní projekty uvnitř workspace:

```powershell
git init
git add .
git commit -m "Initial portable AI workspace"
pwsh -File scripts\Repair-Repo.ps1
```

`Repair-Repo.ps1` nastaví `.gitattributes`, renormalizuje koncovky a odstraní
`node_modules` z trackingu.

## Odinstalace

Workspace je jen složka:

1. Zkontrolujte, že v `env\.env` nemáte klíč, který potřebujete jinde.
2. Smažte složku `C:\portableAI\`.
3. Odstraňte případné záznamy z `PATH`, pokud jste si je přidali ručně.

Nic se nezapisuje do registru ani do `%APPDATA%`.
