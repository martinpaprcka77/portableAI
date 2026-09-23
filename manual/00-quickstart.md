# 00 — Quickstart (5 minut)

Od nuly k prvnímu promptu. Předpokládáme, že máte složku `C:\portableAI\`.

## Minuta 0 — Kontrola

Otevřete PowerShell a ověřte, že máte potřebné nástroje:

```powershell
pwsh --version
node --version
git --version
```

Když některý chybí, doinstalujte ho ručně — workspace to sám neudělá.

## Minuta 1 — Start

```powershell
cd C:\portableAI
pwsh -File launcher\Menu.ps1
```

Nebo dvojklikněte na `launcher\Start-PortableAI.cmd`.

Uvidíte menu:

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

## Minuta 2 — Setup

Zvolte `[1]`. Setup:

- vytvoří `env/.env` ze vzoru,
- nainstaluje nástroje do `bin/npm-global` (lokálně),
- nakonfiguruje Reasonix a Claude Code,
- spustí ověření.

Komponenty mají kategorie: `reasonix` je `Required` (vždy se instaluje),
`pi` je `Recommended`, `claude` a `dsh` jsou `Optional` (jen na vyžádání).
Nástroj nalezený v globálním `PATH` se **přesto** nainstaluje do workspace,
aby workspace fungoval i po přesunu na jiný stroj.

```powershell
pwsh -File scripts\Setup-DeepSeekStack.ps1 -WhatIf                # jen plán
pwsh -File scripts\Setup-DeepSeekStack.ps1 -SkipOptional          # jen reasonix
pwsh -File scripts\Setup-DeepSeekStack.ps1 -InstallOptional dsh   # + DSH
```

## Minuta 3 — API klíč

Nejdřív ověřte, zda klíč už nemáte v prostředí:

```powershell
[Environment]::GetEnvironmentVariable("DEEPSEEK_API_KEY", "User")
```

Vrátí-li hodnotu, klíč v prostředí máte a `env\.env` nechte být — env má
přednost a Setup do `.env` nic nezapisuje.

Vrátí-li `$null`, vyplňte klíč do `env\.env`:

1. Otevřete `env\.env` v editoru.
2. Najděte zakomentovaný řádek `# DEEPSEEK_API_KEY=sk-vložte-sem`.
3. Odkomentujte ho a nahraďte hodnotu skutečným klíčem z
   https://platform.deepseek.com/api_keys.
4. Uložte soubor.

Soubor `env\.env` je v `.gitignore` — nikdy se necommituje.

## Minuta 4 — Ověření

Zvolte `[2] Diagnostics`, nebo:

```powershell
pwsh -File scripts\Get-AiStackInfo.ps1
```

Hledejte:

```
[OK  ] DEEPSEEK_API_KEY: sk-a...1234
=== CELKOVÝ STAV: OK ===
```

Volitelně spusťte self-test:

```powershell
pwsh -File scripts\Test-Workspace.ps1
# === WORKSPACE TEST: PASS ===
```

## Minuta 5 — První prompt

Zvolte `[5] Launch Reasonix` (nebo jiný agent). Agenta spouštějte vždy
s kontextem workspace — nejlépe přes launcher, který načte `env\.env`.

První zpráva agentovi:

```
Přečti si prompts/00-system.md a řiď se jím.

Úkol: <co chcete udělat>
Kritérium hotovo: <jak poznáte, že je to hotové>
```

Nebo si vezměte hotový prompt z `prompts/`:

- nový projekt → `prompts/01-setup.md`
- něco nefunguje → `prompts/02-diagnostics.md`
- implementace → `prompts/03-coding.md`

## Hotovo

Teď víte, jak workspace spustit, nakonfigurovat a ověřit. Dál:

- [Cheatsheet](01-cheatsheet.md) — příkazy na jedné stránce
- [Workflows](02-workflows.md) — typické scénáře
- [FAQ](03-faq.md) — časté otázky
- [Glosář](04-glossary.md) — pojmy AI nástrojů

## Časté zádrhely

| Problém | Řešení |
| --- | --- |
| `pwsh` není rozpoznán | použijte `Start-PortableAI.cmd`, který má fallback na `powershell.exe` |
| Rozbitá diakritika | `pwsh -File scripts\Repair-Repo.ps1` |
| `Test-Workspace` hlásí FAIL | `pwsh -File scripts\Test-Workspace.ps1 -Fix` |
| Setup hlásí `npm exit 1` | zkontrolujte síť a názvy balíčků v `Get-ComponentCatalog` (`scripts/_common.ps1`) |
| `reasonix` není ve workspace | `pwsh -File scripts\Setup-DeepSeekStack.ps1` (kontrola 16 v self-testu) |
