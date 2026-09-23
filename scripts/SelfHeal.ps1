<#
.SYNOPSIS
    Detekuje a opraví běžné odchylky portable AI workspace.
.DESCRIPTION
    Self-healing kontrola portable workspace. Odchylky nejdřív jen ohlásí
    (report-only je výchozí režim) a teprve s přepínačem -Fix je opraví.

    Kontroly:

      1. UTF-8 BOM u všech `.ps1` ve `scripts/` a `launcher/`
      2. řádkové koncovky podle `.gitattributes` (CRLF pro `.ps1`/`.cmd`/`.bat`,
         LF pro `.md`/`.json`/`.toml`/`.html`/`.css`/`.js`/`.yaml`/`.svg`)
      3. chybějící runtime adresáře (`bin/npm-global`, `data/reasonix`, `logs`)
      4. `bin/npm-global` v User PATH
      5. `env/.env` proti vzoru `env/.env.example`
      6. verze ve `VERSION` je zmíněná v `CHANGELOG.md`
      7. duplicitní záznamy v `PATH`
      8. untracked soubory v `git status`
      9. PSScriptAnalyzer nad `scripts/` a `launcher/`
     10. povinná komponenta `reasonix` v `bin/npm-global`
     11. escape artefakty v markdownu (`\#` na začátku řádku, `\*\*bold\*\*`)
     12. `scaffold/directory-tree.txt` je aktuální (obsahuje klíčové soubory
         a jeho hlavička není starší než 30 dní); `-Fix` strom přegeneruje

    Výchozí režim nic nemění. `-Fix` provádí jen bezpečné a idempotentní
    opravy: BOM, řádkové koncovky, chybějící adresáře, User PATH,
    chybějící `env/.env` ze vzoru a přegenerování `scaffold/directory-tree.txt`
    (kontrola 12). Kombinace `-Fix -WhatIf` jen vypíše, co by se změnilo.
    Obsah ostatních existujících souborů se nikdy nepřepisuje - výjimkou
    je právě strom adresářů, který se generuje znovu skriptem
    `scripts/Update-Tree.ps1`.

    Návratový kód: 0 = bez FAIL, 1 = alespoň jeden FAIL.
.PARAMETER Fix
    Provede bezpečné a idempotentní opravy. Bez tohoto přepínače skript
    pouze reportuje, i když najde odchylky.
.PARAMETER SkipAnalyzer
    Přeskočí kontrolu PSScriptAnalyzerem (rychlejší běh).
.PARAMETER Json
    Vypíše strukturovaný JSON místo lidského výstupu.
.EXAMPLE
    .\SelfHeal.ps1
.EXAMPLE
    .\SelfHeal.ps1 -WhatIf
.EXAMPLE
    .\SelfHeal.ps1 -Fix
.EXAMPLE
    .\SelfHeal.ps1 -Json -Fix -SkipAnalyzer
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [switch]$Fix,

    [Parameter()]
    [switch]$SkipAnalyzer,

    [Parameter()]
    [switch]$Json
)

. (Join-Path -Path $PSScriptRoot -ChildPath '_common.ps1')

function Add-HealFinding {
    <#
    .SYNOPSIS
        Přidá výsledek jedné self-heal kontroly do seznamu.
    .DESCRIPTION
        Drží jednotný tvar nálezu, který se dá vypsat lidsky i serializovat
        do JSON. Volitelný `Hint` nese konkrétní návod, co udělat.
    .PARAMETER Results
        Seznam nálezů (List[object]).
    .PARAMETER Id
        Strojový identifikátor kontroly.
    .PARAMETER Name
        Lidský název kontroly.
    .PARAMETER Status
        Stav: OK, WARN nebo FAIL.
    .PARAMETER Detail
        Detail vysvětlující výsledek.
    .PARAMETER Hint
        Návod, co s nálezem dělat. Prázdný řetězec znamená "bez návodu".
    .EXAMPLE
        Add-HealFinding -Results $findings -Id 'bom' -Name 'UTF-8 BOM' -Status 'OK'
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
        [string]$Detail = '',

        [Parameter()]
        [AllowEmptyString()]
        [string]$Hint = ''
    )

    [void]$Results.Add([ordered]@{
            Id     = $Id
            Name   = $Name
            Status = $Status
            Detail = $Detail
            Hint   = $Hint
        })
}

function Test-FileBom {
    <#
    .SYNOPSIS
        Zjistí, zda soubor začíná UTF-8 BOM.
    .DESCRIPTION
        Porovná první tři bajty souboru s UTF-8 BOM (EF BB BF).
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

function Resolve-ExistingFile {
    <#
    .SYNOPSIS
        Vrátí absolutní cestu k existujícímu souboru, jinak skončí chybou.
    .DESCRIPTION
        Ochrana proti překlepům a relativním cestám. Bez tohoto ověření by
        zápis mohl místo opravy existujícího souboru vytvořit soubor nový
        (např. `Menu.ps1` v aktuálním adresáři) a tiše tak poškodit workspace.
    .PARAMETER Path
        Cesta k souboru.
    .OUTPUTS
        System.String
    .EXAMPLE
        Resolve-ExistingFile -Path '.\launcher\Menu.ps1'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw ('Soubor nenalezen: {0}' -f $fullPath)
    }

    return $fullPath
}

function Add-FileBom {
    <#
    .SYNOPSIS
        Přidá do souboru UTF-8 BOM, pokud tam ještě není.
    .DESCRIPTION
        Zachová veškerý obsah včetně řádkových koncovek. Operace je
        idempotentní - soubor s BOM se nezmění.
    .PARAMETER Path
        Cesta k souboru.
    .EXAMPLE
        Add-FileBom -Path '.\scripts\_common.ps1'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    $targetPath = Resolve-ExistingFile -Path $Path
    if (Test-FileBom -Path $targetPath) {
        return
    }

    $bytes = [System.IO.File]::ReadAllBytes($targetPath)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    [System.IO.File]::WriteAllText($targetPath, $text, [System.Text.UTF8Encoding]::new($true))
}

function Test-CrlfContent {
    <#
    .SYNOPSIS
        Zjistí, zda soubor používá výhradně CRLF řádkové koncovky.
    .DESCRIPTION
        Hledá osamocený LF bajt (0x0A) bez předcházejícího CR (0x0D).
    .PARAMETER Path
        Cesta k souboru.
    .OUTPUTS
        System.Boolean
    .EXAMPLE
        Test-CrlfContent -Path '.\launcher\Menu.ps1'
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

function Test-LfContent {
    <#
    .SYNOPSIS
        Zjistí, zda soubor neobsahuje žádné CRLF řádkové koncovky.
    .DESCRIPTION
        Opak `Test-CrlfContent`. Textový soubor, který má používat LF, nesmí
        obsahovat CR před LF.
    .PARAMETER Path
        Cesta k souboru.
    .OUTPUTS
        System.Boolean
    .EXAMPLE
        Test-LfContent -Path '.\README.md'
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

function ConvertTo-CrlfContent {
    <#
    .SYNOPSIS
        Převede řádkové koncovky souboru na CRLF.
    .DESCRIPTION
        Zachová UTF-8 BOM, pokud v souboru byl. Operace je idempotentní.
    .PARAMETER Path
        Cesta k souboru.
    .EXAMPLE
        ConvertTo-CrlfContent -Path '.\Start.cmd'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    $targetPath = Resolve-ExistingFile -Path $Path
    $hasBom = Test-FileBom -Path $targetPath
    $bytes = [System.IO.File]::ReadAllBytes($targetPath)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($hasBom) {
        $text = $text.Substring(1)
    }

    $normalized = ($text -replace "`r`n", "`n") -replace "`n", "`r`n"
    [System.IO.File]::WriteAllText($targetPath, $normalized, [System.Text.UTF8Encoding]::new($hasBom))
}

function ConvertTo-LfContent {
    <#
    .SYNOPSIS
        Převede řádkové koncovky souboru na LF.
    .DESCRIPTION
        Zachová UTF-8 BOM, pokud v souboru byl. Operace je idempotentní.
    .PARAMETER Path
        Cesta k souboru.
    .EXAMPLE
        ConvertTo-LfContent -Path '.\README.md'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    $targetPath = Resolve-ExistingFile -Path $Path
    $hasBom = Test-FileBom -Path $targetPath
    $bytes = [System.IO.File]::ReadAllBytes($targetPath)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($hasBom) {
        $text = $text.Substring(1)
    }

    $normalized = $text -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($targetPath, $normalized, [System.Text.UTF8Encoding]::new($hasBom))
}

function Get-EolRule {
    <#
    .SYNOPSIS
        Načte pravidla řádkových koncovek z `.gitattributes`.
    .DESCRIPTION
        Parsuje řádky s `eol=crlf` a `eol=lf` a vrací je v pořadí, v jakém
        jsou v souboru. Pořadí je důležité: platí poslední odpovídající
        pravidlo, stejně jako v gitu. Řádky bez `eol=` (např. `binary`)
        se přeskakují.
    .PARAMETER Path
        Cesta k `.gitattributes`.
    .OUTPUTS
        Objects with Pattern and Eol properties.
    .EXAMPLE
        Get-EolRule -Path '.\.gitattributes'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    $rules = [System.Collections.Generic.List[object]]::new()
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $rules
    }

    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        $match = [regex]::Match($trimmed, '^(?<pattern>\S+)\s+.*eol=(?<eol>crlf|lf)\b')
        if ($match.Success) {
            [void]$rules.Add([pscustomobject]@{
                    Pattern = $match.Groups['pattern'].Value
                    Eol     = $match.Groups['eol'].Value
                })
        }
    }

    return $rules
}

function Get-ExpectedEol {
    <#
    .SYNOPSIS
        Vrátí očekávanou koncovku řádku pro daný název souboru.
    .DESCRIPTION
        Projde pravidla v pořadí a vrátí poslední odpovídající hodnotu
        (`crlf`, `lf`). Když souboru žádné pravidlo neodpovídá, vrátí
        `$null` - takový soubor se nekontroluje.
    .PARAMETER Name
        Název souboru (např. `Menu.ps1`).
    .PARAMETER Rules
        Pravidla z `Get-EolRule`.
    .OUTPUTS
        System.String - 'crlf', 'lf' nebo $null
    .EXAMPLE
        Get-ExpectedEol -Name 'README.md' -Rules $rules
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory = $true, Position = 1)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Rules
    )

    $expected = $null
    foreach ($rule in $Rules) {
        if ($Name -like $rule.Pattern) {
            $expected = $rule.Eol
        }
    }

    return $expected
}

function Test-ExcludedPath {
    <#
    .SYNOPSIS
        Zjistí, zda cesta patří mezi runtime a vendor adresáře.
    .DESCRIPTION
        Vylučuje `.git`, `node_modules`, `bin`, `logs`, `data` a `temp` -
        tedy cesty, které plní npm nebo si je workspace generuje za běhu.
        Vlastní kód ve `scripts/` a `launcher/` vyloučený není.
    .PARAMETER Path
        Absolutní cesta k souboru.
    .OUTPUTS
        System.Boolean
    .EXAMPLE
        Test-ExcludedPath -Path 'C:\portableAI\logs\setup.log'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    foreach ($pattern in $script:ExcludedPathPatterns) {
        if ($Path -match $pattern) {
            return $true
        }
    }

    return $false
}

function Get-MarkdownEscapeArtifact {
    <#
    .SYNOPSIS
        Najde escape artefakty v markdownu.
    .DESCRIPTION
        Hledá známky poškození vzniklého kopírováním textu: escapovaný
        nadpis (`\#` na začátku řádku) a escapovaný bold (`\*\*`).

        Falešné poplachy se potlačují: obsah inline kódu a bloků kódu se
        neposuzuje, protože tam může být escapování záměrné (dokumentace
        vzorů a regexů). Běžné Windows cesty (`env\.env`) ani escapované
        tečky v číslovaných seznamech se nehlásí.
    .PARAMETER Path
        Cesta k `.md` souboru.
    .OUTPUTS
        System.String - čísla řádků s nálezem
    .EXAMPLE
        Get-MarkdownEscapeArtifact -Path '.\METAPROMPT.md'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    $findings = [System.Collections.Generic.List[string]]::new()
    $lines = [System.IO.File]::ReadAllLines($Path)
    $insideCodeBlock = $false
    for ($index = 0; $index -lt $lines.Length; $index++) {
        $line = $lines[$index]
        if ($line -match '^\s*```') {
            $insideCodeBlock = -not $insideCodeBlock
            continue
        }
        if ($insideCodeBlock) {
            continue
        }

        $outsideCode = [regex]::Replace($line, '`[^`]*`', '')
        if ($outsideCode -match '^\s*\\#{1,6}\s' -or $outsideCode -match '\\\*\\\*') {
            [void]$findings.Add(($index + 1))
        }
    }

    return $findings
}

function Get-DirectoryTreeState {
    <#
    .SYNOPSIS
        Vyhodnotí stav `scaffold/directory-tree.txt` pro kontrolu 12.
    .DESCRIPTION
        Vrací hashtable s klíči:

          Exists      - soubor existuje
          Problems    - seznam nalezených problémů (prázdný seznam = OK)
          GeneratedAt - datum z hlavičky, nebo `$null`
          AgeDays     - stáří hlavičky ve dnech (nikdy záporné)

        Strom vypisuje jen názvy položek (ne celé cesty), proto se klíčové
        soubory hledají jako jméno na řádku s větví stromu. Funkce se volá
        dvakrát: před opravou a po ní.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [string[]]$KeyFile = @('ci.yml', 'SECURITY.md', 'VERSION'),

        [Parameter()]
        [int]$MaxAgeDays = 30
    )

    $problems = [System.Collections.Generic.List[string]]::new()
    $state = @{
        Exists      = $false
        Problems    = $problems
        GeneratedAt = $null
        AgeDays     = 0.0
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        [void]$problems.Add('soubor chybí')
        return $state
    }

    $state.Exists = $true
    $text = Get-Content -LiteralPath $Path -Raw

    foreach ($key in $KeyFile) {
        if ($text -notmatch ('(?m)^[^\r\n]*──\s+' + [regex]::Escape($key) + '\s*$')) {
            [void]$problems.Add(('chybí záznam {0}' -f $key))
        }
    }

    $generatedAt = [datetime]::MinValue
    $generatedMatch = [regex]::Match($text, '(?m)^#\s*Vygenerováno:\s*(\d{4}-\d{2}-\d{2}(?: \d{2}:\d{2}:\d{2})?)')
    $hasGeneratedAt = $false
    if ($generatedMatch.Success) {
        $hasGeneratedAt = [datetime]::TryParse(
            $generatedMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::None,
            [ref]$generatedAt
        )
    }

    if (-not $hasGeneratedAt) {
        [void]$problems.Add('v hlavičce chybí datum generování')
        return $state
    }

    $state.GeneratedAt = $generatedAt
    $ageDays = ((Get-Date) - $generatedAt).TotalDays
    if ($ageDays -lt 0) {
        # Hlavička nese lokální čas generátoru; na stroji v jiném pásmu
        # (například UTC runner v CI) vyjde stáří mírně do minusu.
        $ageDays = 0
    }

    $state.AgeDays = $ageDays
    if ($ageDays -gt $MaxAgeDays) {
        [void]$problems.Add(('hlavička je starší než {0} dní ({1:N0} dní)' -f $MaxAgeDays, $ageDays))
    }

    return $state
}

# Adresáře, které se neskenují: plní je npm nebo si je workspace generuje
# za běhu. Stejná množina jako v `Test-Workspace.ps1`.
$script:ExcludedPathPatterns = @(
    '\\node_modules\\'
    '\\bin\\'
    '\\.git\\'
    '\\logs\\'
    '\\data\\'
    '\\temp\\'
    '\\tmp\\'
)

$root = Get-WorkspaceRoot
$findings = [System.Collections.Generic.List[object]]::new()
$started = Get-Date
$canFix = $Fix -and -not $WhatIfPreference
$fixHint = 'Spusťte .\SelfHeal.ps1 -Fix'
if ($WhatIfPreference) {
    $fixHint = 'Spusťte stejný příkaz bez -WhatIf'
}

if (-not $Json) {
    $mode = 'report only'
    if ($Fix) {
        $mode = 'fix'
        if ($WhatIfPreference) {
            $mode = 'fix (whatif - nic se nemění)'
        }
    }
    Write-Banner -Title 'Portable AI Workspace' -Subtitle ('Self-heal - {0:yyyy-MM-dd HH:mm:ss} ({1})' -f $started, $mode)
    Write-Log -Message ('Workspace: {0}' -f $root) -Level INFO
}

# --- 1. UTF-8 BOM u .ps1 ------------------------------------------------------
Write-Log -Message 'Self-heal 1/12: UTF-8 BOM u .ps1' -Level DEBUG
$scriptTargets = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
foreach ($relativeDirectory in @('scripts', 'launcher')) {
    $directoryPath = Join-Path -Path $root -ChildPath $relativeDirectory
    if (-not (Test-Path -LiteralPath $directoryPath -PathType Container)) {
        continue
    }
    foreach ($file in (Get-ChildItem -LiteralPath $directoryPath -Recurse -File -Include '*.ps1' -ErrorAction SilentlyContinue)) {
        [void]$scriptTargets.Add($file)
    }
}

$missingBom = [System.Collections.Generic.List[string]]::new()
foreach ($file in $scriptTargets) {
    if (-not (Test-FileBom -Path $file.FullName)) {
        [void]$missingBom.Add($file.FullName)
    }
}

$bomRepaired = 0
if ($canFix) {
    foreach ($path in $missingBom.ToArray()) {
        if ($PSCmdlet.ShouldProcess($path, 'Přidat UTF-8 BOM')) {
            Add-FileBom -Path $path
            $bomRepaired++
        }
    }
    $missingBom.Clear()
    foreach ($file in $scriptTargets) {
        if (-not (Test-FileBom -Path $file.FullName)) {
            [void]$missingBom.Add($file.FullName)
        }
    }
}

if ($missingBom.Count -eq 0) {
    $detail = '{0}/{0} souborů má BOM' -f $scriptTargets.Count
    if ($bomRepaired -gt 0) {
        $detail = '{0} (opraveno: {1})' -f $detail, $bomRepaired
    }
    Add-HealFinding -Results $findings -Id 'bom' -Name 'UTF-8 BOM u .ps1' -Status 'OK' -Detail $detail
}
else {
    Add-HealFinding -Results $findings -Id 'bom' -Name 'UTF-8 BOM u .ps1' -Status 'FAIL' -Detail ('bez BOM: {0}' -f (($missingBom | ForEach-Object { Split-Path -Path $_ -Leaf }) -join ', ')) -Hint $fixHint
}

# --- 2. řádkové koncovky podle .gitattributes ---------------------------------
Write-Log -Message 'Self-heal 2/12: řádkové koncovky podle .gitattributes' -Level DEBUG
$eolRules = Get-EolRule -Path (Join-Path -Path $root -ChildPath '.gitattributes')
$eolInclude = @($eolRules | ForEach-Object { $_.Pattern } | Sort-Object -Unique)

if ($eolInclude.Count -eq 0) {
    Add-HealFinding -Results $findings -Id 'line-endings' -Name 'Řádkové koncovky' -Status 'WARN' -Detail 'z .gitattributes nelze načíst žádné pravidlo eol=' -Hint 'Doplňte .gitattributes (viz .editorconfig)'
}
else {
    $eolTargets = @(Get-ChildItem -LiteralPath $root -Recurse -File -Include $eolInclude -ErrorAction SilentlyContinue |
            Where-Object { -not (Test-ExcludedPath -Path $_.FullName) })

    $wrongCrlf = [System.Collections.Generic.List[string]]::new()
    $wrongLf = [System.Collections.Generic.List[string]]::new()
    foreach ($file in $eolTargets) {
        $expected = Get-ExpectedEol -Name $file.Name -Rules $eolRules
        if ($null -eq $expected) {
            continue
        }

        if ($expected -eq 'crlf') {
            if (-not (Test-CrlfContent -Path $file.FullName)) {
                [void]$wrongCrlf.Add($file.FullName)
            }
        }
        elseif (-not (Test-LfContent -Path $file.FullName)) {
            [void]$wrongLf.Add($file.FullName)
        }
    }

    $eolRepaired = 0
    if ($canFix) {
        foreach ($path in $wrongCrlf.ToArray()) {
            if ($PSCmdlet.ShouldProcess($path, 'Převést koncovky na CRLF')) {
                ConvertTo-CrlfContent -Path $path
                $eolRepaired++
            }
        }
        foreach ($path in $wrongLf.ToArray()) {
            if ($PSCmdlet.ShouldProcess($path, 'Převést koncovky na LF')) {
                ConvertTo-LfContent -Path $path
                $eolRepaired++
            }
        }
        $wrongCrlf.Clear()
        $wrongLf.Clear()
        foreach ($file in $eolTargets) {
            $expected = Get-ExpectedEol -Name $file.Name -Rules $eolRules
            if ($null -eq $expected) {
                continue
            }

            if ($expected -eq 'crlf') {
                if (-not (Test-CrlfContent -Path $file.FullName)) {
                    [void]$wrongCrlf.Add($file.Name)
                }
            }
            elseif (-not (Test-LfContent -Path $file.FullName)) {
                [void]$wrongLf.Add($file.Name)
            }
        }
    }

    $eolProblems = [System.Collections.Generic.List[string]]::new()
    if ($wrongCrlf.Count -gt 0) {
        [void]$eolProblems.Add(('LF místo CRLF: {0}' -f (($wrongCrlf | ForEach-Object { Split-Path -Path $_ -Leaf }) -join ', ')))
    }
    if ($wrongLf.Count -gt 0) {
        [void]$eolProblems.Add(('CRLF místo LF: {0}' -f (($wrongLf | ForEach-Object { Split-Path -Path $_ -Leaf }) -join ', ')))
    }

    if ($eolProblems.Count -eq 0) {
        $detail = '{0}/{0} souborů má správné koncovky' -f $eolTargets.Count
        if ($eolRepaired -gt 0) {
            $detail = '{0} (opraveno: {1})' -f $detail, $eolRepaired
        }
        Add-HealFinding -Results $findings -Id 'line-endings' -Name 'Řádkové koncovky' -Status 'OK' -Detail $detail
    }
    else {
        Add-HealFinding -Results $findings -Id 'line-endings' -Name 'Řádkové koncovky' -Status 'FAIL' -Detail ($eolProblems -join '; ') -Hint $fixHint
    }
}

# --- 3. runtime adresáře ------------------------------------------------------
Write-Log -Message 'Self-heal 3/12: runtime adresáře' -Level DEBUG
$requiredDirectories = @('bin/npm-global', 'data/reasonix', 'logs')
$missingDirectories = [System.Collections.Generic.List[string]]::new()
foreach ($relative in $requiredDirectories) {
    if (-not (Test-Path -LiteralPath (Join-Path -Path $root -ChildPath $relative) -PathType Container)) {
        [void]$missingDirectories.Add($relative)
    }
}

$directoryRepaired = 0
if ($canFix) {
    foreach ($relative in $missingDirectories.ToArray()) {
        $targetPath = Join-Path -Path $root -ChildPath $relative
        if ($PSCmdlet.ShouldProcess($targetPath, 'Vytvořit runtime adresář')) {
            New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
            $directoryRepaired++
        }
    }
    $missingDirectories.Clear()
    foreach ($relative in $requiredDirectories) {
        if (-not (Test-Path -LiteralPath (Join-Path -Path $root -ChildPath $relative) -PathType Container)) {
            [void]$missingDirectories.Add($relative)
        }
    }
}

if ($missingDirectories.Count -eq 0) {
    $detail = '{0}/{0} runtime adresářů existuje' -f $requiredDirectories.Count
    if ($directoryRepaired -gt 0) {
        $detail = '{0} (vytvořeno: {1})' -f $detail, $directoryRepaired
    }
    Add-HealFinding -Results $findings -Id 'directories' -Name 'Runtime adresáře' -Status 'OK' -Detail $detail
}
else {
    Add-HealFinding -Results $findings -Id 'directories' -Name 'Runtime adresáře' -Status 'FAIL' -Detail ('chybí: {0}' -f ($missingDirectories -join ', ')) -Hint $fixHint
}

# --- 4. bin/npm-global v User PATH --------------------------------------------
Write-Log -Message 'Self-heal 4/12: User PATH' -Level DEBUG
$npmPrefixPath = Join-Path -Path $root -ChildPath 'bin/npm-global'
$userPathRaw = [Environment]::GetEnvironmentVariable('PATH', 'User')
$userPathEntries = @()
if (-not [string]::IsNullOrWhiteSpace($userPathRaw)) {
    $userPathEntries = @($userPathRaw -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

$prefixInUserPath = $false
foreach ($entry in $userPathEntries) {
    if ($entry.TrimEnd('\') -ieq $npmPrefixPath.TrimEnd('\')) {
        $prefixInUserPath = $true
    }
}

$userPathRepaired = $false
if (-not $prefixInUserPath -and $canFix) {
    if ($PSCmdlet.ShouldProcess($npmPrefixPath, 'Přidat do User PATH')) {
        $newUserPath = (@($userPathEntries) + $npmPrefixPath) -join ';'
        [Environment]::SetEnvironmentVariable('PATH', $newUserPath, 'User')
        $userPathRepaired = $true
    }
}

if ($prefixInUserPath -or $userPathRepaired) {
    $detail = 'bin/npm-global je v User PATH'
    if ($userPathRepaired) {
        $detail = 'bin/npm-global přidán do User PATH (nová shell session)'
    }
    Add-HealFinding -Results $findings -Id 'user-path' -Name 'User PATH' -Status 'OK' -Detail $detail
}
else {
    Add-HealFinding -Results $findings -Id 'user-path' -Name 'User PATH' -Status 'WARN' -Detail 'bin/npm-global není v User PATH' -Hint ('Nástroje pak fungují jen přes launcher. {0}' -f $fixHint)
}

# --- 5. env/.env proti vzoru --------------------------------------------------
Write-Log -Message 'Self-heal 5/12: env/.env' -Level DEBUG
$existingDotEnv = $null
foreach ($relative in @('env/.env', '.env')) {
    $candidatePath = Join-Path -Path $root -ChildPath $relative
    if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
        $existingDotEnv = $relative
        break
    }
}

$envTemplatePath = $null
$envTemplateName = ''
foreach ($relative in @('env/.env.example', '.env.example')) {
    $candidatePath = Join-Path -Path $root -ChildPath $relative
    if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
        $envTemplatePath = $candidatePath
        $envTemplateName = $relative
        break
    }
}

$dotEnvCreated = $false
if ($existingDotEnv) {
    Add-HealFinding -Results $findings -Id 'dotenv' -Name 'Konfigurace .env' -Status 'OK' -Detail ('nalezen {0}' -f $existingDotEnv)
}
elseif ($null -eq $envTemplatePath) {
    Add-HealFinding -Results $findings -Id 'dotenv' -Name 'Konfigurace .env' -Status 'WARN' -Detail 'chybí .env i vzor .env.example' -Hint 'Obnovte .env.example z repozitáře'
}
else {
    $targetDotEnv = Join-Path -Path $root -ChildPath 'env/.env'
    if ($canFix -and $PSCmdlet.ShouldProcess($targetDotEnv, ('Vytvořit ze vzoru {0}' -f $envTemplateName))) {
        $templateLines = Get-Content -LiteralPath $envTemplatePath -Encoding utf8
        [System.IO.File]::WriteAllLines($targetDotEnv, $templateLines, [System.Text.UTF8Encoding]::new($false))
        $dotEnvCreated = $true
    }

    if ($dotEnvCreated) {
        Add-HealFinding -Results $findings -Id 'dotenv' -Name 'Konfigurace .env' -Status 'OK' -Detail ('vytvořen env/.env ze vzoru {0}' -f $envTemplateName) -Hint 'Doplňte DEEPSEEK_API_KEY'
    }
    else {
        Add-HealFinding -Results $findings -Id 'dotenv' -Name 'Konfigurace .env' -Status 'WARN' -Detail ('env/.env chybí, vzor {0} je k dispozici' -f $envTemplateName) -Hint $fixHint
    }
}

# --- 6. VERSION vs CHANGELOG --------------------------------------------------
Write-Log -Message 'Self-heal 6/12: VERSION vs CHANGELOG' -Level DEBUG
$versionPath = Join-Path -Path $root -ChildPath 'VERSION'
$changelogPath = Join-Path -Path $root -ChildPath 'CHANGELOG.md'

if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf) -or -not (Test-Path -LiteralPath $changelogPath -PathType Leaf)) {
    Add-HealFinding -Results $findings -Id 'version' -Name 'VERSION vs CHANGELOG' -Status 'WARN' -Detail 'chybí VERSION nebo CHANGELOG.md'
}
else {
    $workspaceVersion = (Get-Content -LiteralPath $versionPath -Raw).Trim()
    $changelogText = Get-Content -LiteralPath $changelogPath -Raw
    $versionPattern = '(?m)^##\s*\[' + [regex]::Escape($workspaceVersion) + '\]'

    if ($changelogText -match $versionPattern) {
        Add-HealFinding -Results $findings -Id 'version' -Name 'VERSION vs CHANGELOG' -Status 'OK' -Detail ('verze {0} je v CHANGELOG.md' -f $workspaceVersion)
    }
    else {
        Add-HealFinding -Results $findings -Id 'version' -Name 'VERSION vs CHANGELOG' -Status 'WARN' -Detail ('verze {0} není v CHANGELOG.md' -f $workspaceVersion) -Hint 'Doplňte sekci [Unreleased] nebo novou verzi'
    }
}

# --- 7. duplicity v PATH ------------------------------------------------------
Write-Log -Message 'Self-heal 7/12: duplicity v PATH' -Level DEBUG
$pathEntries = @($env:PATH -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$seenEntries = [System.Collections.Generic.HashSet[string]]::new()
$duplicateEntries = [System.Collections.Generic.List[string]]::new()
foreach ($entry in $pathEntries) {
    $normalizedEntry = $entry.TrimEnd('\').ToLowerInvariant()
    if (-not $seenEntries.Add($normalizedEntry) -and -not $duplicateEntries.Contains($normalizedEntry)) {
        [void]$duplicateEntries.Add($normalizedEntry)
    }
}

if ($duplicateEntries.Count -eq 0) {
    Add-HealFinding -Results $findings -Id 'path-duplicates' -Name 'Duplicity v PATH' -Status 'OK' -Detail ('{0} záznamů bez duplicit' -f $pathEntries.Count)
}
else {
    Add-HealFinding -Results $findings -Id 'path-duplicates' -Name 'Duplicity v PATH' -Status 'WARN' -Detail ('duplicitní záznamy: {0}' -f ($duplicateEntries -join ', ')) -Hint 'Zkontrolujte User PATH a odstraněte duplicity ručně'
}

# --- 8. git status ------------------------------------------------------------
Write-Log -Message 'Self-heal 8/12: git status' -Level DEBUG
if (-not (Test-Command -Name 'git')) {
    Add-HealFinding -Results $findings -Id 'git-status' -Name 'Git status' -Status 'WARN' -Detail 'git není v PATH'
}
else {
    $gitPorcelain = @(& git -C $root status --porcelain 2>$null)
    if ($LASTEXITCODE -ne 0) {
        Add-HealFinding -Results $findings -Id 'git-status' -Name 'Git status' -Status 'WARN' -Detail 'workspace není git repozitář'
    }
    else {
        $untrackedFiles = @($gitPorcelain | Where-Object { $_.StartsWith('??') })
        if ($untrackedFiles.Count -eq 0) {
            Add-HealFinding -Results $findings -Id 'git-status' -Name 'Git status' -Status 'OK' -Detail 'žádné untracked soubory'
        }
        else {
            $untrackedPreview = @($untrackedFiles | Select-Object -First 5 | ForEach-Object { $_.Substring(3) })
            Add-HealFinding -Results $findings -Id 'git-status' -Name 'Git status' -Status 'WARN' -Detail ('untracked souborů: {0} ({1})' -f $untrackedFiles.Count, ($untrackedPreview -join ', ')) -Hint 'Přidejte je do gitu nebo do .gitignore'
        }
    }
}

# --- 9. PSScriptAnalyzer ------------------------------------------------------
Write-Log -Message 'Self-heal 9/12: PSScriptAnalyzer' -Level DEBUG
$analyzerDirectories = @()
foreach ($relative in @('scripts', 'launcher')) {
    $directoryPath = Join-Path -Path $root -ChildPath $relative
    if (Test-Path -LiteralPath $directoryPath -PathType Container) {
        $analyzerDirectories += $directoryPath
    }
}

if ($SkipAnalyzer) {
    Add-HealFinding -Results $findings -Id 'analyzer' -Name 'PSScriptAnalyzer' -Status 'WARN' -Detail 'přeskočeno (-SkipAnalyzer)'
}
elseif (-not (Get-Module -ListAvailable -Name 'PSScriptAnalyzer' | Select-Object -First 1)) {
    Add-HealFinding -Results $findings -Id 'analyzer' -Name 'PSScriptAnalyzer' -Status 'WARN' -Detail 'modul není nainstalovaný - kontrola přeskočena' -Hint 'npm/PSGallery instalace není součástí workspace'
}
else {
    $analyzerFindings = @()
    foreach ($directoryPath in $analyzerDirectories) {
        # Analyza je read-only - pod -WhatIf ji chceme opravdu spustit,
        # proto se WhatIf pro tento cmdlet explicitne vypina.
        $analyzerFindings += Invoke-ScriptAnalyzer -Path $directoryPath -Recurse -Severity Warning, Error -WhatIf:$false -ErrorAction SilentlyContinue
    }

    if ($analyzerFindings.Count -eq 0) {
        Add-HealFinding -Results $findings -Id 'analyzer' -Name 'PSScriptAnalyzer' -Status 'OK' -Detail 'scripts a launcher bez Warning/Error'
    }
    else {
        $analyzerSummary = ($analyzerFindings | ForEach-Object { '{0}:{1} {2}' -f (Split-Path -Path $_.ScriptName -Leaf), $_.Line, $_.RuleName }) -join '; '
        Add-HealFinding -Results $findings -Id 'analyzer' -Name 'PSScriptAnalyzer' -Status 'FAIL' -Detail ('nálezů: {0} - {1}' -f $analyzerFindings.Count, $analyzerSummary) -Hint 'Opravte nálezy v příslušném skriptu'
    }
}

# --- 10. povinná komponenta reasonix ------------------------------------------
Write-Log -Message 'Self-heal 10/12: povinná komponenta reasonix' -Level DEBUG
$requiredComponentShim = Join-Path -Path $npmPrefixPath -ChildPath 'reasonix.cmd'
if (Test-Path -LiteralPath $requiredComponentShim -PathType Leaf) {
    Add-HealFinding -Results $findings -Id 'component-reasonix' -Name 'Komponenta reasonix' -Status 'OK' -Detail 'nalezena v bin/npm-global'
}
elseif (Test-Command -Name 'reasonix') {
    Add-HealFinding -Results $findings -Id 'component-reasonix' -Name 'Komponenta reasonix' -Status 'WARN' -Detail 'nalezena v PATH mimo workspace - není přenositelná' -Hint 'Nainstalujte ji do bin/npm-global přes Setup'
}
else {
    Add-HealFinding -Results $findings -Id 'component-reasonix' -Name 'Komponenta reasonix' -Status 'WARN' -Detail 'chybí v bin/npm-global' -Hint 'Spusťte scripts\Setup-DeepSeekStack.ps1 (npm install -g --prefix bin/npm-global reasonix)'
}

# --- 11. escape artefakty v markdownu ----------------------------------------
Write-Log -Message 'Self-heal 11/12: escape artefakty v markdownu' -Level DEBUG
$markdownTargets = @(Get-ChildItem -LiteralPath $root -Recurse -File -Include '*.md' -ErrorAction SilentlyContinue |
        Where-Object { -not (Test-ExcludedPath -Path $_.FullName) })

$escapeArtifacts = [System.Collections.Generic.List[string]]::new()
foreach ($file in $markdownTargets) {
    foreach ($lineNumber in (Get-MarkdownEscapeArtifact -Path $file.FullName)) {
        [void]$escapeArtifacts.Add(('{0}:{1}' -f $file.Name, $lineNumber))
    }
}

if ($escapeArtifacts.Count -eq 0) {
    Add-HealFinding -Results $findings -Id 'markdown-escape' -Name 'Escapovaný markdown' -Status 'OK' -Detail ('{0}/{0} souborů bez escape artefaktů' -f $markdownTargets.Count)
}
else {
    $escapePreview = @($escapeArtifacts | Select-Object -First 5)
    Add-HealFinding -Results $findings -Id 'markdown-escape' -Name 'Escapovaný markdown' -Status 'WARN' -Detail ('nálezů: {0} ({1})' -f $escapeArtifacts.Count, ($escapePreview -join ', ')) -Hint 'Odstraňte escape artefakty - postup viz docs/METAPROMPT-REVISION.md'
}

# --- 12. directory tree je aktuální -------------------------------------------
Write-Log -Message 'Self-heal 12/12: directory tree je aktuální' -Level DEBUG
$treeRelativePath = 'scaffold/directory-tree.txt'
$treePath = Join-Path -Path $root -ChildPath $treeRelativePath
$treeHint = 'Spusťte pwsh -File scripts\Update-Tree.ps1'
$treeMaxAgeDays = 30
$treeRepaired = $false
$treeState = Get-DirectoryTreeState -Path $treePath -MaxAgeDays $treeMaxAgeDays

if ($treeState.Problems.Count -gt 0 -and $canFix) {
    $updateTreePath = Join-Path -Path $root -ChildPath 'scripts/Update-Tree.ps1'
    if (-not (Test-Path -LiteralPath $updateTreePath -PathType Leaf)) {
        [void]$treeState.Problems.Add('chybí scripts/Update-Tree.ps1')
    }
    elseif ($PSCmdlet.ShouldProcess($treePath, 'Přegenerovat directory tree')) {
        # Samostatný proces: `exit` v generátoru nesmí ukončit self-heal
        # a `-Json` výstup musí zůstat čistý (stejný vzor jako v Menu.ps1).
        $hostExecutable = 'powershell.exe'
        if (Test-Command -Name 'pwsh') {
            $hostExecutable = 'pwsh.exe'
        }

        $updateOutput = @(& $hostExecutable -NoProfile -ExecutionPolicy Bypass -File $updateTreePath 2>&1)
        if ($LASTEXITCODE -ne 0) {
            Write-Log -Message ('Update-Tree.ps1 skončilo s kódem {0}: {1}' -f $LASTEXITCODE, (($updateOutput -join ' | ').Trim())) -Level DEBUG
            [void]$treeState.Problems.Add(('přegenerování stromu selhalo (exit {0})' -f $LASTEXITCODE))
        }
        else {
            if ($updateOutput.Count -gt 0) {
                Write-Log -Message ('Update-Tree.ps1: {0}' -f (($updateOutput -join ' | ').Trim())) -Level DEBUG
            }

            # Po opravě se stav přehodnotí - datum i obsah stromu se mohly změnit.
            $treeState = Get-DirectoryTreeState -Path $treePath -MaxAgeDays $treeMaxAgeDays
            if ($treeState.Problems.Count -eq 0) {
                $treeRepaired = $true

                # V -Json módu se nesmí nic vypsat do konzole (rozbilo by to
                # parsování JSON); informace jde do Detailu nálezu.
                if (-not $Json) {
                    Write-Log -Message 'Strom přegenerován (hlavička obnovena).' -Level OK
                }
            }
        }
    }
}

if ($treeState.Problems.Count -eq 0) {
    $treeDetail = '{0}: klíčové soubory přítomny, vygenerováno {1:yyyy-MM-dd} ({2:N0} dní)' -f $treeRelativePath, $treeState.GeneratedAt, $treeState.AgeDays
    if ($treeRepaired) {
        $treeDetail = '{0}; strom přegenerován (hlavička obnovena)' -f $treeDetail
    }

    Add-HealFinding -Results $findings -Id 'directory-tree' -Name 'Directory tree je aktuální' -Status 'OK' -Detail $treeDetail
}
else {
    Add-HealFinding -Results $findings -Id 'directory-tree' -Name 'Directory tree je aktuální' -Status 'WARN' -Detail ('tree je zastaralý - {0}' -f ($treeState.Problems -join '; ')) -Hint $treeHint
}

# --- Souhrn -------------------------------------------------------------------
$failCount = @($findings | Where-Object { $_.Status -eq 'FAIL' }).Count
$warnCount = @($findings | Where-Object { $_.Status -eq 'WARN' }).Count
$okCount = @($findings | Where-Object { $_.Status -eq 'OK' }).Count
$overall = 'OK'
if ($failCount -gt 0) {
    $overall = 'FAIL'
}

$elapsed = (Get-Date) - $started
$modeName = 'report'
if ($Fix) {
    $modeName = 'fix'
    if ($WhatIfPreference) {
        $modeName = 'whatif'
    }
}

if ($Json) {
    $payload = [ordered]@{
        workspace = $root
        timestamp = $started.ToString('o')
        mode      = $modeName
        status    = $overall
        counts    = [ordered]@{ OK = $okCount; WARN = $warnCount; FAIL = $failCount }
        duration  = [math]::Round($elapsed.TotalSeconds, 2)
        findings  = $findings
    }
    $payload | ConvertTo-Json -Depth 6
}
else {
    Write-Log -Message 'Výsledky self-healu' -Level HEAD
    foreach ($finding in $findings) {
        Write-Log -Message ('    {0}: {1}' -f $finding.Name, $finding.Detail) -Level $finding.Status
        if ($finding.Hint) {
            Write-Log -Message ('      -> {0}' -f $finding.Hint) -Level INFO
        }
    }
    Write-Log -Message ('    OK: {0} | WARN: {1} | FAIL: {2} | čas: {3:N2} s' -f $okCount, $warnCount, $failCount, $elapsed.TotalSeconds) -Level INFO
    if ($modeName -eq 'fix') {
        Write-Log -Message '=== SELF-HEAL: HOTOVO ===' -Level OK
    }
    elseif ($modeName -eq 'whatif') {
        Write-Log -Message '=== SELF-HEAL: WHATIF (nic se nezměnilo) ===' -Level OK
    }
    else {
        Write-Log -Message '=== SELF-HEAL: REPORT (nic se nezměnilo) ===' -Level OK
    }
}

if ($failCount -gt 0) {
    exit 1
}

exit 0
