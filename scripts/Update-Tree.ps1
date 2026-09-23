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

    Výchozí režim soubor přepíše. `-WhatIf` jen vypíše, co by se změnilo.

    Návratový kód: 0 = strom je aktuální nebo byl zapsán.
.PARAMETER WhatIf
    Zobrazí rozdíl proti současnému stromu, ale soubor nezmění.
.EXAMPLE
    .\Update-Tree.ps1
.EXAMPLE
    .\Update-Tree.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path -Path $PSScriptRoot -ChildPath '_common.ps1')

$script:ExcludedDirectories = @('.git', 'node_modules', '.reasonix', 'temp', 'tmp')
$script:PlaceholderDirectories = @('bin', 'logs', 'data')
$script:ExcludedFiles = @('.env', '*.log', '*.zip', 'session-*.md', 'Thumbs.db', 'desktop.ini', '.DS_Store')
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

# --- sestavení stromu ---------------------------------------------------------
$root = Get-WorkspaceRoot
$relativePath = 'scaffold/directory-tree.txt'
$treePath = Join-Path -Path $root -ChildPath $relativePath

$version = ''
$versionPath = Join-Path -Path $root -ChildPath 'VERSION'
if (Test-Path -LiteralPath $versionPath -PathType Leaf) {
    $version = (Get-Content -LiteralPath $versionPath -Raw).Trim()
}

$generatedAt = Get-Date
$lines = [System.Collections.Generic.List[string]]::new()
foreach ($headerLine in (Get-TreeHeader -RelativePath $relativePath -Version $version -GeneratedAt $generatedAt)) {
    [void]$lines.Add($headerLine)
}
[void]$lines.Add((Split-Path -Path $root -Leaf) + '\')
foreach ($treeLine in (Get-TreeLine -Path $root)) {
    [void]$lines.Add($treeLine)
}

$newContent = (($lines -join "`n") + "`n")

$oldContent = ''
$hasExistingTree = Test-Path -LiteralPath $treePath -PathType Leaf
if ($hasExistingTree) {
    $oldContent = (Get-Content -LiteralPath $treePath -Raw) -replace "`r`n", "`n"
}

Write-Banner -Title 'Portable AI Workspace' -Subtitle ('Directory tree - {0:yyyy-MM-dd HH:mm:ss}{1}' -f $generatedAt, $(if ($WhatIfPreference) { ' (whatif - nic se nemění)' } else { '' }))
Write-Log -Message ('Workspace: {0}' -f $root) -Level INFO
Write-Log -Message ('Cíl: {0} (verze {1})' -f $relativePath, $(if ($version) { $version } else { 'neznámá' })) -Level INFO

if ($oldContent -eq $newContent) {
    Write-Log -Message 'Strom je aktuální - není co měnit.' -Level OK
    exit 0
}

$added = @()
$removed = @()
if ($hasExistingTree) {
    $differences = @(Compare-Object -ReferenceObject ($oldContent -split "`n") -DifferenceObject ($newContent -split "`n"))
    $added = @($differences | Where-Object { $_.SideIndicator -eq '=>' } | ForEach-Object { $_.InputObject } | Where-Object { $_ -ne '' })
    $removed = @($differences | Where-Object { $_.SideIndicator -eq '<=' } | ForEach-Object { $_.InputObject } | Where-Object { $_ -ne '' })
}

if ($hasExistingTree) {
    Write-Log -Message ('Rozdíl proti současnému stromu: +{0} / -{1} řádků (bez ohledu na pořadí).' -f $added.Count, $removed.Count) -Level STEP
}
else {
    Write-Log -Message ('Soubor {0} neexistuje - vytvoří se nový ({1} řádků).' -f $relativePath, $lines.Count) -Level STEP
}

foreach ($line in $added) {
    Write-Log -Message ('+ {0}' -f $line) -Level OK
}
foreach ($line in $removed) {
    Write-Log -Message ('- {0}' -f $line) -Level WARN
}

if ($PSCmdlet.ShouldProcess($treePath, 'Zapsat přegenerovaný directory tree')) {
    [System.IO.File]::WriteAllText($treePath, $newContent, (New-Object System.Text.UTF8Encoding($false)))
    Write-Log -Message ('Zapsáno: {0} ({1} řádků, UTF-8 bez BOM, LF).' -f $relativePath, $lines.Count) -Level OK
    exit 0
}

Write-Log -Message ('WhatIf: {0} by se zapsal ({1} řádků). Soubor zůstal beze změny.' -f $relativePath, $lines.Count) -Level STEP
exit 0
