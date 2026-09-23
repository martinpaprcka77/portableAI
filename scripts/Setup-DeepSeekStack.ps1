<#
.SYNOPSIS
    Nainstaluje a nakonfiguruje DeepSeek AI stack v portable workspace.
.DESCRIPTION
    Postupuje v pěti krocích a každý z nich je možné přeskočit:

      1. příprava adresářů (env, data, bin, logs)
      2. detekce `.env` a jeho vytvoření ze vzoru, pokud chybí
      3. instalace nástrojů Reasonix, Pi, Claude Code a DSH
      4. konfigurace: seed konfiguračních souborů a synchronizace klíčů `.env`
      5. ověření pomocí `Test-Workspace.ps1`

    Vše se instaluje do `bin/npm-global` (lokální npm prefix). Skript nikdy
    neinstaluje globálně a nikdy nevyžaduje administrátorská práva, takže
    funguje i po zkopírování workspace na USB disk.

    Komponenty mají kategorie z `Get-ComponentCatalog` (viz `scripts/_common.ps1`):

      Required      - `reasonix`; musí být vždy ve workspace
      Recommended   - `pi`; instaluje se, pokud není `-SkipOptional`
      Optional      - `claude`, `dsh`; jen na výslovné vyžádání
                      (`-InstallOptional`)

    Nalezení nástroje v globálním `PATH` **není** důvod instalaci přeskočit:
    bez parametrů se každá vybraná komponenta instaluje do `bin/npm-global`,
    i když je zároveň nainstalovaná globálně (oprava Bug #2 - dřív se
    instalace přeskočila a workspace pak nefungoval po přesunu na jiný stroj).
    Kdo chce globální instalaci vědomě použít, zapne `-UseGlobalIfPresent`.

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
.PARAMETER SkipOptional
    Přeskočí komponenty kategorie `Recommended` (tedy `pi`) i `Optional`.
    `reasonix` (`Required`) se instaluje vždy.
.PARAMETER InstallOptional
    Názvy komponent kategorie `Optional`, které se mají přesto nainstalovat.
    Přijímá `DisplayName`, `Name`, `Binary` i `Package` (bez ohledu na
    velikost písmen), např. `-InstallOptional claude,dsh`.
.PARAMETER UseGlobalIfPresent
    Když je komponenta nalezena mimo workspace (globální npm nebo `PATH`),
    použije se tato globální instalace a jen se to ohlásí jako `WARN`.
    Bez tohoto přepínače se komponenta vždy doinstaluje do `bin/npm-global`,
    protože globální instalace není přenositelná.
.PARAMETER LogFile
    Cesta k log souboru. Pokud není zadán, použije se
    `logs/setup-YYYYMMDD-HHmm.log`.
.EXAMPLE
    .\Setup-DeepSeekStack.ps1
.EXAMPLE
    .\Setup-DeepSeekStack.ps1 -WhatIf
.EXAMPLE
    .\Setup-DeepSeekStack.ps1 -SkipInstall -SkipCheck
.EXAMPLE
    .\Setup-DeepSeekStack.ps1 -SkipOptional
.EXAMPLE
    .\Setup-DeepSeekStack.ps1 -InstallOptional claude
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
    [switch]$SkipOptional,

    [Parameter()]
    [string[]]$InstallOptional = @(),

    [Parameter()]
    [switch]$UseGlobalIfPresent,

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

        Vlastní hledání deleguje na `Get-ComponentShimPath` v `_common.ps1`,
        aby stejný seznam kandidátů používala i detekce `Test-Component`.
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

    return Get-ComponentShimPath -Directory $NpmPrefix -Binary ([string]$Component.Binary)
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
    .PARAMETER AdditionalArgs
        Další argumenty pro `npm install` (např. `--ignore-scripts`
        nebo `--legacy-peer-deps`) vložené před názvem balíčku.
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
        [string]$NpmPrefix,

        [Parameter()]
        [string[]]$AdditionalArgs = @()
    )

    if (-not (Test-Path -LiteralPath $NpmPrefix -PathType Container)) {
        New-Item -Path $NpmPrefix -ItemType Directory -Force | Out-Null
    }

    $target = Get-ComponentInstallTarget -Component $Component
    Write-Log -Message ('Instaluji {0} ({1}) do bin/npm-global...' -f $Component.Name, $target) -Level STEP

    $npmArguments = @('install', '-g', '--prefix', $NpmPrefix, '--no-fund', '--no-audit')
    foreach ($extraArgument in @($AdditionalArgs)) {
        if (-not [string]::IsNullOrWhiteSpace($extraArgument)) {
            $npmArguments += $extraArgument
        }
    }
    $npmArguments += $target

    & npm @npmArguments 2>&1 |
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
#  Definice je v `Get-ComponentCatalog` ve `scripts/_common.ps1`, aby stejná
#  data (kategorie, verze, binárky) používal setup, diagnostika i self-test.
#  Zdroj pravdy pro člověka je tabulka v docs/02-CONFIG.md.
# -----------------------------------------------------------------------------

$ComponentCatalog = Get-ComponentCatalog

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

# Původ klíče zjišťujeme PŘED Import-DotEnv - ten plní Process scope, takže by
# se po načtení jako zdroj jevil vždy "Process".
$preLoadKeyScopes = [ordered]@{
    Process = [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY', 'Process')
    User    = [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY', 'User')
    Machine = [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY', 'Machine')
}

if ($dotEnvPath -and (Test-Path -LiteralPath $dotEnvPath -PathType Leaf)) {
    $loadedValues = Import-DotEnv -Path $dotEnvPath
    Write-Log -Message ('Z .env načteno {0} klíčů.' -f $loadedValues.Count) -Level OK

    $keySource = Get-EnvValueSource -Name 'DEEPSEEK_API_KEY' -DotEnvValues $loadedValues -ProcessValue ([string]$preLoadKeyScopes['Process'])
    $dotEnvKeyValue = if ($loadedValues.ContainsKey('DEEPSEEK_API_KEY')) { [string]$loadedValues['DEEPSEEK_API_KEY'] } else { '' }

    if ($keySource.Found -and $keySource.Source -ne '.env') {
        # Klíč je v prostředí (Process/User/Machine) - env má přednost, do .env se nezasahuje.
        Write-Log -Message ('DEEPSEEK_API_KEY nalezen v prostředí ({0}) - .env se neaktualizuje.' -f $keySource.Source) -Level OK
        Write-Log -Message ('  klíč z prostředí: {0}' -f (Get-MaskedValue -Value $keySource.Value)) -Level OK
        if (-not [string]::IsNullOrWhiteSpace($dotEnvKeyValue) -and $dotEnvKeyValue -like 'sk-xxxx*') {
            Write-Log -Message '  v .env zůstává jen placeholder - můžete ho nechat zakomentovaný.' -Level INFO
        }
        elseif (-not [string]::IsNullOrWhiteSpace($dotEnvKeyValue) -and $dotEnvKeyValue -cne $keySource.Value) {
            Write-Log -Message '  DEEPSEEK_API_KEY je i v .env, ale klíč v env přebíjí .env (hodnota se liší).' -Level INFO
        }
    }
    elseif ([string]::IsNullOrWhiteSpace($dotEnvKeyValue) -or $dotEnvKeyValue -like 'sk-xxxx*') {
        Write-Log -Message 'DEEPSEEK_API_KEY není vyplněn - AI nástroje se nespustí proti modelu.' -Level WARN
    }
    else {
        Write-Log -Message ('DEEPSEEK_API_KEY nastaven z .env: {0}' -f (Get-MaskedValue -Value $dotEnvKeyValue)) -Level OK
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

    # `pwsh -File` předá `-InstallOptional claude,dsh` jako jediný řetězec, proto
    # se hodnoty dělí i na čárkách - funguje tak volání z PowerShellu i z .cmd.
    $requestedOptional = @()
    foreach ($requestedName in @($InstallOptional)) {
        foreach ($part in ([string]$requestedName -split ',')) {
            $normalizedName = $part.Trim()
            if ($normalizedName) {
                $requestedOptional += $normalizedName.ToLowerInvariant()
            }
        }
    }

    $piComponentSelected = $false

    foreach ($component in $ComponentCatalog) {
        $category = [string]$component.Category
        $installAttempted = $false

        # Výběr podle kategorie: Required vždy, Recommended bez -SkipOptional,
        # Optional jen když ho uživatel vyjmenoval v -InstallOptional.
        $selected = $true
        if ($category -eq 'Recommended') {
            $selected = -not $SkipOptional
        }
        elseif ($category -eq 'Optional') {
            $aliases = @($component.DisplayName, $component.Name, $component.Binary, $component.Package) |
                ForEach-Object { ([string]$_).Trim().ToLowerInvariant() }
            $selected = @($aliases | Where-Object { $requestedOptional -contains $_ }).Count -gt 0
        }

        if ($component.PSObject.Properties.Name -contains 'Extension') {
            $piComponentSelected = [bool]$selected
        }

        # Nalezení nástroje mimo workspace NENÍ důvod instalaci přeskočit -
        # workspace musí být soběstačný i po přesunu na jiný stroj (Bug #2).
        $detection = Test-Component -Name ([string]$component.Binary) -Root $root -SkipVersion
        $installNow = $false

        if ($detection.Portable) {
            Write-Log -Message ('{0} [{1}]: nalezeno v workspace ({2}) - instalace přeskočena.' -f $component.DisplayName, $category, $detection.Source) -Level OK
        }
        elseif (-not $selected) {
            Write-Log -Message ('{0} [{1}]: kategorie není vyžádána (-SkipOptional / -InstallOptional) - přeskakuji.' -f $component.DisplayName, $category) -Level INFO
        }
        elseif ($detection.Found -and $UseGlobalIfPresent) {
            Write-Log -Message ('{0} [{1}]: použita globální instalace ({2}: {3}) - NENÍ přenositelná.' -f $component.DisplayName, $category, $detection.Source, $detection.Path) -Level WARN
        }
        elseif ($SkipInstall) {
            Write-Log -Message ('{0} [{1}]: není ve workspace a -SkipInstall je aktivní.' -f $component.DisplayName, $category) -Level DEBUG
        }
        else {
            if ($detection.Found) {
                Write-Log -Message ('{0} [{1}]: nalezeno mimo workspace ({2}: {3}) - instaluji do bin/npm-global.' -f $component.DisplayName, $category, $detection.Source, $detection.Path) -Level WARN
            }
            $installNow = $true
        }

        if ($installNow -and $PSCmdlet.ShouldProcess($component.Package, $component.Install)) {
            $installAttempted = $true
            if (Install-NpmComponent -Component $component -NpmPrefix $npmPrefix) {
                Write-Log -Message ('{0}: nainstalováno do bin/npm-global.' -f $component.DisplayName) -Level OK
            }
            else {
                Write-Log -Message ('{0}: instalace selhala (npm exit != 0). Pokračuji s ostatními.' -f $component.DisplayName) -Level WARN
                $problems++
            }
        }

        $verification = Test-ComponentBinary -Component $component -NpmPrefix $npmPrefix -MissingIsFailure:$installAttempted
        [void]$verifyResults.Add($verification)
        Write-Log -Message ('{0} verify [{1}]: {2}' -f $component.DisplayName, $verification.Status, $verification.Detail) -Level $verification.LogLevel
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

    if ($piExtension -and $piExtensionVar -and -not $piComponentSelected) {
        Write-Log -Message ('Volitelné rozšíření {0}: komponenta Pi není vybrána (-SkipOptional) - přeskakuji.' -f $piExtension) -Level INFO
    }
    elseif ($piExtension -and $piExtensionVar) {
        $extensionWant = Test-SwitchEnabled -Value ([Environment]::GetEnvironmentVariable($piExtensionVar))
        # Přítomnost adresáře nestačí - neúspěšná instalace po sobě zanechá
        # prázdný skeleton. Rozhoduje až `package.json` balíčku.
        $extensionInstalled = Test-Path -LiteralPath (Join-Path -Path $npmPrefix -ChildPath ('node_modules/{0}/package.json' -f ($piExtension -split '@')[0])) -PathType Leaf

        if (-not $extensionWant) {
            Write-Log -Message ('Volitelné rozšíření {0} vypnuto ({1} není zapnuto).' -f $piExtension, $piExtensionVar) -Level INFO
        }
        elseif ($extensionInstalled) {
            Write-Log -Message ('Volitelné rozšíření {0}: již nainstalováno.' -f $piExtension) -Level OK
        }
        elseif ($SkipInstall) {
            Write-Log -Message ('Volitelné rozšíření {0}: není nainstalováno a -SkipInstall je aktivní.' -f $piExtension) -Level DEBUG
        }
        elseif ($PSCmdlet.ShouldProcess($piExtension, ('npm install -g --prefix bin/npm-global --ignore-scripts --legacy-peer-deps {0}' -f $piExtension))) {
            # `--ignore-scripts`: pi-reasonix má postinstall `npm run build || true`,
            # který na Windows selže (tsc bez tsconfig.json, `|| true` není cmd
            # příkaz) - přestože balíček už veze předpřipravený `dist/`.
            # `--legacy-peer-deps`: peer závislosti jsou volné (`*`) a npm by kvůli
            # nim stahoval druhou celou kopii Pi agenta do vnořeného node_modules.
            # Rozšíření na ně v runtime nesahá (importuje jen relativní cesty).
            $extensionArguments = @('--ignore-scripts', '--legacy-peer-deps')
            if (Install-NpmComponent -Component ([pscustomobject]@{ Name = 'Pi rozšíření'; Package = ($piExtension -split '@')[0]; Version = ($piExtension -split '@')[1] }) -NpmPrefix $npmPrefix -AdditionalArgs $extensionArguments) {
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
