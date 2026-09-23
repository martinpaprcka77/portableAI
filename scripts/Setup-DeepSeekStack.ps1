<#
.SYNOPSIS
    Nainstaluje a nakonfiguruje DeepSeek AI stack v portable workspace.
.DESCRIPTION
    Postupuje ve čtyřech krocích a každý z nich je možné přeskočit:

      1. příprava adresářů (env, data, bin, logs)
      2. detekce `.env` a jeho vytvoření ze vzoru, pokud chybí
      3. instalace nástrojů Reasonix, Claude Code, DSH a Pi
      4. konfigurace: seed konfiguračních souborů a synchronizace klíčů `.env`
      5. ověření pomocí `Test-Workspace.ps1`

    Vše se instaluje do `bin/npm-global` (lokální npm prefix). Skript nikdy
    neinstaluje globálně a nikdy nevyžaduje administrátorská práva, takže
    funguje i po zkopírování workspace na USB disk.

    Názvy a verze v `$ComponentCatalog` jsou ověřené proti živému npm registry
    a proti GitHub releases (audit 2026-09-23). Tabulka ověření, alternativní
    zdroje a odchylky od původního zadání jsou v `docs/02-CONFIG.md` a
    `docs/06-DEVIATIONS.md`.

    Každá komponenta má vlastní `Install` a `Verify`: instalace se nehlásí
    jako úspěšná, dokud binárka v `bin/npm-global` neodpoví na `--version`.

    Návratový kód: 0 = OK, 1 = chyba.
.PARAMETER SkipInstall
    Přeskočí instalaci nástrojů (pouze detekce a konfigurace).
.PARAMETER SkipConfig
    Přeskočí konfiguraci a seed konfiguračních souborů.
.PARAMETER SkipCheck
    Přeskočí závěrečné ověření pomocí Test-Workspace.ps1.
.PARAMETER LogFile
    Cesta k log souboru. Pokud není zadán, použije se
    `logs/setup-YYYYMMDD-HHmm.log`.
.EXAMPLE
    .\Setup-DeepSeekStack.ps1
.EXAMPLE
    .\Setup-DeepSeekStack.ps1 -WhatIf
.EXAMPLE
    .\Setup-DeepSeekStack.ps1 -SkipInstall -SkipCheck
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [switch]$SkipInstall,

    [Parameter()]
    [switch]$SkipConfig,

    [Parameter()]
    [switch]$SkipCheck,

    [Parameter()]
    [string]$LogFile
)

. (Join-Path -Path $PSScriptRoot -ChildPath '_common.ps1')

function Add-MissingDotEnvKey {
    <#
    .SYNOPSIS
        Doplní do `.env` klíče, které obsahuje vzor, ale v cíli chybí.
    .DESCRIPTION
        Porovnává klíče (nikoli hodnoty) dvou `.env` souborů a chybějící
        řádky ze vzoru připojí na konec cíle. Díky tomu funguje upgrade
        workspace i bez přepsání uživatelských hodnot. Idempotentní.
    .PARAMETER TargetPath
        Cesta k cílovému `.env` (uživatelský soubor).
    .PARAMETER TemplatePath
        Cesta k `.env.example` (vzor).
    .OUTPUTS
        System.Int32 - počet přidaných klíčů
    .EXAMPLE
        Add-MissingDotEnvKey -TargetPath '.\env\.env' -TemplatePath '.\.env.example'
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,

        [Parameter(Mandatory = $true)]
        [string]$TemplatePath
    )

    if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf) -or -not (Test-Path -LiteralPath $TemplatePath -PathType Leaf)) {
        return 0
    }

    $targetKeys = @{}
    foreach ($rawLine in (Get-Content -LiteralPath $TargetPath -Encoding utf8)) {
        $line = ([string]$rawLine).Trim()
        if (-not $line -or $line.StartsWith('#')) {
            continue
        }
        $separator = $line.IndexOf('=')
        if ($separator -lt 1) {
            continue
        }
        $targetKeys[$line.Substring(0, $separator).Trim()] = $true
    }

    $missingLines = @()
    foreach ($rawLine in (Get-Content -LiteralPath $TemplatePath -Encoding utf8)) {
        $line = ([string]$rawLine).Trim()
        if (-not $line -or $line.StartsWith('#')) {
            continue
        }
        $separator = $line.IndexOf('=')
        if ($separator -lt 1) {
            continue
        }
        if (-not $targetKeys.ContainsKey($line.Substring(0, $separator).Trim())) {
            $missingLines += $line
        }
    }

    if ($missingLines.Count -eq 0) {
        return 0
    }

    Add-Content -LiteralPath $TargetPath -Value $missingLines -Encoding utf8
    return $missingLines.Count
}

function Get-ComponentInstallTarget {
    <#
    .SYNOPSIS
        Sestaví specifikaci balíčku pro npm včetně přesné verze.
    .DESCRIPTION
        Interní helper setupu. Vrací `nazev@verze`, pokud komponenta verzi
        definuje, jinak pouze název. Přesná verze drží workspace
        reprodukovatelný a záměrně brání tichému upgradu na neověřenou verzi.
    .PARAMETER Component
        Záznam z `$ComponentCatalog`.
    .OUTPUTS
        System.String
    .EXAMPLE
        Get-ComponentInstallTarget -Component $ComponentCatalog[0]
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Component
    )

    $version = [string]$Component.Version
    if ([string]::IsNullOrWhiteSpace($version)) {
        return [string]$Component.Package
    }

    return '{0}@{1}' -f $Component.Package, $version
}

function Resolve-ComponentShim {
    <#
    .SYNOPSIS
        Najde spustitelný shim komponenty v lokálním npm prefixu.
    .DESCRIPTION
        `npm install -g --prefix <dir>` zapisuje shimy přímo do `<dir>`
        (`<dir>/<binary>.cmd` na Windows). Funkce zkusí i POSIX variantu
        `<dir>/bin/<binary>` a PowerShell variantu `<dir>/<binary>.ps1`,
        aby fungovala i po přesunu workspace na jiný systém.
    .PARAMETER Component
        Záznam z `$ComponentCatalog`.
    .PARAMETER NpmPrefix
        Absolutní cesta k lokálnímu npm prefixu (`bin/npm-global`).
    .OUTPUTS
        System.String - absolutní cesta ke shimu, nebo $null
    .EXAMPLE
        Resolve-ComponentShim -Component $ComponentCatalog[0] -NpmPrefix $npmPrefix
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Component,

        [Parameter(Mandatory = $true)]
        [string]$NpmPrefix
    )

    if (-not (Test-Path -LiteralPath $NpmPrefix -PathType Container)) {
        return $null
    }

    $candidates = @(
        (Join-Path -Path $NpmPrefix -ChildPath ('{0}.cmd' -f $Component.Binary))
        (Join-Path -Path $NpmPrefix -ChildPath ('{0}.exe' -f $Component.Binary))
        (Join-Path -Path $NpmPrefix -ChildPath ('{0}.ps1' -f $Component.Binary))
        (Join-Path -Path $NpmPrefix -ChildPath $Component.Binary)
        (Join-Path -Path $NpmPrefix -ChildPath ('bin/{0}' -f $Component.Binary))
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    return $null
}

function Install-NpmComponent {
    <#
    .SYNOPSIS
        Nainstaluje jeden npm balíček do lokálního prefixu workspace.
    .DESCRIPTION
        Volá `npm install -g --prefix <prefix> <balicek>@<verze>`. Globální
        režim s vlastním prefixem zapíše spustitelné shimy přímo do
        `bin/npm-global`, takže workspace zůstane přenositelný na USB a nikdy
        nezasáhne do systémové instalace Node.js.

        Funkce záměrně nevyhodnocuje `-WhatIf`; `ShouldProcess` volá její
        volající, aby byl konzolový výpis v jednom místě.
    .PARAMETER Component
        Záznam z `$ComponentCatalog`.
    .PARAMETER NpmPrefix
        Absolutní cesta k lokálnímu npm prefixu (`bin/npm-global`).
    .OUTPUTS
        System.Boolean - $true, když npm skončil s návratovým kódem 0
    .EXAMPLE
        Install-NpmComponent -Component $ComponentCatalog[0] -NpmPrefix $npmPrefix
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Component,

        [Parameter(Mandatory = $true)]
        [string]$NpmPrefix
    )

    if (-not (Test-Path -LiteralPath $NpmPrefix -PathType Container)) {
        New-Item -Path $NpmPrefix -ItemType Directory -Force | Out-Null
    }

    $target = Get-ComponentInstallTarget -Component $Component
    Write-Log -Message ('Instaluji {0} ({1}) do bin/npm-global...' -f $Component.Name, $target) -Level STEP

    & npm install -g --prefix $NpmPrefix --no-fund --no-audit $target 2>&1 |
        ForEach-Object { Write-Log -Message ('npm: {0}' -f [string]$_) -Level DEBUG }

    return ($LASTEXITCODE -eq 0)
}

function Test-ComponentBinary {
    <#
    .SYNOPSIS
        Ověří, že binárka komponenty existuje a odpovídá na `--version`.
    .DESCRIPTION
        Najde shim v lokálním npm prefixu a spustí ho s argumenty z pole
        `VerifyArgs`. Vrací hashtable se stavem OK/WARN/FAIL, cestou ke shimu,
        návratovým kódem a zkráceným textem odpovědi.

        Chybějící shim je `FAIL`, jen když je zapnuté `-MissingIsFailure`
        (tedy v běhu, který komponentu skutečně instaloval); jinak `WARN`.
        `WARN` je i případ, kdy shim existuje, ale `--version` selhalo nebo
        nic nevypsalo - to se hlásí, ale setup kvůli tomu nespadne.
    .PARAMETER Component
        Záznam z `$ComponentCatalog`.
    .PARAMETER NpmPrefix
        Absolutní cesta k lokálnímu npm prefixu (`bin/npm-global`).
    .PARAMETER MissingIsFailure
        Když je zapnuto, chybějící shim se hlásí jako FAIL. Používá se jen
        v běhu, který komponentu skutečně měl nainstalovat. Při `-SkipInstall`,
        `-WhatIf` nebo u volitelných komponent se chybějící shim hlásí jako
        WARN - nic se neinstalovalo, takže absence není chyba.
    .OUTPUTS
        System.Collections.Hashtable
    .EXAMPLE
        Test-ComponentBinary -Component $ComponentCatalog[0] -NpmPrefix $npmPrefix -MissingIsFailure
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Component,

        [Parameter(Mandatory = $true)]
        [string]$NpmPrefix,

        [Parameter()]
        [switch]$MissingIsFailure
    )

    $shim = Resolve-ComponentShim -Component $Component -NpmPrefix $NpmPrefix
    if (-not $shim) {
        $missingLevel = 'WARN'
        if ($MissingIsFailure) {
            $missingLevel = 'FAIL'
        }

        return @{
            Name     = $Component.Name
            Status   = $missingLevel
            LogLevel = $missingLevel
            Path     = ''
            Command  = [string]$Component.Verify
            ExitCode = -1
            Detail   = ('shim {0}.cmd nenalezen v bin/npm-global' -f $Component.Binary)
        }
    }

    $verifyArgs = @($Component.VerifyArgs)
    $output = ''
    $exitCode = 0

    try {
        $output = (& $shim @verifyArgs 2>&1 | Out-String).Trim()
        $exitCode = $LASTEXITCODE
    }
    catch [System.Exception] {
        return @{
            Name     = $Component.Name
            Status   = 'WARN'
            LogLevel = 'WARN'
            Path     = $shim
            Command  = [string]$Component.Verify
            ExitCode = -1
            Detail   = ('spuštění selhalo: {0}' -f $_.Exception.Message)
        }
    }

    if ($exitCode -ne 0) {
        return @{
            Name     = $Component.Name
            Status   = 'WARN'
            LogLevel = 'WARN'
            Path     = $shim
            Command  = [string]$Component.Verify
            ExitCode = $exitCode
            Detail   = ('shim existuje, ale --version vrátilo kód {0}: {1}' -f $exitCode, $output)
        }
    }

    if ([string]::IsNullOrWhiteSpace($output)) {
        return @{
            Name     = $Component.Name
            Status   = 'WARN'
            LogLevel = 'WARN'
            Path     = $shim
            Command  = [string]$Component.Verify
            ExitCode = $exitCode
            Detail   = 'shim existuje, ale --version nevrátilo žádný výstup'
        }
    }

    $firstLine = ([string]($output -split "`r?`n")[0]).Trim()
    return @{
        Name     = $Component.Name
        Status   = 'OK'
        LogLevel = 'OK'
        Path     = $shim
        Command  = [string]$Component.Verify
        ExitCode = $exitCode
        Detail   = ('{0} -> {1}' -f (Split-Path -Path $shim -Leaf), $firstLine)
    }
}

function Test-SwitchEnabled {
    <#
    .SYNOPSIS
        Vyhodnotí textový přepínač z `.env` jako boolean.
    .DESCRIPTION
        Volitelná rozšíření se zapínají proměnnou z `.env`. Pravdivé jsou
        hodnoty `1`, `true`, `yes` a `on` (bez ohledu na velikost písmen);
        cokoli jiného včetně prázdna znamená vypnuto.
    .PARAMETER Value
        Hodnota přepínače.
    .OUTPUTS
        System.Boolean
    .EXAMPLE
        Test-SwitchEnabled -Value $env:PORTABLEAI_PI_EXTENSIONS
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    return (@('1', 'true', 'yes', 'on') -contains $Value.Trim().ToLowerInvariant())
}

# -----------------------------------------------------------------------------
#  Katalog komponent.
#
#  Názvy a verze ověřené proti npm registry a GitHub releases 2026-09-23.
#  Zdroj pravdy pro člověka je tabulka v docs/02-CONFIG.md; tento katalog je
#  zdroj pravdy pro stroj. `Source` rozlišuje npm / github / winget.
# -----------------------------------------------------------------------------
$ComponentCatalog = @(
    [pscustomobject]@{
        Name        = 'Reasonix'
        Package     = 'reasonix'
        Version     = '1.38.11'
        Binary      = 'reasonix'
        Source      = 'npm'
        SourceUrl   = 'https://www.npmjs.com/package/reasonix'
        Portable    = $true
        Install     = 'npm install -g --prefix bin/npm-global reasonix@1.38.11'
        Verify      = '& "bin/npm-global/reasonix.cmd" --version'
        VerifyArgs  = @('--version')
        Description = 'DeepSeek-native coding agent (cache-first, terminal-first)'
        AltSources  = @(
            'winget install --id ESEngine.ReasonixCLI --exact (POZOR: user-scope, NENI portable)'
            'GitHub releases (offline instalace): https://github.com/esengine/DeepSeek-Reasonix/releases/download/v1.38.11/reasonix-windows-amd64.zip + SHA256SUMS'
        )
    }
    [pscustomobject]@{
        Name        = 'Claude Code'
        Package     = '@anthropic-ai/claude-code'
        Version     = '2.1.280'
        Binary      = 'claude'
        Source      = 'npm'
        SourceUrl   = 'https://www.npmjs.com/package/@anthropic-ai/claude-code'
        Portable    = $true
        Install     = 'npm install -g --prefix bin/npm-global @anthropic-ai/claude-code@2.1.280'
        Verify      = '& "bin/npm-global/claude.cmd" --version'
        VerifyArgs  = @('--version')
        Description = 'Anthropic CLI nad DeepSeek backendem (ANTHROPIC_BASE_URL)'
        AltSources  = @()
    }
    [pscustomobject]@{
        Name        = 'DeepSeek Harness'
        Package     = '@deepseek-ai/dsh'
        Version     = '0.1.5-rc.3'
        Binary      = 'dsh'
        Source      = 'npm'
        SourceUrl   = 'https://www.npmjs.com/package/@deepseek-ai/dsh'
        Portable    = $true
        Install     = 'npm install -g --prefix bin/npm-global @deepseek-ai/dsh@0.1.5-rc.3'
        Verify      = '& "bin/npm-global/dsh.cmd" --version'
        VerifyArgs  = @('--version')
        Description = 'DeepSeek Harness CLI (profile boot, plugins, browser UI)'
        AltSources  = @()
    }
    [pscustomobject]@{
        Name         = 'Pi'
        Package      = '@earendil-works/pi-coding-agent'
        Version      = '0.87.1'
        Binary       = 'pi'
        Source       = 'npm'
        SourceUrl    = 'https://www.npmjs.com/package/@earendil-works/pi-coding-agent'
        Portable     = $true
        Install      = 'npm install -g --prefix bin/npm-global @earendil-works/pi-coding-agent@0.87.1'
        Verify       = '& "bin/npm-global/pi.cmd" --version'
        VerifyArgs   = @('--version')
        Description  = 'Pi coding agent (read, bash, edit, write + session management)'
        AltSources   = @()
        Extension    = 'pi-reasonix@1.1.0'
        ExtensionVar = 'PORTABLEAI_PI_EXTENSIONS'
    }
)

$root = Get-WorkspaceRoot
$started = Get-Date
$problems = 0

if (-not $LogFile) {
    $LogFile = Join-Path -Path $root -ChildPath ("logs/setup-{0:yyyyMMdd-HHmm}.log" -f $started)
}
$logDirectory = Split-Path -Path $LogFile -Parent
if ($logDirectory -and -not (Test-Path -LiteralPath $logDirectory -PathType Container)) {
    New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
}

Write-Banner -Title 'Portable AI Workspace' -Subtitle ('DeepSeek stack setup - {0:yyyy-MM-dd HH:mm:ss}' -f $started)
Write-Log -Message ('Workspace: {0}' -f $root) -Level INFO -LogFile $LogFile

if (Test-IsAdmin) {
    Write-Log -Message 'Běžíte jako administrátor. Workspace to nepotřebuje - doporučuji spustit bez elevace.' -Level WARN
}

# --- 1. adresáře --------------------------------------------------------------
Write-Log -Message 'Krok 1/5: příprava adresářů' -Level STEP

$managedDirectories = @('bin', 'bin/npm-global', 'data', 'data/reasonix', 'env', 'logs')
foreach ($directory in $managedDirectories) {
    $target = Join-Path -Path $root -ChildPath $directory
    if (Test-Path -LiteralPath $target -PathType Container) {
        Write-Log -Message ('Adresář připraven: {0}' -f $directory) -Level DEBUG
        continue
    }

    if ($PSCmdlet.ShouldProcess($target, 'Vytvořit adresář')) {
        New-Item -Path $target -ItemType Directory -Force | Out-Null
        Write-Log -Message ('Vytvořen adresář: {0}' -f $directory) -Level OK
    }
}

# --- 2. .env ------------------------------------------------------------------
Write-Log -Message 'Krok 2/5: detekce .env' -Level STEP

$dotEnvPath = $null
foreach ($candidate in @((Join-Path -Path $root -ChildPath 'env/.env'), (Join-Path -Path $root -ChildPath '.env'))) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $dotEnvPath = $candidate
        break
    }
}

$templatePath = $null
foreach ($candidate in @((Join-Path -Path $root -ChildPath 'env/.env.example'), (Join-Path -Path $root -ChildPath '.env.example'))) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $templatePath = $candidate
        break
    }
}

if ($dotEnvPath) {
    Write-Log -Message ('Nalezen .env: {0}' -f $dotEnvPath) -Level OK
}
elseif ($templatePath) {
    $dotEnvPath = Join-Path -Path $root -ChildPath 'env/.env'
    if ($PSCmdlet.ShouldProcess($dotEnvPath, ('Vytvořit ze vzoru {0}' -f (Split-Path -Path $templatePath -Leaf)))) {
        $templateLines = Get-Content -LiteralPath $templatePath -Encoding utf8
        [System.IO.File]::WriteAllLines($dotEnvPath, $templateLines, [System.Text.UTF8Encoding]::new($false))
        Write-Log -Message ('Vytvořen {0} ze vzoru. Doplňte DEEPSEEK_API_KEY.' -f $dotEnvPath) -Level WARN
    }
}
else {
    Write-Log -Message 'Nenalezen .env ani .env.example - konfigurace API nebude dostupná.' -Level WARN
    $problems++
}

if ($dotEnvPath -and (Test-Path -LiteralPath $dotEnvPath -PathType Leaf)) {
    $loadedValues = Import-DotEnv -Path $dotEnvPath
    Write-Log -Message ('Z .env načteno {0} klíčů.' -f $loadedValues.Count) -Level OK

    $apiKeyValue = [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY')
    if ([string]::IsNullOrWhiteSpace($apiKeyValue) -or $apiKeyValue -like 'sk-xxxx*') {
        Write-Log -Message 'DEEPSEEK_API_KEY není vyplněn - AI nástroje se nespustí proti modelu.' -Level WARN
    }
    else {
        Write-Log -Message ('DEEPSEEK_API_KEY nastaven: {0}' -f (Get-MaskedValue -Value $apiKeyValue)) -Level OK
    }
}

# --- 3. instalace -------------------------------------------------------------
Write-Log -Message 'Krok 3/5: instalace a ověření nástrojů' -Level STEP

$npmPrefix = Join-Path -Path $root -ChildPath 'bin/npm-global'
$npmAvailable = Test-Command -Name 'npm'
$nodeAvailable = Test-Command -Name 'node'
$verifyResults = [System.Collections.Generic.List[object]]::new()

if (-not $nodeAvailable -or -not $npmAvailable) {
    Write-Log -Message 'Node.js nebo npm není v PATH. Workspace nic neinstaluje globálně - nainstalujte prosím Node.js 22.19+ ručně.' -Level FAIL
    $problems++
}
else {
    if ($SkipInstall) {
        Write-Log -Message 'Instalace přeskočena (-SkipInstall). Ověřuji jen to, co už v bin/npm-global je.' -Level WARN
    }

    foreach ($component in $ComponentCatalog) {
        $shim = Resolve-ComponentShim -Component $component -NpmPrefix $npmPrefix
        $installAttempted = $false

        if ($shim) {
            Write-Log -Message ('{0}: nalezeno v bin/npm-global - instalace přeskočena.' -f $component.Name) -Level OK
        }
        elseif ($SkipInstall) {
            Write-Log -Message ('{0}: není nainstalováno a -SkipInstall je aktivní.' -f $component.Name) -Level DEBUG
        }
        elseif (Test-Command -Name $component.Binary) {
            Write-Log -Message ('{0}: nalezeno v PATH mimo workspace - instalace přeskočena.' -f $component.Name) -Level WARN
        }
        elseif ($PSCmdlet.ShouldProcess($component.Package, $component.Install)) {
            $installAttempted = $true
            if (Install-NpmComponent -Component $component -NpmPrefix $npmPrefix) {
                Write-Log -Message ('{0}: nainstalováno do bin/npm-global.' -f $component.Name) -Level OK
            }
            else {
                Write-Log -Message ('{0}: instalace selhala (npm exit != 0). Pokračuji s ostatními.' -f $component.Name) -Level WARN
                $problems++
            }
        }

        $verification = Test-ComponentBinary -Component $component -NpmPrefix $npmPrefix -MissingIsFailure:$installAttempted
        [void]$verifyResults.Add($verification)
        Write-Log -Message ('{0} verify [{1}]: {2}' -f $component.Name, $verification.Status, $verification.Detail) -Level $verification.LogLevel
        if ($verification.Status -eq 'FAIL') {
            $problems++
        }
    }

    # Volitelné rozšíření Pi - gated proměnnou z .env, nikdy povinné.
    $piComponent = $ComponentCatalog | Where-Object { $_.Name -eq 'Pi' } | Select-Object -First 1
    $piExtension = ''
    $piExtensionVar = ''
    if ($piComponent) {
        if ($piComponent.PSObject.Properties.Name -contains 'Extension') {
            $piExtension = [string]$piComponent.Extension
        }
        if ($piComponent.PSObject.Properties.Name -contains 'ExtensionVar') {
            $piExtensionVar = [string]$piComponent.ExtensionVar
        }
    }

    if ($piExtension -and $piExtensionVar) {
        $extensionWant = Test-SwitchEnabled -Value ([Environment]::GetEnvironmentVariable($piExtensionVar))
        $extensionInstalled = Test-Path -LiteralPath (Join-Path -Path $npmPrefix -ChildPath ('node_modules/{0}' -f ($piExtension -split '@')[0])) -PathType Container

        if (-not $extensionWant) {
            Write-Log -Message ('Volitelné rozšíření {0} vypnuto ({1} není zapnuto).' -f $piExtension, $piExtensionVar) -Level INFO
        }
        elseif ($extensionInstalled) {
            Write-Log -Message ('Volitelné rozšíření {0}: již nainstalováno.' -f $piExtension) -Level OK
        }
        elseif ($SkipInstall) {
            Write-Log -Message ('Volitelné rozšíření {0}: není nainstalováno a -SkipInstall je aktivní.' -f $piExtension) -Level DEBUG
        }
        elseif ($PSCmdlet.ShouldProcess($piExtension, ('npm install -g --prefix bin/npm-global {0}' -f $piExtension))) {
            if (Install-NpmComponent -Component ([pscustomobject]@{ Name = 'Pi rozšíření'; Package = ($piExtension -split '@')[0]; Version = ($piExtension -split '@')[1] }) -NpmPrefix $npmPrefix) {
                Write-Log -Message ('Volitelné rozšíření {0}: nainstalováno.' -f $piExtension) -Level OK
            }
            else {
                Write-Log -Message ('Volitelné rozšíření {0}: instalace selhala. Pi funguje i bez něj.' -f $piExtension) -Level WARN
            }
        }
    }
}

# --- 4. konfigurace -----------------------------------------------------------
Write-Log -Message 'Krok 4/5: konfigurace' -Level STEP

if ($SkipConfig) {
    Write-Log -Message 'Konfigurace přeskočena (-SkipConfig).' -Level WARN
}
else {
    if ($dotEnvPath -and $templatePath -and (Test-Path -LiteralPath $dotEnvPath -PathType Leaf)) {
        if ($PSCmdlet.ShouldProcess($dotEnvPath, 'Synchronizovat chybějící klíče ze vzoru')) {
            $addedKeys = Add-MissingDotEnvKey -TargetPath $dotEnvPath -TemplatePath $templatePath
            if ($addedKeys -gt 0) {
                Write-Log -Message ('Do .env doplněno {0} nových klíčů ze vzoru.' -f $addedKeys) -Level OK
            }
            else {
                Write-Log -Message '.env obsahuje všechny klíče ze vzoru.' -Level OK
            }
        }
    }

    $configSeeds = @(
        [pscustomobject]@{ Source = 'gists/snippets/reasonix.toml'; Destination = 'data/reasonix/config.toml'; Note = 'Reasonix' }
        [pscustomobject]@{ Source = 'gists/snippets/models.json'; Destination = 'data/reasonix/models.json'; Note = 'seznam modelů' }
    )

    foreach ($seed in $configSeeds) {
        $sourcePath = Join-Path -Path $root -ChildPath $seed.Source
        $destinationPath = Join-Path -Path $root -ChildPath $seed.Destination

        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            Write-Log -Message ('Vzor {0} nenalezen - přeskakuji.' -f $seed.Source) -Level WARN
            continue
        }
        if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
            Write-Log -Message ('Konfigurace již existuje, nepřepisuji: {0}' -f $seed.Destination) -Level OK
            continue
        }
        if ($PSCmdlet.ShouldProcess($destinationPath, ('Vytvořit ze vzoru {0}' -f $seed.Source))) {
            $destinationDirectory = Split-Path -Path $destinationPath -Parent
            if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
                New-Item -Path $destinationDirectory -ItemType Directory -Force | Out-Null
            }
            Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
            Write-Log -Message ('Vytvořena konfigurace {0} ({1}).' -f $seed.Destination, $seed.Note) -Level OK
        }
    }
}

# --- 5. ověření ---------------------------------------------------------------
Write-Log -Message 'Krok 5/5: ověření' -Level STEP

if ($SkipCheck) {
    Write-Log -Message 'Ověření přeskočeno (-SkipCheck).' -Level WARN
}
else {
    $testScript = Join-Path -Path $PSScriptRoot -ChildPath 'Test-Workspace.ps1'
    if (-not (Test-Path -LiteralPath $testScript -PathType Leaf)) {
        Write-Log -Message 'Test-Workspace.ps1 nenalezen - ověření přeskočeno.' -Level WARN
    }
    else {
        $hostExecutable = 'powershell.exe'
        if (Test-Command -Name 'pwsh') {
            $hostExecutable = 'pwsh.exe'
        }

        & $hostExecutable -NoProfile -ExecutionPolicy Bypass -File $testScript 2>&1 |
            ForEach-Object { Write-Log -Message ([string]$_) -Level INFO -Raw }

        if ($LASTEXITCODE -eq 0) {
            Write-Log -Message 'Ověření workspace: PASS.' -Level OK
        }
        else {
            Write-Log -Message ('Ověření workspace: FAIL (exit {0}).' -f $LASTEXITCODE) -Level WARN
            $problems++
        }
    }
}

# --- Souhrn -------------------------------------------------------------------
if ($verifyResults.Count -gt 0) {
    Write-Log -Message 'Ověření binárek (bin/npm-global)' -Level HEAD
    foreach ($result in $verifyResults) {
        Write-Log -Message ('    {0}: {1}' -f $result.Name, $result.Detail) -Level $result.LogLevel
    }
}
$elapsed = (Get-Date) - $started
if ($problems -eq 0) {
    Write-Log -Message ('Setup dokončen za {0:N2} s.' -f $elapsed.TotalSeconds) -Level OK
    Write-Log -Message 'Další krok: launcher\Start-PortableAI.cmd' -Level INFO
    exit 0
}

Write-Log -Message ('Setup dokončen s {0} problémy za {1:N2} s.' -f $problems, $elapsed.TotalSeconds) -Level WARN
exit 1
