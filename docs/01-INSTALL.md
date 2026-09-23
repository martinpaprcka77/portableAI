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
pwsh -File scripts\Test-Workspace.ps1        # očekáváno: WORKSPACE TEST: PASS
pwsh -File scripts\Get-AiStackInfo.ps1       # očekáváno: CELKOVÝ STAV: OK
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
