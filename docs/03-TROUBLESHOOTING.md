# 03 — Troubleshooting

Než začnete hádat, spusťte diagnostiku:

```powershell
pwsh -File scripts\Get-AiStackInfo.ps1 -NoBanner
pwsh -File scripts\Test-Workspace.ps1
```

## Tabulka symptom → příčina → řešení

| # | Symptom | Pravděpodobná příčina | Řešení |
| --- | --- | --- | --- |
| 1 | `pwsh.exe` není rozpoznán | PowerShell 7 není v `PATH` | Nainstalujte PS7, nebo použijte `launcher\Start-PortableAI.cmd` (má fallback na `powershell.exe`) |
| 2 | Diakritika v konzoli je rozbitá (`Ã¡` místo `á`) | Konzole není v UTF-8 | Spusťte `scripts\Repair-Repo.ps1`; viz `gists/0005-utf8-console.md` |
| 3 | `node --version` hlásí verzi < 22.19 | Zastaralý Node | Aktualizujte Node ručně; workspace nic neinstaluje |
| 4 | `Setup` hlásí `npm exit 1` | Chybí síť, proxy, nebo neexistuje balíček | Zkontrolujte síť; upravte `$ComponentCatalog` v `Setup-DeepSeekStack.ps1` |
| 5 | `Get-AiStackInfo` hlásí `DEEPSEEK_API_KEY: <nenastaveno>` | Chybí `env\.env` | `Copy-Item env\.env.example env\.env` a vyplňte klíč |
| 6 | API vrací `401 Unauthorized` | Neplatný nebo expirovaný klíč | Vygenerujte nový klíč a aktualizujte `env\.env` |
| 7 | `Test-Workspace` hlásí `bez BOM: ...ps1` | Skript byl uložen bez BOM | `Test-Workspace.ps1 -Fix` (přidá BOM) |
| 8 | `Test-Workspace` hlásí `LF místo CRLF` | Soubor vznikl v Linux nástroji/editoru | `Test-Workspace.ps1 -Fix` (převede koncovky) |
| 9 | `Test-Workspace` hlásí `workspace není git repozitář` | Nebylo spuštěno `git init` | `Test-Workspace.ps1 -Fix` nebo `git init` |
| 10 | `PSScriptAnalyzer` hlásí `PSUseBOMForUnicodeEncodedFile` | Skript s diakritikou bez BOM | `Test-Workspace.ps1 -Fix`, pak ověřte `UTF-8 BOM u .ps1: OK` |
| 11 | `git add` mění konce řádků u každého souboru | Chybí nebo je špatně `.gitattributes` | `Repair-Repo.ps1` a pak `git add --renormalize .` |
| 12 | V gitu se objevil `node_modules` | Byl přidán dřív než `.gitignore` | `Repair-Repo.ps1` (odstraní z trackingu, soubory zůstanou) |
| 13 | `Menu.ps1` se nespustí, hned zmizí okno | `.cmd` má LF místo CRLF, nebo chybí `-ExecutionPolicy Bypass` | `Test-Workspace.ps1 -Fix`; zkontrolujte `Start-PortableAI.cmd` |
| 14 | `Repair-Repo.ps1` hlásí `git není v PATH` | Git for Windows není nainstalovaný | Nainstalujte Git for Windows |
| 15 | `landing/index.html` zobrazuje rozbité odkazy | Byl přesunut soubor nebo se změnila struktura | Ověřte cesty vůči `scaffold/directory-tree.txt` |
| 16 | Workspace nefunguje po zkopírování na USB | Absolutní cesta v konfiguraci | Hledejte `C:\portableAI` v `env\`, `data\`, `.vscode\` a nahraďte relativní cestou |
| 17 | `UnauthorizedAccessException` při zápisu do `logs/` | Soubor drží jiný proces nebo je čistě jen pro čtení | Zavřete ostatní procesy; workspace nepotřebuje admin práva |
| 18 | Agent „nevidí“ proměnné z `.env` | Byl spuštěn v jiném procesu bez načtení `.env` | Spouštějte agenty přes `launcher\Launch-*.cmd`, které `.env` načítají |
| 19 | `Test-Workspace` hlásí `PSScriptAnalyzer: ... FAIL` | Reálný nález PSScriptAnalyzeru | Přečtěte nález v detailu a opravte skript |
| 20 | Vše funguje, ale `Test-Workspace` hlásí `chybí soubor: ...` | Nekompletní rozbalení ZIPu | Rozbalte archiv znovu se zachováním struktury |

## Systematický postup

Když tabulka nepomůže:

1. **Reprodukujte** — spusťte znovu přesně to, co selhalo.
2. **Změřte** — `Get-AiStackInfo.ps1 -Json > logs\before.json`.
3. **Izolujte** — vypněte/odeberte jednu proměnnou (env, PATH, soubor).
4. **Opravte jednu věc** — pak znovu `Test-Workspace.ps1`.
5. **Zaznamenejte** — `Get-AiStackInfo.ps1 -Json > logs\after.json` a porovnejte.

## Kam se dívat

| Zdroj | Co tam je |
| --- | --- |
| `logs/*.log` | historie běhů setupu, oprav a diagnostiky |
| `Get-AiStackInfo.ps1 -Json` | strojově čitelný snapshot pro diff |
| `git status` / `git diff` | co se změnilo v repu |
| `Invoke-ScriptAnalyzer -Path .\scripts` | statická analýza skriptů |
