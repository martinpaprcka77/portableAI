<#
.SYNOPSIS
    Přegeneruje `scaffold/directory-tree.txt` podle skutečného obsahu workspace.
.DESCRIPTION
    Projde workspace, přeskočí runtime a citlivé cesty a zapíše strom ve
    stejném formátu, jaký používá `scaffold/directory-tree.txt` (znaky `│`,
    `├──` a `└──`, adresáře před soubory, řazení bez ohledu na velikost
    písmen).

    Přeskakuje se:

      - adresáře `.git`, `node_modules`, `.reasonix`, `temp`, `tmp`
      - obsah `bin/`, `logs/` a `data/` (ve stromu zůstává jen `.gitkeep`)
      - soubory `.env`, `*.log`, `session-*.md` a `*.zip`

    Hlavička stromu nese datum generování a verzi workspace, takže je
    z historie poznat, kdy a z jaké verze strom vznikl. `SelfHeal.ps1`
    (kontrola 12) hlásí strom jako zastaralý, když v něm chybí klíčové
    soubory nebo je hlavička starší než 30 dní.

    Regenerace je obsah-idempotentní: když se strom nezměnil a hlavička
    není starší než 30 dní, skript nezapíše nic - žádný jednořádkový diff
    kvůli datu. Datum se obnoví, když se obsah (nebo hlavička včetně verze)
    změnil, když je hlavička starší než 30 dní, nebo vždy s `-Force`.
    Díky tomu stačí po `WARN` z kontroly 12 spustit skript bez parametrů.

    `-WhatIf` jen vypíše, co by se změnilo.

    Návratový kód: 0 = strom je aktuální nebo byl zapsán.
.PARAMETER Force
    Zapíše strom vždy, i když se obsah ani datum nemění (např. když chcete
    vynutit nové datum bez čekání na 30 dní).
.PARAMETER WhatIf
    Zobrazí rozdíl proti současnému stromu, ale soubor nezmění.
.EXAMPLE
    .\Update-Tree.ps1
.EXAMPLE
    .\Update-Tree.ps1 -WhatIf
.EXAMPLE
    .\Update-Tree.ps1 -Force
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [switch]$Force
)

. (Join-Path -Path $PSScriptRoot -ChildPath '_common.ps1')

$script:ExcludedDirectories = @('.git', 'node_modules', '.reasonix', 'temp', 'tmp')
$script:PlaceholderDirectories = @('bin', 'logs', 'data')
$script:ExcludedFiles = @('.env', '*.log', '*.zip', 'session-*.md', 'Thumbs.db', 'desktop.ini', '.DS_Store')
# Stejný práh používá SelfHeal kontrola 12 - při změně držte obojí v souladu.
$script:HeaderMaxAgeDays = 30
$script:PlaceholderFileName = '.gitkeep'

function Test-ExcludedDirectory {
    <#
    .SYNOPSIS
        Vrátí $true, když se adresář do stromu vůbec nepromítá.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return ($script:ExcludedDirectories -contains $Name)
}

function Test-PlaceholderDirectory {
    <#
    .SYNOPSIS
        Vrátí $true, když se z adresáře ve stromu vypisuje jen `.gitkeep`.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return ($script:PlaceholderDirectories -contains $Name)
}

function Test-ExcludedFile {
    <#
    .SYNOPSIS
        Vrátí $true, když se soubor do stromu nepromítá (secrets, logy, runtime).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    foreach ($pattern in $script:ExcludedFiles) {
        if ($Name -like $pattern) {
            return $true
        }
    }

    return $false
}

function Get-TreeSortedChildItem {
    <#
    .SYNOPSIS
        Vrátí položky seřazené podle názvu deterministicky - InvariantCulture, bez ohledu na velikost písmen.
    .DESCRIPTION
        `Sort-Object` řadí podle kultury prostředí: v češtině je `ch` samostatné
        písmeno až za `h`, takže by stejný strom vypadal na českém a anglickém
        systému jinak. Invariantní řazení drží stejný výstup lokálně i v CI.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileSystemInfo[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.IO.FileSystemInfo[]]$Item
    )

    if ($Item.Count -le 1) {
        return $Item
    }

    $names = [string[]]@($Item | ForEach-Object { $_.Name })
    [Array]::Sort($names, [System.StringComparer]::InvariantCultureIgnoreCase)

    $byName = @{}
    foreach ($entry in $Item) {
        $byName[$entry.Name] = $entry
    }

    return @($names | ForEach-Object { $byName[$_] })
}

function Get-TreeLine {
    <#
    .SYNOPSIS
        Vrátí řádky stromu pro obsah zadaného adresáře (bez hlavičky).
    .DESCRIPTION
        Rekurzivní průchod. V každé úrovni se nejdřív vypíšou adresáře,
        potom soubory - stejně jako v `scaffold/directory-tree.txt`.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [string]$Prefix = '',

        [Parameter()]
        [switch]$PlaceholdersOnly
    )

    $directories = @()
    if (-not $PlaceholdersOnly) {
        $directories = @(Get-TreeSortedChildItem -Item @(Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue |
                    Where-Object { -not (Test-ExcludedDirectory -Name $_.Name) }))
    }

    $files = @(Get-TreeSortedChildItem -Item @(Get-ChildItem -LiteralPath $Path -File -Force -ErrorAction SilentlyContinue |
                Where-Object { -not (Test-ExcludedFile -Name $_.Name) } |
                Where-Object { -not $PlaceholdersOnly -or $_.Name -eq $script:PlaceholderFileName }))

    $total = $directories.Count + $files.Count
    $index = 0

    foreach ($directory in $directories) {
        $index++
        $isLast = ($index -eq $total)
        $branch = if ($isLast) { '└── ' } else { '├── ' }
        $childPrefix = $Prefix + $(if ($isLast) { '    ' } else { '│   ' })

        Write-Output ($Prefix + $branch + $directory.Name + '\')
        Get-TreeLine -Path $directory.FullName -Prefix $childPrefix -PlaceholdersOnly:(Test-PlaceholderDirectory -Name $directory.Name)
    }

    foreach ($file in $files) {
        $index++
        $branch = if ($index -eq $total) { '└── ' } else { '├── ' }
        Write-Output ($Prefix + $branch + $file.Name)
    }
}

function Get-TreeHeader {
    <#
    .SYNOPSIS
        Vrátí hlavičku stromu (komentáře s datem, verzí a odkazem na generátor).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter()]
        [string]$Version = '',

        [Parameter()]
        [datetime]$GeneratedAt = (Get-Date)
    )

    $skipped = '.git, node_modules, .reasonix, temp, bin/npm-global, logs/*.log, data (kromě .gitkeep), .env, session-*.md, *.zip, Thumbs.db, desktop.ini'

    return @(
        ('# {0}' -f $RelativePath)
        '#'
        '# Automaticky generovaný strom portable AI workspace (jen verzované soubory).'
        ('# Vygenerováno: {0} (lokální čas)' -f $GeneratedAt.ToString('yyyy-MM-dd HH:mm:ss'))
        ('# Verze workspace: {0}' -f $(if ($Version) { $Version } else { 'neznámá' }))
        ('# Vynecháno: {0}' -f $skipped)
        '# Vygeneruje: pwsh -File scripts\Update-Tree.ps1   (-WhatIf vypíše jen rozdíl)'
        '#'
        '# Skutečný obsah verzovaných souborů: git ls-files'
        ''
    )
}

function Get-TreeHeaderTimestamp {
    <#
    .SYNOPSIS
        Přečte datum generování z hlavičky stromu.
    .DESCRIPTION
        Vrací `[datetime]` z řádku `# Vygenerováno: <datum>`, nebo `$null`,
        když v hlavičce datum není. Stejný tvar parsuje i `SelfHeal.ps1`
        (kontrola 12); tady se podle něj rozhoduje, jestli je potřeba
        obnovit datum.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    $match = [regex]::Match($Content, '(?m)^#\s*Vygenerováno:\s*(\d{4}-\d{2}-\d{2}(?: \d{2}:\d{2}:\d{2})?)')
    if (-not $match.Success) {
        return $null
    }

    $parsed = [datetime]::MinValue
    if (-not [datetime]::TryParse($match.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
        return $null
    }

    return $parsed
}

# --- sestavení stromu ---------------------------------------------------------
$root = Get-WorkspaceRoot
$relativePath = 'scaffold/directory-tree.txt'
$treePath = Join-Path -Path $root -ChildPath $relativePath

$version = ''
$versionPath = Join-Path -Path $root -ChildPath 'VERSION'
if (Test-Path -LiteralPath $versionPath -PathType Leaf) {
    $version = (Get-Content -LiteralPath $versionPath -Raw).Trim()
}

# Tělo stromu je deterministické - hlavička se generuje zvlášť, aby se dalo
# porovnat, jestli se změnilo něco jiného než datum.
$bodyLines = [System.Collections.Generic.List[string]]::new()
[void]$bodyLines.Add((Split-Path -Path $root -Leaf) + '\')
foreach ($treeLine in (Get-TreeLine -Path $root)) {
    [void]$bodyLines.Add($treeLine)
}

$generatedAt = Get-Date
$newLines = @(Get-TreeHeader -RelativePath $relativePath -Version $version -GeneratedAt $generatedAt) + @($bodyLines)
$newContent = (($newLines -join "`n") + "`n")

$hasExistingTree = Test-Path -LiteralPath $treePath -PathType Leaf
$existingContent = ''
$existingGeneratedAt = $null
if ($hasExistingTree) {
    $existingContent = (Get-Content -LiteralPath $treePath -Raw) -replace "`r`n", "`n"
    $existingGeneratedAt = Get-TreeHeaderTimestamp -Content $existingContent
}

$headerAgeDays = 0.0
if ($null -ne $existingGeneratedAt) {
    $headerAgeDays = ((Get-Date) - $existingGeneratedAt).TotalDays
    if ($headerAgeDays -lt 0) {
        # Hlavička nese lokální čas generátoru; na stroji v jiném pásmu
        # (například UTC runner v CI) vyjde stáří mírně do minusu.
        $headerAgeDays = 0
    }
}

$headerStale = ($null -eq $existingGeneratedAt) -or ($headerAgeDays -gt $script:HeaderMaxAgeDays)

# Rozdíl jen v datu: kdyby obsah i hlavička (verze, seznam vynechaných cest)
# odpovídaly, ale s původním datem - pak není co řešit a soubor se nezapíše.
$onlyHeaderDateDiffers = $false
if ($hasExistingTree -and $null -ne $existingGeneratedAt) {
    $comparisonLines = @(Get-TreeHeader -RelativePath $relativePath -Version $version -GeneratedAt $existingGeneratedAt) + @($bodyLines)
    $onlyHeaderDateDiffers = ($existingContent -eq ((($comparisonLines -join "`n") + "`n")))
}

$shouldWrite = (-not $hasExistingTree) -or $Force -or (-not $onlyHeaderDateDiffers) -or $headerStale

Write-Banner -Title 'Portable AI Workspace' -Subtitle ('Directory tree - {0:yyyy-MM-dd HH:mm:ss}{1}' -f $generatedAt, $(if ($WhatIfPreference) { ' (whatif - nic se nemění)' } else { '' }))
Write-Log -Message ('Workspace: {0}' -f $root) -Level INFO
Write-Log -Message ('Cíl: {0} (verze {1})' -f $relativePath, $(if ($version) { $version } else { 'neznámá' })) -Level INFO

if (-not $shouldWrite) {
    Write-Log -Message ('Strom je aktuální - obsah i hlavička bez změny (vygenerováno {0:yyyy-MM-dd}, {1:N0} dní). Nic se nezapisuje.' -f $existingGeneratedAt, $headerAgeDays) -Level OK
    exit 0
}

if (-not $hasExistingTree) {
    Write-Log -Message ('Důvod zápisu: soubor {0} neexistuje.' -f $relativePath) -Level STEP
}
elseif ($Force) {
    Write-Log -Message 'Důvod zápisu: vynuceno přes -Force.' -Level STEP
}
elseif (-not $onlyHeaderDateDiffers) {
    Write-Log -Message 'Důvod zápisu: změnil se obsah nebo hlavička stromu.' -Level STEP
}
else {
    Write-Log -Message ('Důvod zápisu: hlavička je starší než {0} dní ({1:N0} dní) - obnovuje se jen datum.' -f $script:HeaderMaxAgeDays, $headerAgeDays) -Level STEP
}

$added = @()
$removed = @()
if ($hasExistingTree) {
    $differences = @(Compare-Object -ReferenceObject ($existingContent -split "`n") -DifferenceObject ($newContent -split "`n"))
    $added = @($differences | Where-Object { $_.SideIndicator -eq '=>' } | ForEach-Object { $_.InputObject } | Where-Object { $_ -ne '' })
    $removed = @($differences | Where-Object { $_.SideIndicator -eq '<=' } | ForEach-Object { $_.InputObject } | Where-Object { $_ -ne '' })
    Write-Log -Message ('Rozdíl proti současnému stromu: +{0} / -{1} řádků (bez ohledu na pořadí).' -f $added.Count, $removed.Count) -Level STEP
}
else {
    Write-Log -Message ('Soubor {0} neexistuje - vytvoří se nový ({1} řádků).' -f $relativePath, $newLines.Count) -Level STEP
}

foreach ($line in $added) {
    Write-Log -Message ('+ {0}' -f $line) -Level OK
}
foreach ($line in $removed) {
    Write-Log -Message ('- {0}' -f $line) -Level WARN
}

if ($PSCmdlet.ShouldProcess($treePath, 'Zapsat přegenerovaný directory tree')) {
    [System.IO.File]::WriteAllText($treePath, $newContent, (New-Object System.Text.UTF8Encoding($false)))
    if ($onlyHeaderDateDiffers -and -not $Force) {
        Write-Log -Message ('Zapsáno: {0} (obnoveno jen datum hlavičky).' -f $relativePath) -Level OK
    }
    else {
        Write-Log -Message ('Zapsáno: {0} ({1} řádků, UTF-8 bez BOM, LF).' -f $relativePath, $newLines.Count) -Level OK
    }

    exit 0
}

Write-Log -Message ('WhatIf: {0} by se zapsal ({1} řádků). Soubor zůstal beze změny.' -f $relativePath, $newLines.Count) -Level STEP
exit 0
