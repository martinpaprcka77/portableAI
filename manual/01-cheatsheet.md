# 01 — Cheatsheet

## Spouštění

| Příkaz | Co dělá | Příklad |
| --- | --- | --- |
| `launcher\Start-PortableAI.cmd` | spustí interaktivní menu | dvojklik v Průzkumníku |
| `pwsh -File launcher\Menu.ps1` | totéž z terminálu | `pwsh -File launcher\Menu.ps1` |
| `pwsh -File scripts\Setup-DeepSeekStack.ps1` | instalace a konfigurace stacku | `... -SkipInstall` |
| `Setup-DeepSeekStack.ps1 -SkipOptional` | přeskočí `Recommended` i `Optional` (jen `reasonix`) | `... -SkipOptional` |
| `Setup-DeepSeekStack.ps1 -InstallOptional X` | doinstaluje vyjmenované `Optional` komponenty | `... -InstallOptional claude,dsh` |
| `Setup-DeepSeekStack.ps1 -UseGlobalIfPresent` | použije globální instalaci, když existuje | `... -UseGlobalIfPresent` |
| `pwsh -File scripts\Get-AiStackInfo.ps1` | diagnostický snapshot | `... -NoBanner` |
| `pwsh -File scripts\Test-Workspace.ps1` | self-test workspace | `... -Fix` |
| `pwsh -File scripts\Repair-Repo.ps1` | oprava gitu a koncovek | `... -WhatIf` |

## Diagnostika

| Příkaz | Co dělá | Příklad |
| --- | --- | --- |
| `Get-AiStackInfo.ps1` | 8 sekcí stavu workspace | `pwsh -File scripts\Get-AiStackInfo.ps1` |
| `Get-AiStackInfo.ps1 -Json` | strojově čitelný výstup | `... -Json > logs\snap.json` |
| `Get-AiStackInfo.ps1 -LogFile X` | zapíše i do souboru | `... -LogFile logs\doc.log` |
| `Get-AiStackInfo.ps1 -NoColor` | bez barev (CI) | `... -NoColor` |
| `Get-AiStackInfo.ps1 -NoBanner` | bez ASCII banneru | `... -NoBanner` |
| `Get-AiStackInfo.ps1 -Verbose` | zobrazí i DEBUG řádky | `... -Verbose` |

## Údržba a opravy

| Příkaz | Co dělá | Příklad |
| --- | --- | --- |
| `Test-Workspace.ps1` | 16 kontrol, PASS/FAIL | `pwsh -File scripts\Test-Workspace.ps1` |
| `Test-Workspace.ps1 -Fix` | opraví BOM, CRLF, dirs, git | `... -Fix` |
| `Test-Workspace.ps1 -Fix -WhatIf` | jen ukáže, co by opravil | `... -Fix -WhatIf` |
| `Test-Workspace.ps1 -Json` | výsledek jako JSON | `... -Json` |
| `Repair-Repo.ps1` | .gitattributes, renormalizace, untrack | `pwsh -File scripts\Repair-Repo.ps1` |
| `Repair-Repo.ps1 -SkipLineEndings` | přeskočí koncovky | `... -SkipLineEndings` |
| `Repair-Repo.ps1 -SkipUntrack` | nechá `node_modules` být | `... -SkipUntrack` |

## Git

| Příkaz | Co dělá | Příklad |
| --- | --- | --- |
| `git init` | založí repozitář ve workspace | `git -C C:\portableAI init` |
| `git add --renormalize .` | přepíše koncovky podle atributů | po změně `.gitattributes` |
| `git rm -r --cached node_modules` | vyřadí z trackingu, soubory zůstanou | `Repair-Repo.ps1` |
| `git check-ignore -v .env` | ověří, že `.env` je ignorovaný | `git check-ignore -v .env` |
| `git status --short` | co se změnilo | `git status --short` |
| `git ls-files \| Select-String env` | co je trackované v `env/` | mělo by být prázdné |

## PowerShell konvence

| Příkaz | Co dělá | Příklad |
| --- | --- | --- |
| `. .\scripts\_common.ps1` | načte sdílené funkce | `. .\scripts\_common.ps1` |
| `Get-WorkspaceRoot` | absolutní kořen workspace | `Join-Path (Get-WorkspaceRoot) 'logs'` |
| `Write-Log -Message X -Level OK` | jednotné logování | `Write-Log -Message 'hotovo' -Level OK` |
| `Import-DotEnv` | načte `.env` do prostředí | `$cfg = Import-DotEnv` |
| `Get-MaskedValue -Value X` | zamaskuje tajemství | `Get-MaskedValue -Value $env:DEEPSEEK_API_KEY` |
| `Test-Command -Name 'node'` | ověří dostupnost nástroje | `if (Test-Command 'node') { … }` |
| `Test-Component -Name 'reasonix'` | najde komponentu v 5 režimech | `(Test-Component -Name 'reasonix').Source` |
| `Get-ComponentCatalog` | katalog komponent s kategoriemi | `(Get-ComponentCatalog).Category` |
| `Get-WorkspaceManifest` | co má workspace obsahovat | `(Get-WorkspaceManifest).Files` |
| `Invoke-ScriptAnalyzer -Path .\scripts` | statická analýza | `Invoke-ScriptAnalyzer -Path .\scripts` |

## Kontrola kvality

| Příkaz | Co dělá | Příklad |
| --- | --- | --- |
| `Invoke-ScriptAnalyzer -Path X -Severity Warning,Error` | nálezy ve skriptu | `-Path .\scripts\_common.ps1` |
| `(Get-Item X).Length` | velikost souboru v bajtech | `(Get-Item .\README.md).Length` |
| `Format-Hex -Path X \| Select -First 1` | první bajty (BOM) | `Format-Hex -Path .\scripts\_common.ps1` |
| `Get-Content X -Raw` | celý soubor jako řetězec | `(Get-Content .\VERSION -Raw).Trim()` |

## Kde co najít

| Potřebuji… | Soubor |
| --- | --- |
| rychle začít | `manual/00-quickstart.md` |
| vyřešit problém | `docs/03-TROUBLESHOOTING.md` |
| zadat agentovi práci | `prompts/README.md` |
| zkopírovat konfiguraci | `gists/snippets/` |
| pochopit strukturu | `scaffold/01-STRUCTURE.md` |
| zjistit, proč je co jak | `docs/adr/` |
