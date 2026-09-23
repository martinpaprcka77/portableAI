<#
.SYNOPSIS
    Interaktivní rozcestník portable AI workspace.
.DESCRIPTION
    Zobrazí menu a spouští ostatní skripty workspace s načteným `.env` a
    lokálním npm prefixem na začátku `PATH`.

    S parametrem -Action běží neinteraktivně: provede jednu akci a skončí.
    Toho využívají wrappery `launcher\Launch-*.cmd`.

    Menu vrací vždy návratový kód 0 — díky tomu fallback na Windows
    PowerShell v `Start-PortableAI.cmd` nespustí menu dvakrát.
.PARAMETER Action
    Akce pro neinteraktivní režim. Bez tohoto parametru se zobrazí menu.
.PARAMETER NoBanner
    Potlačí ASCII banner.
.EXAMPLE
    .\Menu.ps1
.EXAMPLE
    .\Menu.ps1 -Action diagnostics
.EXAMPLE
    pwsh -File launcher\Menu.ps1 -Action test
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('setup', 'diagnostics', 'test', 'repair', 'reasonix', 'claude', 'dsh', 'pi', 'landing', 'docs')]
    [string]$Action,

    [Parameter()]
    [switch]$NoBanner
)

. (Join-Path -Path $PSScriptRoot -ChildPath '../scripts/_common.ps1')

function Initialize-LauncherEnvironment {
    <#
    .SYNOPSIS
        Připraví prostředí pro spouštěné nástroje.
    .DESCRIPTION
        Načte `env\.env` do proměnných prostředí a přidá lokální npm prefix
        na začátek `PATH`. Nástroje se instalují příkazem
        `npm install -g --prefix bin/npm-global`, takže spustitelné shimy
        leží přímo v `bin\npm-global`; `bin\npm-global\node_modules\.bin`
        zůstává v `PATH` kvůli balíčkům nainstalovaným v lokálním režimu.
        Díky tomu nástroje nainstalované ve workspace fungují bez globální
        instalace. Operace je idempotentní.
    .EXAMPLE
        Initialize-LauncherEnvironment
    #>
    [CmdletBinding()]
    param()

    $root = Get-WorkspaceRoot

    $toolPaths = @(
        (Join-Path -Path $root -ChildPath 'bin/npm-global')
        (Join-Path -Path $root -ChildPath 'bin/npm-global/node_modules/.bin')
    )

    foreach ($toolBin in $toolPaths) {
        if (-not (Test-Path -LiteralPath $toolBin -PathType Container)) {
            continue
        }
        if ($env:PATH -like "*$toolBin*") {
            continue
        }

        $env:PATH = '{0}{1}{2}' -f $toolBin, [System.IO.Path]::PathSeparator, $env:PATH
        Write-Log -Message ('PATH rozšířena o lokální nástroje: {0}' -f $toolBin) -Level DEBUG
    }

    $dotEnvPath = $null
    foreach ($candidate in @((Join-Path -Path $root -ChildPath 'env/.env'), (Join-Path -Path $root -ChildPath '.env'))) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $dotEnvPath = $candidate
            break
        }
    }

    if ($dotEnvPath) {
        $null = Import-DotEnv -Path $dotEnvPath
    }
    else {
        Write-Log -Message 'Chybí env\.env - AI nástroje nebudou mít API klíč. Spusťte [1] Setup.' -Level WARN
    }
}

function Invoke-WorkspaceScript {
    <#
    .SYNOPSIS
        Spustí skript workspace v samostatném procesu.
    .DESCRIPTION
        Skript se spouští v novém procesu PowerShellu, aby jeho `exit`
        neukončil menu a aby měl čisté prostředí. Preferuje se `pwsh.exe`,
        s fallbackem na Windows PowerShell 5.1.
    .PARAMETER RelativePath
        Cesta ke skriptu relativní ke kořeni workspace.
    .EXAMPLE
        Invoke-WorkspaceScript -RelativePath 'scripts/Get-AiStackInfo.ps1'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$RelativePath
    )

    $scriptPath = Join-Path -Path (Get-WorkspaceRoot) -ChildPath $RelativePath
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        Write-Log -Message ('Skript nenalezen: {0}' -f $RelativePath) -Level FAIL
        return
    }

    $hostExecutable = 'powershell.exe'
    if (Test-Command -Name 'pwsh') {
        $hostExecutable = 'pwsh.exe'
    }

    Write-Log -Message ('Spouštím {0}' -f $RelativePath) -Level STEP
    & $hostExecutable -NoProfile -ExecutionPolicy Bypass -File $scriptPath
    Write-Log -Message ('Dokončeno: {0}' -f $RelativePath) -Level OK
}

function Invoke-AgentTool {
    <#
    .SYNOPSIS
        Spustí AI agenta v aktuálním prostředí workspace.
    .DESCRIPTION
        Ověří, že je nástroj dostupný v `PATH`, a spustí ho interaktivně.
        Když nástroj chybí, vypíše srozumitelný návod místo chyby.
    .PARAMETER Name
        Název spouštěného nástroje (reasonix, claude, dsh, pi).
    .EXAMPLE
        Invoke-AgentTool -Name 'reasonix'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name
    )

    if (-not (Test-Command -Name $Name)) {
        Write-Log -Message ('Nástroj {0} není v PATH.' -f $Name) -Level WARN
        Write-Log -Message 'Spusťte [1] Setup nebo nainstalujte nástroj ručně.' -Level INFO
        return
    }

    Write-Log -Message ('Spouštím {0}...' -f $Name) -Level STEP
    & $Name
}

function Open-WorkspaceItem {
    <#
    .SYNOPSIS
        Otevře soubor workspace ve výchozí aplikaci systému.
    .DESCRIPTION
        Používá se pro landing page a dokumentaci. Cesta se ověřuje, aby
        otevírání neexistujícího souboru neskončilo systémovou chybou.
    .PARAMETER RelativePath
        Cesta k souboru relativní ke kořeni workspace.
    .EXAMPLE
        Open-WorkspaceItem -RelativePath 'landing/index.html'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$RelativePath
    )

    $itemPath = Join-Path -Path (Get-WorkspaceRoot) -ChildPath $RelativePath
    if (-not (Test-Path -LiteralPath $itemPath -PathType Leaf)) {
        Write-Log -Message ('Soubor nenalezen: {0}' -f $RelativePath) -Level WARN
        return
    }

    Write-Log -Message ('Otevírám {0}' -f $RelativePath) -Level STEP
    Start-Process -FilePath $itemPath
}

function Show-PortableAiMenu {
    <#
    .SYNOPSIS
        Vypíše volby interaktivního menu.
    .DESCRIPTION
        Drží nabídku na jednom místě, aby se položky menu a obsluha voleb
        nemohly rozejít.
    .EXAMPLE
        Show-PortableAiMenu
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interaktivní menu je konzolová záležitost; Write-Host formátuje volby.')]
    [CmdletBinding()]
    param()

    $hostExecutable = 'powershell.exe'
    if (Test-Command -Name 'pwsh') {
        $hostExecutable = 'pwsh.exe'
    }

    Write-Host ('  Host: {0} | Workspace: {1}' -f $hostExecutable, (Get-WorkspaceRoot))
    Write-Host ''
    Write-Host '  [1] Setup (instalace nástrojů)'
    Write-Host '  [2] Diagnostics (Get-AiStackInfo)'
    Write-Host '  [3] Test workspace'
    Write-Host '  [4] Repair repo'
    Write-Host '  [5] Launch Reasonix'
    Write-Host '  [6] Launch Claude Code'
    Write-Host '  [7] Launch DSH'
    Write-Host '  [8] Open landing page'
    Write-Host '  [9] Open documentation'
    Write-Host '  [0] Exit'
    Write-Host ''
}

$actions = [ordered]@{
    'setup'       = { Invoke-WorkspaceScript -RelativePath 'scripts/Setup-DeepSeekStack.ps1' }
    'diagnostics' = { Invoke-WorkspaceScript -RelativePath 'scripts/Get-AiStackInfo.ps1' }
    'test'        = { Invoke-WorkspaceScript -RelativePath 'scripts/Test-Workspace.ps1' }
    'repair'      = { Invoke-WorkspaceScript -RelativePath 'scripts/Repair-Repo.ps1' }
    'reasonix'    = { Invoke-AgentTool -Name 'reasonix' }
    'claude'      = { Invoke-AgentTool -Name 'claude' }
    'dsh'         = { Invoke-AgentTool -Name 'dsh' }
    'pi'          = { Invoke-AgentTool -Name 'pi' }
    'landing'     = { Open-WorkspaceItem -RelativePath 'landing/index.html' }
    'docs'        = { Open-WorkspaceItem -RelativePath 'docs/00-OVERVIEW.md' }
}

Initialize-LauncherEnvironment

if ($Action) {
    Write-Log -Message ('Neinteraktivní režim: {0}' -f $Action) -Level INFO
    & $actions[$Action]
    exit 0
}

$choiceToAction = [ordered]@{
    '1' = 'setup'
    '2' = 'diagnostics'
    '3' = 'test'
    '4' = 'repair'
    '5' = 'reasonix'
    '6' = 'claude'
    '7' = 'dsh'
    '8' = 'landing'
    '9' = 'docs'
}

$running = $true
$versionPath = Join-Path -Path (Get-WorkspaceRoot) -ChildPath 'VERSION'
$workspaceVersion = 'neznámá'
if (Test-Path -LiteralPath $versionPath -PathType Leaf) {
    $workspaceVersion = (Get-Content -LiteralPath $versionPath -Raw).Trim()
}

while ($running) {
    Write-Banner -Title 'Portable AI Workspace' -Subtitle ('verze {0}' -f $workspaceVersion) -NoBanner:$NoBanner
    Show-PortableAiMenu

    $choice = Read-Host '  Volba'
    if ([string]::IsNullOrWhiteSpace($choice)) {
        continue
    }
    $choice = $choice.Trim()

    if ($choice -eq '0') {
        Write-Log -Message 'Ukončuji portable AI workspace.' -Level INFO
        $running = $false
        continue
    }

    if (-not $choiceToAction.Contains($choice)) {
        Write-Log -Message ('Neznámá volba: {0}' -f $choice) -Level WARN
        continue
    }

    $selectedAction = $choiceToAction[$choice]
    Write-Log -Message ('--- akce: {0} ---' -f $selectedAction) -Level HEAD
    & $actions[$selectedAction]

    [void](Read-Host '  Pokračujte stisknutím Enter')
    Write-Log -Message ''
}

exit 0
