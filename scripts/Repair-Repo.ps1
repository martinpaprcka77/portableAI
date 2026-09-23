<#
.SYNOPSIS
    Opraví git repozitář workspace: atributy, ignorované soubory a řádkové koncovky.
.DESCRIPTION
    Sjednotí stav repozitáře podle pravidel workspace:

      1. ověří, že jde o git repozitář (a že je git vůbec dostupný)
      2. vytvoří chybějící `.gitattributes` a `.gitignore`, případně do
         existujících doplní chybějící vzory
      3. renormalizuje řádkové koncovky podle `.gitattributes`
      4. odstraní `node_modules` z trackingu (soubory na disku zůstávají)

    Všechny změny jsou idempotentní a podporují `-WhatIf`, takže si je lze
    nejdřív prohlédnout. Skript nikdy nemaže data z disku.

    Návratový kód: 0 = OK, 1 = chyba.
.PARAMETER SkipLineEndings
    Přeskočí renormalizaci řádkových koncovek.
.PARAMETER SkipUntrack
    Přeskočí odstranění `node_modules` z trackingu.
.PARAMETER LogFile
    Cesta k log souboru. Pokud není zadán, skript do souboru neloguje.
.EXAMPLE
    .\Repair-Repo.ps1
.EXAMPLE
    .\Repair-Repo.ps1 -WhatIf
.EXAMPLE
    .\Repair-Repo.ps1 -LogFile ..\logs\repair.log
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [switch]$SkipLineEndings,

    [Parameter()]
    [switch]$SkipUntrack,

    [Parameter()]
    [string]$LogFile
)

. (Join-Path -Path $PSScriptRoot -ChildPath '_common.ps1')

function Add-GitIgnoreEntry {
    <#
    .SYNOPSIS
        Doplní do souboru chybějící vzory, pokud tam ještě nejsou.
    .DESCRIPTION
        Pro každý vzor ověří, zda už v souboru existuje (jako samostatný
        řádek, bez ohledu na okolní bílé znaky). Chybějící vzory připojí na
        konec pod komentář s vysvětlením. Operace je idempotentní.
    .PARAMETER Path
        Cesta k souboru (typicky `.gitignore`).
    .PARAMETER Patterns
        Pole vzorů, které mají v souboru být.
    .OUTPUTS
        System.Int32 - počet skutečně přidaných vzorů
    .EXAMPLE
        Add-GitIgnoreEntry -Path '.\.gitignore' -Patterns @('.env', 'node_modules/')
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,

        [Parameter(Mandatory = $true, Position = 1)]
        [string[]]$Patterns
    )

    $existing = @()
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $existing = @(Get-Content -LiteralPath $Path -Encoding utf8 | ForEach-Object { $_.Trim() })
    }

    $missing = @($Patterns | Where-Object { $existing -notcontains $_ })
    if ($missing.Count -eq 0) {
        return 0
    }

    $addition = @('', '# Doplněno skriptem Repair-Repo.ps1') + $missing
    Add-Content -LiteralPath $Path -Value $addition -Encoding utf8

    return $missing.Count
}

$root = Get-WorkspaceRoot
$started = Get-Date
$problems = 0

if (-not $LogFile) {
    $LogFile = Join-Path -Path $root -ChildPath ("logs/repair-{0:yyyyMMdd-HHmm}.log" -f $started)
}
$logDirectory = Split-Path -Path $LogFile -Parent
if ($logDirectory -and -not (Test-Path -LiteralPath $logDirectory -PathType Container)) {
    New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
}

Write-Banner -Title 'Portable AI Workspace' -Subtitle ('Repair repo - {0:yyyy-MM-dd HH:mm:ss}' -f $started)
Write-Log -Message ('Workspace: {0}' -f $root) -Level INFO -LogFile $LogFile
Write-Log -Message ('Kódování konzole: UTF-8 ({0})' -f [Console]::OutputEncoding.WebName) -Level INFO

# --- 1. git a repozitář -------------------------------------------------------
Write-Log -Message 'Krok 1/4: kontrola git repozitáře' -Level STEP

if (-not (Test-Command -Name 'git')) {
    Write-Log -Message 'Git není v PATH - oprava není možná. Nainstalujte Git for Windows.' -Level FAIL
    exit 1
}

& git -C $root rev-parse --is-inside-work-tree 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Log -Message ('Workspace {0} není git repozitář. Spusťte: git init' -f $root) -Level FAIL
    exit 1
}
Write-Log -Message 'Git repozitář nalezen.' -Level OK

# --- 2. .gitattributes a .gitignore -------------------------------------------
Write-Log -Message 'Krok 2/4: .gitattributes a .gitignore' -Level STEP

$gitAttributesPath = Join-Path -Path $root -ChildPath '.gitattributes'
if (Test-Path -LiteralPath $gitAttributesPath -PathType Leaf) {
    Write-Log -Message '.gitattributes existuje - obsah nepřepisuji.' -Level OK
}
else {
    if ($PSCmdlet.ShouldProcess($gitAttributesPath, 'Vytvořit .gitattributes')) {
        $gitAttributesContent = @(
            '# Normalizace řádkových koncovek'
            '* text=auto'
            '*.ps1  text eol=crlf'
            '*.psm1 text eol=crlf'
            '*.psd1 text eol=crlf'
            '*.cmd  text eol=crlf'
            '*.bat  text eol=crlf'
            '*.md   text eol=lf'
            '*.json text eol=lf'
            '*.toml text eol=lf'
            '*.yaml text eol=lf'
            '*.yml  text eol=lf'
            '*.html text eol=lf'
            '*.css  text eol=lf'
            '*.js   text eol=lf'
            '*.svg  text eol=lf'
        )
        Set-Content -LiteralPath $gitAttributesPath -Value $gitAttributesContent -Encoding utf8
        Write-Log -Message 'Vytvořen .gitattributes.' -Level OK
    }
}

$gitIgnorePath = Join-Path -Path $root -ChildPath '.gitignore'
$requiredIgnorePatterns = @('.env', '**/.env', '!**/.env.example', 'node_modules/', 'logs/*.log', 'data/*', '!data/.gitkeep', 'bin/*', '!bin/.gitkeep')

if (-not (Test-Path -LiteralPath $gitIgnorePath -PathType Leaf)) {
    if ($PSCmdlet.ShouldProcess($gitIgnorePath, 'Vytvořit .gitignore')) {
        Set-Content -LiteralPath $gitIgnorePath -Value @('# Secrets', '.env', '**/.env') -Encoding utf8
        Write-Log -Message 'Vytvořen .gitignore.' -Level OK
    }
}

if ($PSCmdlet.ShouldProcess($gitIgnorePath, 'Doplnit chybějící vzory do .gitignore')) {
    $added = Add-GitIgnoreEntry -Path $gitIgnorePath -Patterns $requiredIgnorePatterns
    if ($added -gt 0) {
        Write-Log -Message ('Do .gitignore doplněno {0} vzorů.' -f $added) -Level OK
    }
    else {
        Write-Log -Message '.gitignore obsahuje všechny povinné vzory.' -Level OK
    }
}

# --- 3. renormalizace řádkových koncovek --------------------------------------
Write-Log -Message 'Krok 3/4: renormalizace řádkových koncovek' -Level STEP

if ($SkipLineEndings) {
    Write-Log -Message 'Přeskočeno (-SkipLineEndings).' -Level WARN
}
elseif ($PSCmdlet.ShouldProcess($root, 'git add --renormalize .')) {
    & git -C $root add --renormalize . 2>&1 | ForEach-Object { Write-Log -Message ([string]$_) -Level DEBUG }
    if ($LASTEXITCODE -eq 0) {
        Write-Log -Message 'Řádkové koncovky renormalizovány podle .gitattributes.' -Level OK
    }
    else {
        Write-Log -Message ('Renormalizace selhala (git exit {0}).' -f $LASTEXITCODE) -Level WARN
        $problems++
    }
}

# --- 4. node_modules z trackingu ----------------------------------------------
Write-Log -Message 'Krok 4/4: node_modules v trackingu' -Level STEP

if ($SkipUntrack) {
    Write-Log -Message 'Přeskočeno (-SkipUntrack).' -Level WARN
}
else {
    $trackedNodeModules = @(& git -C $root ls-files 'node_modules' 2>$null | Select-Object -First 5)
    if ($trackedNodeModules.Count -eq 0) {
        Write-Log -Message 'node_modules není trackovaný.' -Level OK
    }
    elseif ($PSCmdlet.ShouldProcess((Join-Path -Path $root -ChildPath 'node_modules'), 'git rm -r --cached node_modules')) {
        & git -C $root rm -r --cached 'node_modules' --quiet 2>&1 | ForEach-Object { Write-Log -Message ([string]$_) -Level DEBUG }
        if ($LASTEXITCODE -eq 0) {
            Write-Log -Message 'node_modules odstraněn z trackingu (soubory na disku zůstávají).' -Level OK
        }
        else {
            Write-Log -Message ('Odstranění z trackingu selhalo (git exit {0}).' -f $LASTEXITCODE) -Level WARN
            $problems++
        }
    }
}

# --- Souhrn -------------------------------------------------------------------
$elapsed = (Get-Date) - $started
if ($problems -eq 0) {
    Write-Log -Message ('Repozitář je opravený. Trvalo to {0:N2} s.' -f $elapsed.TotalSeconds) -Level OK
    exit 0
}

Write-Log -Message ('Oprava dokončena s {0} problémy za {1:N2} s.' -f $problems, $elapsed.TotalSeconds) -Level FAIL
exit 1
