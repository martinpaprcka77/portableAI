<#
.SYNOPSIS
    Vypíše diagnostický snapshot portable AI workspace a jeho okolí.
.DESCRIPTION
    Projde osm sekcí (systém, PowerShell, cesty, adresáře, env, API, AI nástroje,
    doctor) a vytvoří lidsky čitelný přehled nebo strojově čitelný JSON.

    Skript je read-only: nic neinstaluje, nic nekonfiguruje a nemění soubory.
    Jediný vedlejší efekt je načtení `.env` do proměnných prostředí aktuálního
    procesu (aby diagnostika viděla stejné hodnoty jako běžící nástroje).

    Návratový kód: 0 = OK nebo WARN, 1 = FAIL (chybí povinné soubory/adresáře).
.PARAMETER Json
    Vypíše strukturovaný JSON místo barevného lidského výstupu. Logy do konzole
    jsou potlačeny, aby JSON zůstal validní.
.PARAMETER LogFile
    Cesta k log souboru. Pokud není zadán, skript do souboru neloguje.
.PARAMETER NoBanner
    Potlačí ASCII banner.
.PARAMETER NoColor
    Vypne barevný výstup.
.EXAMPLE
    .\Get-AiStackInfo.ps1
.EXAMPLE
    .\Get-AiStackInfo.ps1 -Json | Set-Content -Path ..\logs\snapshot.json -Encoding utf8
.EXAMPLE
    .\Get-AiStackInfo.ps1 -LogFile ..\logs\doctor.log -NoBanner
#>
[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Json,

    [Parameter()]
    [string]$LogFile,

    [Parameter()]
    [switch]$NoBanner,

    [Parameter()]
    [switch]$NoColor
)

. (Join-Path -Path $PSScriptRoot -ChildPath '_common.ps1')

$script:PortableAiNoColor = [bool]$NoColor

function Add-ReportEntry {
    <#
    .SYNOPSIS
        Přidá do sekce reportu jednu položku se stavem a hodnotou.
    .DESCRIPTION
        Interní helper diagnostiky. Položky mají jednotný tvar
        `@{ Status; Value }`, takže se stejná struktura dá vypsat lidsky
        i serializovat do JSON.
    .PARAMETER Section
        OrderedDictionary reprezentující sekci reportu.
    .PARAMETER Name
        Název položky.
    .PARAMETER Status
        Stav položky: OK, WARN, FAIL nebo INFO.
    .PARAMETER Value
        Textová hodnota položky.
    .EXAMPLE
        Add-ReportEntry -Section $section -Name 'Node' -Status 'OK' -Value 'v24.19.0'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Section,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet('OK', 'WARN', 'FAIL', 'INFO')]
        [string]$Status,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Value = ''
    )

    $Section[$Name] = [ordered]@{
        Status = $Status
        Value  = $Value
    }
}

function Get-ToolVersion {
    <#
    .SYNOPSIS
        Zjistí verzi externího nástroje bezpečným spuštěním.
    .DESCRIPTION
        Spustí nástroj s argumentem pro verzi a vrátí první řádek výstupu.
        Nikdy nevyhodí výjimku - při jakémkoli problému vrátí 'neznámá'.
        Používá se pouze pro nástroje, u kterých je bezpečné je volat bez
        interakce (node, npm, git, pwsh).
    .PARAMETER Name
        Název příkazu.
    .OUTPUTS
        System.String
    .EXAMPLE
        Get-ToolVersion -Name 'node'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name
    )

    try {
        $raw = & $Name '--version' 2>&1 | Select-Object -First 1
        if ($null -eq $raw) {
            return 'neznámá'
        }

        return ([string]$raw).Trim()
    }
    catch {
        Write-Log -Message ("Verzi nástroje '{0}' nelze zjistit: {1}" -f $Name, $_.Exception.Message) -Level DEBUG
        return 'neznámá'
    }
}

$root = Get-WorkspaceRoot
$manifest = Get-WorkspaceManifest
$report = [ordered]@{}
$started = Get-Date

if ($LogFile) {
    $logDirectory = Split-Path -Path $LogFile -Parent
    if ($logDirectory -and -not (Test-Path -LiteralPath $logDirectory -PathType Container)) {
        New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
    }
}

if (-not $Json) {
    Write-Banner -Title 'Portable AI Workspace' -Subtitle ('Diagnostics - {0:yyyy-MM-dd HH:mm:ss}' -f $started) -NoBanner:$NoBanner
}

Write-Log -Message 'Start diagnostiky' -Level STEP -LogFile $LogFile -Quiet:$Json

# --- Sekce 1: systém ----------------------------------------------------------
Write-Log -Message 'Sekce 1/8: systém' -Level DEBUG

$osCaption = [string]$env:OS
try {
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $osCaption = '{0} (build {1})' -f $osInfo.Caption, $osInfo.BuildNumber
}
catch {
    Write-Log -Message ('WMI informace o OS nedostupné: {0}' -f $_.Exception.Message) -Level DEBUG
    $osCaption = [System.Environment]::OSVersion.VersionString
}

$isAdmin = Test-IsAdmin
$systemSection = [ordered]@{}
Add-ReportEntry -Section $systemSection -Name 'Operační systém' -Status 'INFO' -Value $osCaption
Add-ReportEntry -Section $systemSection -Name 'Verze jádra' -Status 'INFO' -Value ([System.Environment]::OSVersion.VersionString)
Add-ReportEntry -Section $systemSection -Name 'Architektura' -Status 'INFO' -Value ([string]$env:PROCESSOR_ARCHITECTURE)
Add-ReportEntry -Section $systemSection -Name 'Počítač' -Status 'INFO' -Value ([string]$env:COMPUTERNAME)
Add-ReportEntry -Section $systemSection -Name 'Uživatel' -Status 'INFO' -Value ([string]$env:USERNAME)
Add-ReportEntry -Section $systemSection -Name 'Kultura' -Status 'INFO' -Value ([System.Globalization.CultureInfo]::CurrentCulture.Name)
Add-ReportEntry -Section $systemSection -Name 'Elevated (admin)' -Status $(if ($isAdmin) { 'WARN' } else { 'OK' }) -Value $(if ($isAdmin) { 'ano (workspace admin nepotřebuje)' } else { 'ne (správně)' })
$report['1. Systém'] = $systemSection

# --- Sekce 2: PowerShell ------------------------------------------------------
Write-Log -Message 'Sekce 2/8: PowerShell' -Level DEBUG

$psSection = [ordered]@{}
Add-ReportEntry -Section $psSection -Name 'Verze' -Status 'INFO' -Value $PSVersionTable.PSVersion.ToString()
Add-ReportEntry -Section $psSection -Name 'Edice' -Status 'INFO' -Value ([string]$PSVersionTable.PSEdition)
Add-ReportEntry -Section $psSection -Name 'Host' -Status 'INFO' -Value ('{0} {1}' -f $Host.Name, $Host.Version)
Add-ReportEntry -Section $psSection -Name 'PSHome' -Status 'INFO' -Value $PSHome
Add-ReportEntry -Section $psSection -Name 'Proces 64-bit' -Status 'INFO' -Value ([string][Environment]::Is64BitProcess)
Add-ReportEntry -Section $psSection -Name 'LanguageMode' -Status 'INFO' -Value ([string]$ExecutionContext.SessionState.LanguageMode)

$executionPolicy = 'neznámá'
try {
    $executionPolicy = (Get-ExecutionPolicy).ToString()
}
catch [System.Management.Automation.RuntimeException] {
    Write-Log -Message 'ExecutionPolicy nelze přečíst (constrained language mode).' -Level DEBUG
}
Add-ReportEntry -Section $psSection -Name 'ExecutionPolicy' -Status 'INFO' -Value $executionPolicy

$pwshAvailable = Test-Command -Name 'pwsh'
Add-ReportEntry -Section $psSection -Name 'pwsh v PATH' -Status $(if ($pwshAvailable) { 'OK' } else { 'WARN' }) -Value $(if ($pwshAvailable) { 'ano' } else { 'ne - launcher použije Windows PowerShell 5.1' })
$report['2. PowerShell'] = $psSection

# --- Sekce 3: cesty -----------------------------------------------------------
Write-Log -Message 'Sekce 3/8: cesty' -Level DEBUG

$pathsSection = [ordered]@{}
Add-ReportEntry -Section $pathsSection -Name 'Workspace root' -Status 'OK' -Value $root
Add-ReportEntry -Section $pathsSection -Name 'Skripty' -Status 'INFO' -Value $PSScriptRoot
Add-ReportEntry -Section $pathsSection -Name 'Aktuální adresář' -Status 'INFO' -Value (Get-Location).Path
Add-ReportEntry -Section $pathsSection -Name 'USERPROFILE' -Status 'INFO' -Value ([string]$env:USERPROFILE)
Add-ReportEntry -Section $pathsSection -Name 'LOCALAPPDATA' -Status 'INFO' -Value ([string]$env:LOCALAPPDATA)
Add-ReportEntry -Section $pathsSection -Name 'TEMP' -Status 'INFO' -Value ([System.IO.Path]::GetTempPath())
Add-ReportEntry -Section $pathsSection -Name 'Položek v PATH' -Status $(if ($env:PATH) { 'OK' } else { 'WARN' }) -Value ([string](@($env:PATH -split ';' | Where-Object { $_ }).Count))
$report['3. Cesty'] = $pathsSection

# --- Sekce 4: adresáře a soubory ---------------------------------------------
Write-Log -Message 'Sekce 4/8: adresáře' -Level DEBUG

$structureSection = [ordered]@{}
$missingDirectories = @()
foreach ($directory in $manifest.Directories) {
    if (-not (Test-Path -LiteralPath (Join-Path -Path $root -ChildPath $directory) -PathType Container)) {
        $missingDirectories += $directory
    }
}
Add-ReportEntry -Section $structureSection -Name 'Povinné adresáře' -Status $(if ($missingDirectories.Count -eq 0) { 'OK' } else { 'FAIL' }) -Value ('{0}/{1} přítomno' -f ($manifest.Directories.Count - $missingDirectories.Count), $manifest.Directories.Count)
foreach ($directory in $missingDirectories) {
    Add-ReportEntry -Section $structureSection -Name 'Chybí adresář' -Status 'FAIL' -Value $directory
}

$missingFiles = @()
foreach ($file in $manifest.Files) {
    if (-not (Test-Path -LiteralPath (Join-Path -Path $root -ChildPath $file) -PathType Leaf)) {
        $missingFiles += $file
    }
}
Add-ReportEntry -Section $structureSection -Name 'Povinné soubory' -Status $(if ($missingFiles.Count -eq 0) { 'OK' } else { 'FAIL' }) -Value ('{0}/{1} přítomno' -f ($manifest.Files.Count - $missingFiles.Count), $manifest.Files.Count)
foreach ($file in $missingFiles) {
    Add-ReportEntry -Section $structureSection -Name 'Chybí soubor' -Status 'FAIL' -Value $file
}

foreach ($counted in @('prompts', 'docs', 'manual', 'gists', 'scripts', 'landing', 'launcher')) {
    $countedPath = Join-Path -Path $root -ChildPath $counted
    if (Test-Path -LiteralPath $countedPath -PathType Container) {
        $fileCount = @(Get-ChildItem -LiteralPath $countedPath -Recurse -File -ErrorAction SilentlyContinue).Count
        Add-ReportEntry -Section $structureSection -Name ("Obsah: {0}" -f $counted) -Status 'INFO' -Value ('{0} souborů' -f $fileCount)
    }
}
$report['4. Adresáře a soubory'] = $structureSection

# --- Sekce 5: prostředí (.env) ------------------------------------------------
Write-Log -Message 'Sekce 5/8: env' -Level DEBUG

$dotEnvPath = $null
foreach ($candidate in @((Join-Path -Path $root -ChildPath 'env/.env'), (Join-Path -Path $root -ChildPath '.env'))) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $dotEnvPath = $candidate
        break
    }
}
# Původ klíče je nutné zjistit PŘED načtením .env - Import-DotEnv plní Process
# scope, takže po načtení by se jako zdroj jevil vždy "Process".
$preLoadKeyScopes = [ordered]@{
    Process = [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY', 'Process')
    User    = [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY', 'User')
    Machine = [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY', 'Machine')
}
$dotEnvValues = Import-DotEnv

$envSection = [ordered]@{}
Add-ReportEntry -Section $envSection -Name '.env soubor' -Status $(if ($dotEnvPath) { 'OK' } else { 'WARN' }) -Value $(if ($dotEnvPath) { $dotEnvPath } else { 'nenalezen - zkopírujte env/.env.example na env/.env' })
Add-ReportEntry -Section $envSection -Name '.env.example' -Status $(if (Test-Path -LiteralPath (Join-Path -Path $root -ChildPath '.env.example') -PathType Leaf) { 'OK' } else { 'FAIL' }) -Value 'vzor konfigurace bez secrets'
Add-ReportEntry -Section $envSection -Name 'Načtené klíče' -Status 'INFO' -Value ('{0} klíčů' -f $dotEnvValues.Count)
if ($dotEnvValues.Count -gt 0) {
    Add-ReportEntry -Section $envSection -Name 'Klíče' -Status 'INFO' -Value (($dotEnvValues.Keys | Sort-Object) -join ', ')
}

# Substituce ${VAR}/$VAR: po expanzi nesmí v hodnotách zůstat žádná reference.
$unexpandedValues = @($dotEnvValues.Keys | Where-Object { ([string]$dotEnvValues[$_]) -match '\$\{[A-Za-z_][A-Za-z0-9_]*\}' })
if ($dotEnvValues.Count -eq 0) {
    Add-ReportEntry -Section $envSection -Name 'Substituce ${VAR}' -Status 'INFO' -Value 'žádné hodnoty k expanzi'
}
elseif ($unexpandedValues.Count -eq 0) {
    Add-ReportEntry -Section $envSection -Name 'Substituce ${VAR}' -Status 'OK' -Value ('{0} hodnot expandováno bez zbytku' -f $dotEnvValues.Count)
}
else {
    Add-ReportEntry -Section $envSection -Name 'Substituce ${VAR}' -Status 'WARN' -Value ('neexpandované reference u: {0}' -f ($unexpandedValues -join ', '))
}
$report['5. Prostředí'] = $envSection

# --- Sekce 6: API -------------------------------------------------------------
Write-Log -Message 'Sekce 6/8: API' -Level DEBUG

$apiKey = [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY')
$apiKeySet = -not [string]::IsNullOrWhiteSpace($apiKey)

$apiSection = [ordered]@{}
Add-ReportEntry -Section $apiSection -Name 'DEEPSEEK_API_KEY' -Status $(if ($apiKeySet) { 'OK' } else { 'WARN' }) -Value (Get-MaskedValue -Value $apiKey)

# Původ klíče: priorita Process -> User -> Machine -> .env (viz Get-EnvValueSource).
$keySource = Get-EnvValueSource -Name 'DEEPSEEK_API_KEY' -DotEnvValues $dotEnvValues -ProcessValue ([string]$preLoadKeyScopes['Process'])

foreach ($scopeName in @('Process', 'User', 'Machine')) {
    $scopeValue = [string]$preLoadKeyScopes[$scopeName]
    $isActive = $keySource.Found -and $keySource.Source -eq $scopeName
    $status = 'INFO'
    $label = 'nenastaveno'
    if (-not [string]::IsNullOrWhiteSpace($scopeValue)) {
        $label = 'set (len={0})' -f $scopeValue.Length
        if ($isActive) {
            $label += '  <- POUŽITO'
            $status = 'OK'
        }
    }
    Add-ReportEntry -Section $apiSection -Name ('zdroj: {0}' -f $scopeName) -Status $status -Value $label
}

$dotEnvKeyValue = if ($dotEnvValues.ContainsKey('DEEPSEEK_API_KEY')) { [string]$dotEnvValues['DEEPSEEK_API_KEY'] } else { '' }
if ([string]::IsNullOrWhiteSpace($dotEnvKeyValue)) {
    Add-ReportEntry -Section $apiSection -Name 'zdroj: .env' -Status 'INFO' -Value 'nenastaveno'
}
elseif ($keySource.Source -eq '.env') {
    Add-ReportEntry -Section $apiSection -Name 'zdroj: .env' -Status 'OK' -Value ('set (len={0})  <- POUŽITO' -f $dotEnvKeyValue.Length)
}
elseif ($keySource.Found -and $keySource.Value -ceq $dotEnvKeyValue) {
    Add-ReportEntry -Section $apiSection -Name 'zdroj: .env' -Status 'INFO' -Value ('set (len={0})  <- ignorováno, env má přednost (stejná hodnota)' -f $dotEnvKeyValue.Length)
}
else {
    Add-ReportEntry -Section $apiSection -Name 'zdroj: .env' -Status 'WARN' -Value ('set (len={0})  <- ignorováno, env má přednost (hodnota se liší)' -f $dotEnvKeyValue.Length)
}

if ($keySource.Found) {
    Add-ReportEntry -Section $apiSection -Name 'aktivní zdroj' -Status 'OK' -Value ('{0} ({1})' -f $keySource.Source, (Get-MaskedValue -Value $keySource.Value))
}
else {
    Add-ReportEntry -Section $apiSection -Name 'aktivní zdroj' -Status 'WARN' -Value 'DEEPSEEK_API_KEY není v env ani v .env'
}

foreach ($apiVariable in @('DEEPSEEK_BASE_URL', 'DEEPSEEK_MODEL', 'DEEPSEEK_REASONER_MODEL', 'ANTHROPIC_BASE_URL')) {
    $apiValue = [Environment]::GetEnvironmentVariable($apiVariable)
    if ([string]::IsNullOrWhiteSpace($apiValue)) {
        $apiValue = '<nenastaveno>'
    }
    Add-ReportEntry -Section $apiSection -Name $apiVariable -Status 'INFO' -Value $apiValue
}

# ANTHROPIC_AUTH_TOKEN se v .env obvykle odvozuje jako ${DEEPSEEK_API_KEY}.
$authToken = [Environment]::GetEnvironmentVariable('ANTHROPIC_AUTH_TOKEN')
if ([string]::IsNullOrWhiteSpace($authToken)) {
    Add-ReportEntry -Section $apiSection -Name 'ANTHROPIC_AUTH_TOKEN' -Status 'WARN' -Value 'nenastaveno - Claude Code se proti DeepSeek nepřihlásí'
}
elseif ($authToken -match '\$\{') {
    Add-ReportEntry -Section $apiSection -Name 'ANTHROPIC_AUTH_TOKEN' -Status 'FAIL' -Value ('neexpandovaná substituce: {0}' -f $authToken)
}
else {
    Add-ReportEntry -Section $apiSection -Name 'ANTHROPIC_AUTH_TOKEN' -Status 'OK' -Value (Get-MaskedValue -Value $authToken)
}
$report['6. API'] = $apiSection

# --- Sekce 7: AI nástroje -----------------------------------------------------
Write-Log -Message 'Sekce 7/8: AI nástroje' -Level DEBUG

$toolsSection = [ordered]@{}
$baseToolCandidates = [ordered]@{
    'node'       = $true
    'npm'        = $true
    'npx'        = $true
    'git'        = $true
    'pwsh'       = $true
    'powershell' = $false
}

$nodeAvailable = Test-Command -Name 'node'
$gitAvailable = Test-Command -Name 'git'

foreach ($tool in $baseToolCandidates.Keys) {
    $present = Test-Command -Name $tool
    $value = if ($present) { 'nalezen' } else { 'nenalezen' }
    if ($present -and $baseToolCandidates[$tool]) {
        $value = Get-ToolVersion -Name $tool
    }

    $status = 'INFO'
    if ($present) {
        $status = 'OK'
    }
    elseif ($tool -in @('node', 'npm', 'git')) {
        $status = 'FAIL'
    }

    Add-ReportEntry -Section $toolsSection -Name $tool -Status $status -Value $value
}

# AI komponenty rozdělené podle kategorií (Get-ComponentCatalog):
# Required mimo bin/npm-global je WARN, chybějící Required je FAIL,
# chybějící Recommended je WARN a Optional se hlásí jen jako INFO.
$missingRequiredComponents = @()
$componentCatalog = @(Get-ComponentCatalog)

foreach ($category in @('Required', 'Recommended', 'Optional')) {
    $categoryComponents = @($componentCatalog | Where-Object { $_.Category -eq $category } | Sort-Object -Property Name)
    if ($categoryComponents.Count -eq 0) {
        continue
    }

    Add-ReportEntry -Section $toolsSection -Name $category -Status 'INFO' -Value (($categoryComponents | ForEach-Object { $_.DisplayName }) -join ', ')

    foreach ($component in $categoryComponents) {
        $detection = Test-Component -Name ([string]$component.Binary) -Binary ([string]$component.Binary)
        $entryName = '{0} ({1})' -f $component.DisplayName, $component.Binary
        $version = [string]$detection.Version
        if (-not $version) {
            $version = 'neznámá'
        }

        if ($detection.Portable) {
            Add-ReportEntry -Section $toolsSection -Name $entryName -Status 'OK' -Value ('{0} | bin/npm-global ({1}, portable)' -f $version, $detection.Source)
            continue
        }

        $status = 'INFO'
        if ($category -eq 'Required') {
            $status = 'WARN'
            $missingRequiredComponents += $component.DisplayName
        }

        if ($detection.Found) {
            Add-ReportEntry -Section $toolsSection -Name $entryName -Status $status -Value ('{0} | mimo workspace ({1}: {2}) - NENÍ portable' -f $version, $detection.Source, $detection.Path)
        }
        else {
            if ($category -eq 'Required') {
                $status = 'FAIL'
            }
            elseif ($category -eq 'Recommended') {
                $status = 'WARN'
            }
            Add-ReportEntry -Section $toolsSection -Name $entryName -Status $status -Value 'nenalezeno - spusťte Setup-DeepSeekStack.ps1'
        }
    }
}
$report['7. AI nástroje'] = $toolsSection

# --- Sekce 8: doctor ----------------------------------------------------------
Write-Log -Message 'Sekce 8/8: doctor' -Level DEBUG

$counts = @{ OK = 0; WARN = 0; FAIL = 0; INFO = 0 }
foreach ($sectionName in $report.Keys) {
    foreach ($entryName in $report[$sectionName].Keys) {
        $status = [string]$report[$sectionName][$entryName].Status
        if ($counts.ContainsKey($status)) {
            $counts[$status]++
        }
        else {
            $counts['INFO']++
        }
    }
}

$overall = 'OK'
if ($counts.FAIL -gt 0) {
    $overall = 'FAIL'
}
elseif ($counts.WARN -gt 0) {
    $overall = 'WARN'
}

$doctorSection = [ordered]@{}
Add-ReportEntry -Section $doctorSection -Name 'Celkový stav' -Status $overall -Value $overall
Add-ReportEntry -Section $doctorSection -Name 'OK / WARN / FAIL' -Status 'INFO' -Value ('{0} / {1} / {2}' -f $counts.OK, $counts.WARN, $counts.FAIL)

if (-not $nodeAvailable) {
    Add-ReportEntry -Section $doctorSection -Name 'Doporučení' -Status 'WARN' -Value 'Node.js 22.19+ není v PATH. Nainstalujte ji ručně (workspace nic neinstaluje globálně).'
}
if (-not $gitAvailable) {
    Add-ReportEntry -Section $doctorSection -Name 'Doporučení' -Status 'WARN' -Value 'Git for Windows není v PATH. Bez něj nefunguje Repair-Repo.ps1.'
}
if (-not $dotEnvPath) {
    Add-ReportEntry -Section $doctorSection -Name 'Doporučení' -Status 'WARN' -Value 'Chybí .env. Spusťte: Copy-Item .env.example env/.env a doplňte klíč.'
}
if (-not $apiKeySet) {
    Add-ReportEntry -Section $doctorSection -Name 'Doporučení' -Status 'WARN' -Value 'DEEPSEEK_API_KEY není nastaven. AI nástroje poběží, ale nebudou moci volat model.'
}
if ($missingDirectories.Count + $missingFiles.Count -gt 0) {
    Add-ReportEntry -Section $doctorSection -Name 'Doporučení' -Status 'FAIL' -Value 'Chybí část workspace. Spusťte: scripts\Test-Workspace.ps1 -Fix'
}
if ($missingRequiredComponents.Count -gt 0) {
    Add-ReportEntry -Section $doctorSection -Name 'Doporučení' -Status 'WARN' -Value ('Required komponenta není v bin/npm-global: {0}. Spusťte: scripts\Setup-DeepSeekStack.ps1' -f ($missingRequiredComponents -join ', '))
}
if ($counts.WARN -eq 0 -and $counts.FAIL -eq 0) {
    Add-ReportEntry -Section $doctorSection -Name 'Doporučení' -Status 'OK' -Value 'Žádné problémy. Workspace je připraven.'
}
$report['8. Doctor'] = $doctorSection

$elapsed = (Get-Date) - $started
Write-Log -Message ('Diagnostika dokončena za {0:N2} s - stav: {1}' -f $elapsed.TotalSeconds, $overall) -Level $overall

# --- Výstup -------------------------------------------------------------------
if ($Json) {
    $report | ConvertTo-Json -Depth 8
}
else {
    foreach ($sectionName in $report.Keys) {
        Write-Log -Message $sectionName -Level HEAD
        foreach ($entryName in $report[$sectionName].Keys) {
            $entry = $report[$sectionName][$entryName]
            $level = [string]$entry.Status
            if ($level -notin @('OK', 'WARN', 'FAIL')) {
                $level = 'INFO'
            }
            Write-Log -Message ('    {0}: {1}' -f $entryName, $entry.Value) -Level $level
        }
        Write-Log -Message ''
    }
    Write-Log -Message ('=== CELKOVÝ STAV: {0} ===' -f $overall) -Level $overall
}

if ($overall -eq 'FAIL') {
    exit 1
}

exit 0
