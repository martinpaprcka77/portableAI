<#
.SYNOPSIS
    Provede self-test portable AI workspace.
.DESCRIPTION
    Ověří čtrnáct oblastí workspace a vrátí souhrnný stav PASS nebo FAIL:

      1. povinné adresáře existují
      2. povinné soubory existují
      3. všechny `.ps1` mají UTF-8 BOM (první tři bajty EF BB BF)
      4. všechny `.ps1` projdou Invoke-ScriptAnalyzer (pokud je modul dostupný)
      5. `.env.example` existuje a `.env` není trackovaný gitem
      6. Node.js je dostupný ve verzi 22.19+
      7. workspace je inicializovaný git repozitář
      8. `.ps1` a `.cmd` mají CRLF řádkové koncovky
      9. `.md`, `.json` a `.toml` mají LF řádkové koncovky (žádné CRLF)
     10. všechny `.ps1` mají `.SYNOPSIS`, `.DESCRIPTION` a `.EXAMPLE`
     11. relativní odkazy v `README.md` míří na existující soubory
     12. `landing/index.html` má spárované HTML tagy
     13. `METAPROMPT.md` obsahuje všechny fáze 0-10
     14. všechny prompty v `prompts/` mají YAML frontmatter s `title`
         a `description`

    S přepínačem -Fix se opraví to, co opravit lze: chybějící adresáře,
    UTF-8 BOM, řádkové koncovky a chybějící git repozitář. Chybějící soubory
    s obsahem, rozbité odkazy a chybějící frontmatter se nevytvářejí - ty
    hlásí FAIL.

    Návratový kód: 0 = PASS, 1 = FAIL.
.PARAMETER Json
    Vypíše strukturovaný JSON místo lidského výstupu.
.PARAMETER Fix
    Provede opravy, které jsou bezpečné a idempotentní. Kombinujte s -WhatIf
    pro zobrazení toho, co by se změnilo.
.EXAMPLE
    .\Test-Workspace.ps1
.EXAMPLE
    .\Test-Workspace.ps1 -Fix -WhatIf
.EXAMPLE
    .\Test-Workspace.ps1 -Json -Fix
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [switch]$Json,

    [Parameter()]
    [switch]$Fix
)

. (Join-Path -Path $PSScriptRoot -ChildPath '_common.ps1')

function Add-CheckResult {
    <#
    .SYNOPSIS
        Přidá výsledek jedné kontroly do seznamu.
    .DESCRIPTION
        Interní helper self-testu. Drží jednotný tvar výsledku, který se dá
        vypsat lidsky i serializovat do JSON.
    .PARAMETER Results
        Seznam výsledků (List[object]).
    .PARAMETER Id
        Strojový identifikátor kontroly.
    .PARAMETER Name
        Lidský název kontroly.
    .PARAMETER Status
        Stav: OK, WARN nebo FAIL.
    .PARAMETER Detail
        Detail vysvětlující výsledek.
    .EXAMPLE
        Add-CheckResult -Results $checks -Id 'dirs' -Name 'Adresáře' -Status 'OK' -Detail '17/17'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Results,

        [Parameter(Mandatory = $true)]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet('OK', 'WARN', 'FAIL')]
        [string]$Status,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Detail = ''
    )

    [void]$Results.Add([ordered]@{
            Id     = $Id
            Name   = $Name
            Status = $Status
            Detail = $Detail
        })
}

function Test-FileBom {
    <#
    .SYNOPSIS
        Zjistí, zda soubor začíná UTF-8 BOM.
    .DESCRIPTION
        Čte první tři bajty souboru a porovná je s UTF-8 BOM (EF BB BF).
        Prázdný nebo krátký soubor vrací $false.
    .PARAMETER Path
        Cesta k souboru.
    .OUTPUTS
        System.Boolean
    .EXAMPLE
        Test-FileBom -Path '.\scripts\_common.ps1'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 3) {
        return $false
    }

    return ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
}

function Test-CrlfFile {
    <#
    .SYNOPSIS
        Zjistí, zda soubor používá výhradně CRLF řádkové koncovky.
    .DESCRIPTION
        Hledá osamocený LF bajt (0x0A) bez předcházejícího CR (0x0D).
        Výsledek true znamená, že soubor je bezpečný pro Windows shell.
    .PARAMETER Path
        Cesta k souboru.
    .OUTPUTS
        System.Boolean
    .EXAMPLE
        Test-CrlfFile -Path '.\launcher\Menu.ps1'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    for ($index = 0; $index -lt $bytes.Length; $index++) {
        if ($bytes[$index] -eq 0x0A -and ($index -eq 0 -or $bytes[$index - 1] -ne 0x0D)) {
            return $false
        }
    }

    return $true
}

function Add-Utf8Bom {
    <#
    .SYNOPSIS
        Přidá do souboru UTF-8 BOM, pokud tam ještě není.
    .DESCRIPTION
        Zachová veškerý obsah včetně řádkových koncovek. Operace je
        idempotentní - soubor s BOM se nezmění.
    .PARAMETER Path
        Cesta k souboru.
    .EXAMPLE
        Add-Utf8Bom -Path '.\scripts\_common.ps1'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    if (Test-FileBom -Path $Path) {
        return
    }

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    [System.IO.File]::WriteAllText($Path, $text, [System.Text.UTF8Encoding]::new($true))
}

function ConvertTo-CrlfFile {
    <#
    .SYNOPSIS
        Převede řádkové koncovky souboru na CRLF.
    .DESCRIPTION
        Zachová UTF-8 BOM, pokud v souboru byl. Operace je idempotentní.
    .PARAMETER Path
        Cesta k souboru.
    .EXAMPLE
        ConvertTo-CrlfFile -Path '.\launcher\Menu.ps1'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $hasBom = Test-FileBom -Path $Path
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($hasBom) {
        $text = $text.Substring(1)
    }

    $normalized = ($text -replace "`r`n", "`n") -replace "`n", "`r`n"
    $encoding = [System.Text.UTF8Encoding]::new($hasBom)
    [System.IO.File]::WriteAllText($Path, $normalized, $encoding)
}

function Test-LfFile {
    <#
    .SYNOPSIS
        Zjistí, zda soubor neobsahuje žádné CRLF řádkové koncovky.
    .DESCRIPTION
        Opak `Test-CrlfFile`. Pravdivý výsledek znamená, že textový soubor,
        který má používat LF (`.md`, `.json`, `.toml`), je v pořádku -
        Windows editor do něj nesmí zapsat CR.
    .PARAMETER Path
        Cesta k souboru.
    .OUTPUTS
        System.Boolean
    .EXAMPLE
        Test-LfFile -Path '.\README.md'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    for ($index = 1; $index -lt $bytes.Length; $index++) {
        if ($bytes[$index] -eq 0x0A -and $bytes[$index - 1] -eq 0x0D) {
            return $false
        }
    }

    return $true
}

function ConvertTo-LfFile {
    <#
    .SYNOPSIS
        Převede řádkové koncovky souboru na LF.
    .DESCRIPTION
        Zachová UTF-8 BOM, pokud v souboru byl. Operace je idempotentní.
    .PARAMETER Path
        Cesta k souboru.
    .EXAMPLE
        ConvertTo-LfFile -Path '.\README.md'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $hasBom = Test-FileBom -Path $Path
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($hasBom) {
        $text = $text.Substring(1)
    }

    $normalized = $text -replace "`r`n", "`n"
    $encoding = [System.Text.UTF8Encoding]::new($hasBom)
    [System.IO.File]::WriteAllText($Path, $normalized, $encoding)
}

function Test-ScriptCommentHelp {
    <#
    .SYNOPSIS
        Zjistí, které povinné sekce komentářové nápovědy skriptu chybí.
    .DESCRIPTION
        Konvence workspace vyžaduje u každého `.ps1` blok komentářové
        nápovědy s `.SYNOPSIS`, `.DESCRIPTION` a `.EXAMPLE`. Kontroluje se
        pouze hlavička na začátku souboru - nález značky uvnitř dokumentace
        jiné funkce v těle skriptu nestačí.
    .PARAMETER Path
        Cesta k `.ps1` souboru.
    .OUTPUTS
        System.String[] - chybějící sekce; prázdné pole znamená OK
    .EXAMPLE
        Test-ScriptCommentHelp -Path '.\scripts\_common.ps1'
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    $header = [System.Collections.Generic.List[string]]::new()
    $inside = $false

    foreach ($rawLine in (Get-Content -LiteralPath $Path -Encoding utf8)) {
        $line = ([string]$rawLine).Trim()
        if (-not $inside) {
            if ($line.StartsWith('<#')) {
                $inside = $true
                continue
            }
            if ($line) {
                break
            }
            continue
        }
        if ($line.EndsWith('#>')) {
            break
        }
        [void]$header.Add($line)
    }

    $text = $header -join "`n"
    $missing = [System.Collections.Generic.List[string]]::new()
    foreach ($section in @('.SYNOPSIS', '.DESCRIPTION', '.EXAMPLE')) {
        if ($text -notmatch [regex]::Escape($section)) {
            [void]$missing.Add($section)
        }
    }

    return $missing.ToArray()
}

function Get-MarkdownRelativeLink {
    <#
    .SYNOPSIS
        Vrátí relativní cíle odkazů z Markdownu.
    .DESCRIPTION
        Vytáhne cíle zápisu `[text](cil)`, vynechá absolutní URL (`https:`,
        `mailto:`, …) a čisté kotvy (`#...`) a odstraní případný fragment.
        Slouží k ověření, že relativní odkazy v dokumentaci míří na
        existující soubory.
    .PARAMETER Path
        Cesta k `.md` souboru.
    .OUTPUTS
        System.String[]
    .EXAMPLE
        Get-MarkdownRelativeLink -Path '.\README.md'
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    $content = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    $links = [System.Collections.Generic.List[string]]::new()

    foreach ($match in [regex]::Matches($content, '\]\(([^)\s]+)\)')) {
        $target = $match.Groups[1].Value.Trim()
        if ($target -match '^[a-zA-Z][a-zA-Z0-9+.-]*:') {
            continue
        }
        if ($target.StartsWith('#')) {
            continue
        }
        $target = ($target -split '#')[0]
        if ([string]::IsNullOrWhiteSpace($target)) {
            continue
        }
        [void]$links.Add([uri]::UnescapeDataString($target))
    }

    return $links.ToArray()
}

function Test-HtmlStructure {
    <#
    .SYNOPSIS
        Zkontroluje, zda má HTML dokument spárované tagy.
    .DESCRIPTION
        Lehká statická kontrola bez externích závislostí. Odstraní komentáře
        a obsah `<script>`/`<style>`, ignoruje void elementy a self-closing
        tagy a pak ověří, že se každý otevřený element zase zavře ve
        správném pořadí. Nenahrazuje validátor, ale odhalí rozbitou
        strukturu stránky.
    .PARAMETER Path
        Cesta k `.html` souboru.
    .OUTPUTS
        System.String[] - popis problémů; prázdné pole znamená OK
    .EXAMPLE
        Test-HtmlStructure -Path '.\landing\index.html'
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    $voidElements = @('area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param', 'source', 'track', 'wbr')
    $singleline = [System.Text.RegularExpressions.RegexOptions]::Singleline
    $singlelineIgnoreCase = $singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase

    $content = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    $content = [regex]::Replace($content, '<!--.*?-->', '', $singleline)
    $content = [regex]::Replace($content, '<script\b[^>]*>.*?</script\s*>', '', $singlelineIgnoreCase)
    $content = [regex]::Replace($content, '<style\b[^>]*>.*?</style\s*>', '', $singlelineIgnoreCase)

    $stack = [System.Collections.Generic.List[string]]::new()
    $problems = [System.Collections.Generic.List[string]]::new()

    foreach ($match in [regex]::Matches($content, '<(/?)([a-zA-Z][a-zA-Z0-9-]*)\b[^>]*?(/?)>')) {
        $tag = $match.Groups[2].Value.ToLowerInvariant()
        $isClosing = $match.Groups[1].Value -eq '/'
        $isSelfClosing = $match.Groups[3].Value -eq '/'

        if ($isSelfClosing -or ($voidElements -contains $tag)) {
            continue
        }

        if (-not $isClosing) {
            [void]$stack.Add($tag)
            continue
        }

        if ($stack.Count -eq 0) {
            [void]$problems.Add(('zavírací </{0}> bez otevíracího' -f $tag))
            continue
        }

        $openTag = $stack[$stack.Count - 1]
        if ($openTag -ne $tag) {
            [void]$problems.Add(('</{0}> uzavírá <{1}> - nekonzistentní vnoření' -f $tag, $openTag))
            continue
        }

        $stack.RemoveAt($stack.Count - 1)
    }

    foreach ($unclosed in $stack) {
        [void]$problems.Add(('neuzavřený <{0}>' -f $unclosed))
    }

    return $problems.ToArray()
}

function Test-PromptFrontmatter {
    <#
    .SYNOPSIS
        Zkontroluje YAML frontmatter promptu.
    .DESCRIPTION
        Prompt musí začínat blokem `---`, obsahovat klíče `title`
        a `description` a blok uzavřít dalším `---`. Funkce vrací názvy
        chybějících částí, aby se dal problém přesně pojmenovat.
    .PARAMETER Path
        Cesta k `.md` souboru promptu.
    .OUTPUTS
        System.String[] - chybějící části; prázdné pole znamená OK
    .EXAMPLE
        Test-PromptFrontmatter -Path '.\prompts\00-system.md'
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    $missing = [System.Collections.Generic.List[string]]::new()
    $lines = @(Get-Content -LiteralPath $Path -Encoding utf8 | ForEach-Object { [string]$_ })

    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') {
        [void]$missing.Add('blok --- na prvním řádku')
        return $missing.ToArray()
    }

    $endIndex = -1
    for ($index = 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index].Trim() -eq '---') {
            $endIndex = $index
            break
        }
    }

    if ($endIndex -lt 0) {
        [void]$missing.Add('uzavírací ---')
        return $missing.ToArray()
    }

    $frontmatterText = ''
    if ($endIndex -gt 1) {
        $frontmatterText = ($lines[1..($endIndex - 1)]) -join "`n"
    }

    foreach ($key in @('title', 'description')) {
        if ($frontmatterText -notmatch ('(?m)^{0}\s*:' -f [regex]::Escape($key))) {
            [void]$missing.Add($key)
        }
    }

    return $missing.ToArray()
}

$root = Get-WorkspaceRoot
$manifest = Get-WorkspaceManifest
$checks = [System.Collections.Generic.List[object]]::new()
$started = Get-Date

if (-not $Json) {
    Write-Banner -Title 'Portable AI Workspace' -Subtitle ('Self-test - {0:yyyy-MM-dd HH:mm:ss}{1}' -f $started, $(if ($Fix) { ' (fix mode)' } else { '' }))
    Write-Log -Message ('Workspace: {0}' -f $root) -Level INFO
}

# --- 1. povinné adresáře ------------------------------------------------------
Write-Log -Message 'Kontrola 1/14: povinné adresáře' -Level DEBUG
$missingDirectories = @()
foreach ($directory in $manifest.Directories) {
    if (-not (Test-Path -LiteralPath (Join-Path -Path $root -ChildPath $directory) -PathType Container)) {
        $missingDirectories += $directory
    }
}

if ($Fix -and $missingDirectories.Count -gt 0) {
    foreach ($directory in $missingDirectories) {
        $target = Join-Path -Path $root -ChildPath $directory
        if ($PSCmdlet.ShouldProcess($target, 'Vytvořit chybějící adresář')) {
            New-Item -Path $target -ItemType Directory -Force | Out-Null
        }
    }
    $missingDirectories = @()
    foreach ($directory in $manifest.Directories) {
        if (-not (Test-Path -LiteralPath (Join-Path -Path $root -ChildPath $directory) -PathType Container)) {
            $missingDirectories += $directory
        }
    }
}

if ($missingDirectories.Count -eq 0) {
    Add-CheckResult -Results $checks -Id 'directories' -Name 'Povinné adresáře' -Status 'OK' -Detail ('{0}/{0} přítomno' -f $manifest.Directories.Count)
}
else {
    Add-CheckResult -Results $checks -Id 'directories' -Name 'Povinné adresáře' -Status 'FAIL' -Detail (('chybí: {0}' -f ($missingDirectories -join ', ')))
}

# --- 2. povinné soubory -------------------------------------------------------
Write-Log -Message 'Kontrola 2/14: povinné soubory' -Level DEBUG
$missingFiles = @()
foreach ($file in $manifest.Files) {
    if (-not (Test-Path -LiteralPath (Join-Path -Path $root -ChildPath $file) -PathType Leaf)) {
        $missingFiles += $file
    }
}

if ($missingFiles.Count -eq 0) {
    Add-CheckResult -Results $checks -Id 'files' -Name 'Povinné soubory' -Status 'OK' -Detail ('{0}/{0} přítomno' -f $manifest.Files.Count)
}
else {
    $preview = $missingFiles | Select-Object -First 10
    Add-CheckResult -Results $checks -Id 'files' -Name 'Povinné soubory' -Status 'FAIL' -Detail ('chybí {0}/{1}: {2}{3}' -f $missingFiles.Count, $manifest.Files.Count, ($preview -join ', '), $(if ($missingFiles.Count -gt 10) { ', ...' } else { '' }))
}

# --- 3. UTF-8 BOM u .ps1 ------------------------------------------------------
Write-Log -Message 'Kontrola 3/14: UTF-8 BOM' -Level DEBUG
$powerShellFiles = @(Get-ChildItem -LiteralPath $root -Recurse -File -Include '*.ps1' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\\.git\\' })
$missingBom = @()
foreach ($file in $powerShellFiles) {
    if (-not (Test-FileBom -Path $file.FullName)) {
        $missingBom += $file.FullName
    }
}

if ($Fix -and $missingBom.Count -gt 0) {
    foreach ($file in $missingBom) {
        if ($PSCmdlet.ShouldProcess($file, 'Přidat UTF-8 BOM')) {
            Add-Utf8Bom -Path $file
        }
    }
    $missingBom = @($missingBom | Where-Object { -not (Test-FileBom -Path $_) })
}

if ($missingBom.Count -eq 0) {
    Add-CheckResult -Results $checks -Id 'encoding' -Name 'UTF-8 BOM u .ps1' -Status 'OK' -Detail ('{0}/{0} má BOM' -f $powerShellFiles.Count)
}
else {
    Add-CheckResult -Results $checks -Id 'encoding' -Name 'UTF-8 BOM u .ps1' -Status 'FAIL' -Detail ('bez BOM: {0}' -f (($missingBom | ForEach-Object { Split-Path -Path $_ -Leaf }) -join ', '))
}

# --- 4. PSScriptAnalyzer ------------------------------------------------------
Write-Log -Message 'Kontrola 4/14: PSScriptAnalyzer' -Level DEBUG
$analyzerAvailable = [bool](Get-Module -ListAvailable -Name 'PSScriptAnalyzer' | Select-Object -First 1)
if (-not $analyzerAvailable) {
    Add-CheckResult -Results $checks -Id 'analyzer' -Name 'PSScriptAnalyzer' -Status 'WARN' -Detail 'modul není nainstalovaný - kontrola přeskočena (workspace nic neinstaluje globálně)'
}
else {
    $analyzerFindings = @()
    foreach ($file in $powerShellFiles) {
        $analyzerFindings += Invoke-ScriptAnalyzer -Path $file.FullName -Severity Warning, Error -ErrorAction SilentlyContinue
    }

    if ($analyzerFindings.Count -eq 0) {
        Add-CheckResult -Results $checks -Id 'analyzer' -Name 'PSScriptAnalyzer' -Status 'OK' -Detail ('{0}/{0} skriptů bez Warning/Error' -f $powerShellFiles.Count)
    }
    else {
        $summary = ($analyzerFindings | ForEach-Object { '{0}:{1} {2}' -f (Split-Path -Path $_.ScriptName -Leaf), $_.Line, $_.RuleName }) -join '; '
        Add-CheckResult -Results $checks -Id 'analyzer' -Name 'PSScriptAnalyzer' -Status 'FAIL' -Detail ('{0} nálezů - {1}' -f $analyzerFindings.Count, $summary)
    }
}

# --- 5. secrets ---------------------------------------------------------------
Write-Log -Message 'Kontrola 5/14: secrets' -Level DEBUG
$envExamplePath = Join-Path -Path $root -ChildPath '.env.example'
$gitAvailable = Test-Command -Name 'git'
$isGitRepo = $false
if ($gitAvailable) {
    & git -C $root rev-parse --is-inside-work-tree 2>$null | Out-Null
    $isGitRepo = ($LASTEXITCODE -eq 0)
}

$secretProblems = @()
if (-not (Test-Path -LiteralPath $envExamplePath -PathType Leaf)) {
    $secretProblems += 'chybí .env.example'
}
if ($isGitRepo) {
    & git -C $root check-ignore -q '.env' 2>$null
    if ($LASTEXITCODE -ne 0) {
        $secretProblems += '.env není v .gitignore'
    }
    & git -C $root ls-files --error-unmatch '.env' 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $secretProblems += '.env je trackovaný gitem'
    }
}

if ($secretProblems.Count -eq 0) {
    Add-CheckResult -Results $checks -Id 'secrets' -Name 'Secrets (.env)' -Status 'OK' -Detail '.env.example existuje, .env je ignorovaný a netrackovaný'
}
else {
    Add-CheckResult -Results $checks -Id 'secrets' -Name 'Secrets (.env)' -Status 'FAIL' -Detail ($secretProblems -join '; ')
}

# --- 6. Node.js ---------------------------------------------------------------
Write-Log -Message 'Kontrola 6/14: Node.js' -Level DEBUG
$nodeAvailable = Test-Command -Name 'node'
$requiredNodeVersion = [version]'22.19'
if (-not $nodeAvailable) {
    Add-CheckResult -Results $checks -Id 'node' -Name 'Node.js 22.19+' -Status 'FAIL' -Detail 'node není v PATH (workspace nic neinstaluje globálně)'
}
else {
    $nodeRaw = (& node '--version' 2>$null | Select-Object -First 1)
    $nodeVersion = $null
    if ($nodeRaw) {
        try {
            $nodeVersion = [version]([string]$nodeRaw).Trim().TrimStart('v')
        }
        catch [System.Management.Automation.RuntimeException] {
            Write-Log -Message ('Verzi Node nelze parsovat: {0}' -f $nodeRaw) -Level DEBUG
        }
    }

    if ($null -eq $nodeVersion) {
        Add-CheckResult -Results $checks -Id 'node' -Name 'Node.js 22.19+' -Status 'WARN' -Detail ('verzi nelze zjistit ({0})' -f $nodeRaw)
    }
    elseif ($nodeVersion -ge $requiredNodeVersion) {
        Add-CheckResult -Results $checks -Id 'node' -Name 'Node.js 22.19+' -Status 'OK' -Detail ('nalezena verze {0}' -f $nodeVersion)
    }
    else {
        Add-CheckResult -Results $checks -Id 'node' -Name 'Node.js 22.19+' -Status 'FAIL' -Detail ('nalezena verze {0}, požadováno 22.19+' -f $nodeVersion)
    }
}

# --- 7. git repozitář ---------------------------------------------------------
Write-Log -Message 'Kontrola 7/14: git repozitář' -Level DEBUG
if (-not $gitAvailable) {
    Add-CheckResult -Results $checks -Id 'git' -Name 'Git repozitář' -Status 'FAIL' -Detail 'git není v PATH'
}
elseif (-not $isGitRepo) {
    if ($Fix -and $PSCmdlet.ShouldProcess($root, 'git init')) {
        & git -C $root init 2>$null | Out-Null
        & git -C $root rev-parse --is-inside-work-tree 2>$null | Out-Null
        $isGitRepo = ($LASTEXITCODE -eq 0)
    }

    if ($isGitRepo) {
        Add-CheckResult -Results $checks -Id 'git' -Name 'Git repozitář' -Status 'OK' -Detail 'inicializováno příkazem git init'
    }
    else {
        Add-CheckResult -Results $checks -Id 'git' -Name 'Git repozitář' -Status 'WARN' -Detail 'workspace není git repozitář - spusťte Test-Workspace.ps1 -Fix'
    }
}
else {
    Add-CheckResult -Results $checks -Id 'git' -Name 'Git repozitář' -Status 'OK' -Detail 'git repozitář je inicializovaný'
}

# --- 8. řádkové koncovky ------------------------------------------------------
Write-Log -Message 'Kontrola 8/14: řádkové koncovky CRLF' -Level DEBUG
$crlfFiles = @($powerShellFiles.FullName)
$cmdFiles = @(Get-ChildItem -LiteralPath $root -Recurse -File -Include '*.cmd', '*.bat' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\\.git\\' } |
        Select-Object -ExpandProperty FullName)
$crlfTargets = @($crlfFiles + $cmdFiles | Sort-Object -Unique)

$wrongEol = @()
foreach ($file in $crlfTargets) {
    if (-not (Test-CrlfFile -Path $file)) {
        $wrongEol += $file
    }
}

if ($Fix -and $wrongEol.Count -gt 0) {
    foreach ($file in $wrongEol) {
        if ($PSCmdlet.ShouldProcess($file, 'Převést řádkové koncovky na CRLF')) {
            ConvertTo-CrlfFile -Path $file
        }
    }
    $wrongEol = @($wrongEol | Where-Object { -not (Test-CrlfFile -Path $_) })
}

if ($wrongEol.Count -eq 0) {
    Add-CheckResult -Results $checks -Id 'line-endings' -Name 'Řádkové koncovky (CRLF)' -Status 'OK' -Detail ('{0}/{0} souborů má CRLF' -f $crlfTargets.Count)
}
else {
    Add-CheckResult -Results $checks -Id 'line-endings' -Name 'Řádkové koncovky (CRLF)' -Status 'FAIL' -Detail ('LF místo CRLF: {0}' -f (($wrongEol | ForEach-Object { Split-Path -Path $_ -Leaf }) -join ', '))
}

# --- 9. LF u .md/.json/.toml --------------------------------------------------
Write-Log -Message 'Kontrola 9/14: LF u textových souborů' -Level DEBUG
$lfTargets = @(Get-ChildItem -LiteralPath $root -Recurse -File -Include '*.md', '*.json', '*.toml' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\\.git\\' } |
        Select-Object -ExpandProperty FullName)

$wrongLf = @()
foreach ($file in $lfTargets) {
    if (-not (Test-LfFile -Path $file)) {
        $wrongLf += $file
    }
}

if ($Fix -and $wrongLf.Count -gt 0) {
    foreach ($file in $wrongLf) {
        if ($PSCmdlet.ShouldProcess($file, 'Převést řádkové koncovky na LF')) {
            ConvertTo-LfFile -Path $file
        }
    }
    $wrongLf = @($wrongLf | Where-Object { -not (Test-LfFile -Path $_) })
}

if ($wrongLf.Count -eq 0) {
    Add-CheckResult -Results $checks -Id 'line-endings-lf' -Name 'Řádkové koncovky (LF)' -Status 'OK' -Detail ('{0}/{0} souborů má LF' -f $lfTargets.Count)
}
else {
    Add-CheckResult -Results $checks -Id 'line-endings-lf' -Name 'Řádkové koncovky (LF)' -Status 'FAIL' -Detail ('CRLF místo LF: {0}' -f (($wrongLf | ForEach-Object { Split-Path -Path $_ -Leaf }) -join ', '))
}

# --- 10. komentářová nápověda u .ps1 ------------------------------------------
Write-Log -Message 'Kontrola 10/14: komentářová nápověda' -Level DEBUG
$helpProblems = @()
foreach ($file in $powerShellFiles) {
    $missingSections = @(Test-ScriptCommentHelp -Path $file.FullName)
    if ($missingSections.Count -gt 0) {
        $helpProblems += ('{0} ({1})' -f $file.Name, ($missingSections -join ', '))
    }
}

if ($helpProblems.Count -eq 0) {
    Add-CheckResult -Results $checks -Id 'comment-help' -Name 'Komentářová nápověda' -Status 'OK' -Detail ('{0}/{0} skriptů má .SYNOPSIS, .DESCRIPTION a .EXAMPLE' -f $powerShellFiles.Count)
}
else {
    Add-CheckResult -Results $checks -Id 'comment-help' -Name 'Komentářová nápověda' -Status 'FAIL' -Detail ($helpProblems -join '; ')
}

# --- 11. relativní odkazy v README --------------------------------------------
Write-Log -Message 'Kontrola 11/14: relativní odkazy v README' -Level DEBUG
$readmePath = Join-Path -Path $root -ChildPath 'README.md'
$linkProblems = @()
$checkedLinks = 0

if (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) {
    $linkProblems += 'soubor README.md nenalezen'
}
else {
    foreach ($link in (Get-MarkdownRelativeLink -Path $readmePath)) {
        $checkedLinks++
        $linkTarget = Join-Path -Path $root -ChildPath $link
        if (-not (Test-Path -LiteralPath $linkTarget)) {
            $linkProblems += $link
        }
    }
}

if ($linkProblems.Count -eq 0) {
    Add-CheckResult -Results $checks -Id 'readme-links' -Name 'Odkazy v README.md' -Status 'OK' -Detail ('{0}/{0} relativních odkazů míří na existující cíl' -f $checkedLinks)
}
else {
    Add-CheckResult -Results $checks -Id 'readme-links' -Name 'Odkazy v README.md' -Status 'FAIL' -Detail ('neexistující cíl: {0}' -f ($linkProblems -join ', '))
}

# --- 12. struktura landing page -----------------------------------------------
Write-Log -Message 'Kontrola 12/14: struktura landing page' -Level DEBUG
$landingPath = Join-Path -Path $root -ChildPath 'landing/index.html'
if (-not (Test-Path -LiteralPath $landingPath -PathType Leaf)) {
    Add-CheckResult -Results $checks -Id 'landing-html' -Name 'Landing page (HTML)' -Status 'FAIL' -Detail 'soubor landing/index.html nenalezen'
}
else {
    $htmlProblems = @(Test-HtmlStructure -Path $landingPath)
    if ($htmlProblems.Count -eq 0) {
        Add-CheckResult -Results $checks -Id 'landing-html' -Name 'Landing page (HTML)' -Status 'OK' -Detail 'landing/index.html má spárované tagy'
    }
    else {
        Add-CheckResult -Results $checks -Id 'landing-html' -Name 'Landing page (HTML)' -Status 'FAIL' -Detail ($htmlProblems -join '; ')
    }
}

# --- 13. fáze v METAPROMPT.md -------------------------------------------------
Write-Log -Message 'Kontrola 13/14: fáze METAPROMPT.md' -Level DEBUG
$metapromptPath = Join-Path -Path $root -ChildPath 'METAPROMPT.md'
$phaseProblems = @()

if (-not (Test-Path -LiteralPath $metapromptPath -PathType Leaf)) {
    $phaseProblems += 'soubor METAPROMPT.md nenalezen'
}
else {
    $metapromptText = Get-Content -LiteralPath $metapromptPath -Raw -Encoding utf8
    $foundPhases = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($match in [regex]::Matches($metapromptText, 'FÁZE\s+(\d+)\b')) {
        [void]$foundPhases.Add([int]$match.Groups[1].Value)
    }
    for ($phase = 0; $phase -le 10; $phase++) {
        if (-not $foundPhases.Contains($phase)) {
            $phaseProblems += ('FÁZE {0}' -f $phase)
        }
    }
}

if ($phaseProblems.Count -eq 0) {
    Add-CheckResult -Results $checks -Id 'metaprompt-phases' -Name 'Fáze METAPROMPT.md' -Status 'OK' -Detail 'nalezeny fáze 0-10 (11 fází)'
}
else {
    Add-CheckResult -Results $checks -Id 'metaprompt-phases' -Name 'Fáze METAPROMPT.md' -Status 'FAIL' -Detail ('chybí: {0}' -f ($phaseProblems -join ', '))
}

# --- 14. YAML frontmatter u promptů -------------------------------------------
Write-Log -Message 'Kontrola 14/14: YAML frontmatter promptů' -Level DEBUG
$promptDirectory = Join-Path -Path $root -ChildPath 'prompts'
$frontmatterProblems = @()
$promptFileCount = 0

if (-not (Test-Path -LiteralPath $promptDirectory -PathType Container)) {
    $frontmatterProblems += 'adresář prompts/ nenalezen'
}
else {
    $promptFiles = @(Get-ChildItem -LiteralPath $promptDirectory -Recurse -File -Include '*.md' -ErrorAction SilentlyContinue)
    $promptFileCount = $promptFiles.Count

    if ($promptFileCount -eq 0) {
        $frontmatterProblems += 'v prompts/ nejsou žádné prompty'
    }

    foreach ($file in $promptFiles) {
        $missingParts = @(Test-PromptFrontmatter -Path $file.FullName)
        if ($missingParts.Count -gt 0) {
            $frontmatterProblems += ('{0} (chybí: {1})' -f $file.Name, ($missingParts -join ', '))
        }
    }
}

if ($frontmatterProblems.Count -eq 0) {
    Add-CheckResult -Results $checks -Id 'prompt-frontmatter' -Name 'YAML frontmatter promptů' -Status 'OK' -Detail ('{0}/{0} promptů má title a description' -f $promptFileCount)
}
else {
    Add-CheckResult -Results $checks -Id 'prompt-frontmatter' -Name 'YAML frontmatter promptů' -Status 'FAIL' -Detail ($frontmatterProblems -join '; ')
}

# --- Souhrn -------------------------------------------------------------------
if ($checks.Count -eq 0) {
    Add-CheckResult -Results $checks -Id 'selftest' -Name 'Self-test' -Status 'FAIL' -Detail 'nepodařilo se sesbírat výsledky kontrol - viz chyby výše'
}

$failCount = @($checks | Where-Object { $_.Status -eq 'FAIL' }).Count
$warnCount = @($checks | Where-Object { $_.Status -eq 'WARN' }).Count
$okCount = @($checks | Where-Object { $_.Status -eq 'OK' }).Count
$overall = 'PASS'
if ($failCount -gt 0) {
    $overall = 'FAIL'
}

$elapsed = (Get-Date) - $started

if ($Json) {
    $payload = [ordered]@{
        workspace = $root
        timestamp = $started.ToString('o')
        status    = $overall
        counts    = [ordered]@{ OK = $okCount; WARN = $warnCount; FAIL = $failCount }
        duration  = [math]::Round($elapsed.TotalSeconds, 2)
        checks    = $checks
    }
    $payload | ConvertTo-Json -Depth 6
}
else {
    Write-Log -Message 'Výsledky kontroly' -Level HEAD
    foreach ($check in $checks) {
        Write-Log -Message ('    {0}: {1}' -f $check.Name, $check.Detail) -Level $check.Status
    }
    Write-Log -Message ('    OK: {0} | WARN: {1} | FAIL: {2} | čas: {3:N2} s' -f $okCount, $warnCount, $failCount, $elapsed.TotalSeconds) -Level INFO
    Write-Log -Message ('=== WORKSPACE TEST: {0} ===' -f $overall) -Level $(if ($overall -eq 'PASS') { 'OK' } else { 'FAIL' })
}

if ($overall -eq 'FAIL') {
    exit 1
}

exit 0
