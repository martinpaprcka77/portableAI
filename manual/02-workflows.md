# 02 — Workflows

Typické scénáře od začátku do konce.

## 1. Spuštění nového projektu

**Cíl:** mít ve workspace funkční kostru projektu.

```powershell
cd C:\portableAI
pwsh -File launcher\Menu.ps1        # [1] Setup (pokud ještě neproběhl)
```

Pak agentovi vložte `prompts/01-setup.md` s vyplněnými placeholdery.

Konkrétně:

1. Rozhodněte, kam projekt patří. Uvnitř workspace je to `data/<název>/`,
   pokud projekt nemá být verzovaný spolu s workspace.
2. Nechte agenta navrhnout strukturu **před** psaním kódu.
3. Závislosti instalujte lokálně:

   ```powershell
   npm install --prefix data\<název> <balíček>
   ```

4. Ověřte, že workspace zůstal v pořádku:

   ```powershell
   pwsh -File scripts\Test-Workspace.ps1
   ```

**Kritérium hotovo:** projekt se spustí jedním příkazem a `Test-Workspace` je PASS.

## 2. Diagnostika problému

**Cíl:** najít příčinu, ne ji zamlčet.

```powershell
# 1. Zaznamenej stav
pwsh -File scripts\Get-AiStackInfo.ps1 -Json > logs\before.json

# 2. Ověř strukturu
pwsh -File scripts\Test-Workspace.ps1

# 3. Podívej se do logů
Get-ChildItem logs\*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

Pak agentovi vložte `prompts/02-diagnostics.md`. Vyžadujte tabulku
hypotéza → test → výsledek.

Po opravě:

```powershell
pwsh -File scripts\Get-AiStackInfo.ps1 -Json > logs\after.json
Compare-Object (Get-Content logs\before.json) (Get-Content logs\after.json)
```

## 3. Upgrade workspace

**Cíl:** dostat novou verzi workspace bez ztráty vlastní konfigurace.

```powershell
# 1. Zazálohuj lokální stav
Copy-Item env\.env env\.env.backup
pwsh -File scripts\Test-Workspace.ps1 -Json > logs\upgrade-before.json

# 2. Zjisti, co se bude měnit
git -C C:\portableAI status
git -C C:\portableAI diff

# 3. Aktualizuj (git)
git -C C:\portableAI pull --ff-only

# 4. Doplň nové klíče do .env (nepřepíše hodnoty)
pwsh -File scripts\Setup-DeepSeekStack.ps1 -SkipInstall

# 5. Ověř
pwsh -File scripts\Test-Workspace.ps1 -Fix
pwsh -File scripts\Get-AiStackInfo.ps1
```

Body 4 a 5 jsou důležité: `Setup -SkipInstall` doplní do `.env` jen **chybějící**
klíče ze vzoru, takže vaše hodnoty zůstanou.

Před verzí 1.0.0 (bez gitu) postupujte ručně: rozbalte novou verzi do jiné
složky, přeneste `env\.env` a `data\`, pak spusťte `Test-Workspace.ps1 -Fix`.

## 4. Export a import konfigurace

**Cíl:** přenést nastavení na jiný stroj bez klíče.

```powershell
# --- Export (bez secrets) ---
$exportDir = "logs\export-$(Get-Date -Format yyyyMMdd-HHmm)"
New-Item -Path $exportDir -ItemType Directory -Force | Out-Null
Copy-Item .vscode\settings.json      $exportDir
Copy-Item .editorconfig              $exportDir
Copy-Item env\.env.example           $exportDir
Copy-Item gists\snippets\*           $exportDir
pwsh -File scripts\Get-AiStackInfo.ps1 -Json -NoBanner > "$exportDir\snapshot.json"
```

Předání klíče řešte mimo workspace (správce hesel, šifrovaný kanál).

```powershell
# --- Import na novém stroji ---
Copy-Item <export>\* C:\portableAI\ -Recurse -Force
pwsh -File C:\portableAI\scripts\Test-Workspace.ps1 -Fix
pwsh -File C:\portableAI\scripts\Get-AiStackInfo.ps1   # DEEPSEEK_API_KEY: <nenastaveno>
```

Pak na novém stroji doplňte klíč do `env\.env`.

## 5. Přenos na USB / jiný disk

**Cíl:** workspace musí fungovat po zkopírování na jinou cestu.

```powershell
# Na zdrojovém stroji
Copy-Item C:\portableAI E:\portableAI -Recurse

# Na cíli
cd E:\portableAI
pwsh -File scripts\Test-Workspace.ps1 -Fix
pwsh -File scripts\Get-AiStackInfo.ps1
```

Když něco nefunguje, hledejte absolutní cesty:

```powershell
Get-ChildItem E:\portableAI -Recurse -File |
    Select-String -Pattern 'C:\\portableAI' |
    Select-Object Path, LineNumber, Line
```

## 6. Přidání nového AI nástroje

**Cíl:** rozšířit stack o další CLI.

1. Přidejte nástroj do `$ComponentCatalog` v `scripts/Setup-DeepSeekStack.ps1`
   (`Name`, `Package`, `Binary`, `Description`).
2. Přidejte ho do `launcher/Menu.ps1` jako novou volbu.
3. Přidejte wrapper `launcher/Launch-<Název>.cmd`.
4. Zaregistrujte ho v `Get-WorkspaceManifest` (`CmdScripts`).
5. Spusťte `Test-Workspace.ps1` — musí zůstat PASS.

## 7. Kontrola před commitem

**Cíl:** nikdy necommitnout rozbitý workspace.

```powershell
pwsh -File scripts\Test-Workspace.ps1 -Fix
pwsh -File scripts\Repair-Repo.ps1 -WhatIf
git status --short
git diff --cached
```

Do commitu nikdy nepatří `env\.env`, `logs\`, `data\` a `bin\`.
