<#
.SYNOPSIS
    Sdílené pomocné funkce pro skripty portable AI workspace.
.DESCRIPTION
    Poskytuje jednotné logování, ASCII banner, odvození kořene workspace,
    testy dostupnosti příkazů, detekci administrátorských práv a načítání
    konfigurace z `.env` souborů.

    Skript nemá žádné vedlejší efekty kromě nastavení UTF-8 kódování konzole
    a je bezpečné jej načítat opakovaně. Ostatní skripty ho používají takto:

        . "$PSScriptRoot/_common.ps1"

.NOTES
    Vyžaduje PowerShell 5.1+ (primárně testováno na PowerShell 7+).
    Žádná globální instalace, žádná admin práva.
.EXAMPLE
    . "$PSScriptRoot/_common.ps1"
    Write-Log -Message 'Hello workspace' -Level OK
#>

# --- UTF-8 konzole (kvůli diakritice) ----------------------------------------
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
}
catch [System.IO.IOException] {
    # Přesměrovaný výstup (CI, pipe) nemusí podporovat změnu encoding. Není chyba.
    Write-Verbose 'Konzoli nelze přepnout do UTF-8 (přesměrovaný výstup) - pokračuji.'
}
catch [System.PlatformNotSupportedException] {
    # Omezený host bez plné Console implementace. Pokračujeme bez UTF-8 konzole.
    Write-Verbose 'Host nepodporuje [Console]::OutputEncoding - pokračuji.'
}

function Get-WorkspaceRoot {
    <#
    .SYNOPSIS
        Vrátí absolutní cestu ke kořeni portable AI workspace.
    .DESCRIPTION
        Kořen se odvozuje z umístění tohoto souboru (`scripts/_common.ps1`),
        takže funguje i po přesunutí workspace na jiný disk nebo na USB.
        Nikdy nepoužívá hardcoded cestu.
    .OUTPUTS
        System.String
    .EXAMPLE
        $root = Get-WorkspaceRoot
        Join-Path -Path $root -ChildPath 'prompts'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $root = Split-Path -Path $PSScriptRoot -Parent
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw "Kořen workspace nebyl nalezen: $root"
    }

    return (Resolve-Path -LiteralPath $root).Path
}

function Write-Log {
    <#
    .SYNOPSIS
        Zapíše zprávu do konzole a volitelně do log souboru.
    .DESCRIPTION
        Jednotný logger pro všechny skripty workspace. Podporuje úrovně
        INFO, OK, WARN, FAIL, DEBUG, STEP a HEAD a barevný výstup.
        Cesta předaná v -LogFile se uloží a stane se výchozí pro všechna
        následující volání v rámci dané PowerShell session (sticky).
        Úroveň DEBUG se zobrazí v konzoli pouze při spuštění s `-Verbose`
        (do log souboru se zapisuje vždy).
    .PARAMETER Message
        Text zprávy. Lze předat také přes pipeline.
    .PARAMETER Level
        Úroveň zprávy: INFO, OK, WARN, FAIL, DEBUG, STEP, HEAD.
    .PARAMETER LogFile
        Cesta k log souboru. Stane se výchozí pro další volání.
    .PARAMETER NoColor
        Vypne barevný výstup (např. pro CI logy).
    .PARAMETER Quiet
        Potlačí výstup do konzole (log do souboru zůstává). Stane se výchozím
        pro všechna následující volání v rámci dané session. Používá se, když
        skript vydává strojově čitelný výstup (např. `-Json`).
    .PARAMETER Raw
        Vypíše zprávu bez časové značky a úrovně. Používá se pro přeposílání
        výstupu vnořených procesů, aby se prefixy nezdvojovaly.
    .EXAMPLE
        Write-Log -Message 'Workspace je připraven.' -Level OK
    .EXAMPLE
        Write-Log -Message 'Kontroluji závislosti...' -Level STEP -LogFile '.\logs\build.log'
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Write-Log je vědomý konzolový reporter; Write-Host je zamýšlený výstup.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Název Write-Log je součástí specifikace workspace (METAPROMPT.md); kolize s built-in cmdletem neexistuje.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter()]
        [ValidateSet('INFO', 'OK', 'WARN', 'FAIL', 'DEBUG', 'STEP', 'HEAD')]
        [string]$Level = 'INFO',

        [Parameter()]
        [string]$LogFile,

        [Parameter()]
        [switch]$NoColor,

        [Parameter()]
        [switch]$Quiet,

        [Parameter()]
        [switch]$Raw
    )

    process {
        if ($LogFile) {
            $script:PortableAiLogFile = $LogFile
        }
        if ($Quiet) {
            $script:PortableAiQuiet = $true
        }

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line = '[{0}] [{1,-5}] {2}' -f $timestamp, $Level, $Message
        if ($Raw) {
            $line = $Message
        }

        if (-not $script:PortableAiQuiet) {
            $toConsole = -not ($Level -eq 'DEBUG' -and $VerbosePreference -ne 'Continue')
        }
        else {
            $toConsole = $false
        }

        if ($toConsole) {
            if ($NoColor -or $script:PortableAiNoColor) {
                Write-Host $line
            }
            else {
                Write-Host $line -ForegroundColor (Get-PortableAiLogColor -Level $Level)
            }
        }

        if ($script:PortableAiLogFile) {
            Add-Content -LiteralPath $script:PortableAiLogFile -Value $line -Encoding utf8 -WhatIf:$false
        }
    }
}

function Write-Banner {
    <#
    .SYNOPSIS
        Vypíše ASCII banner s názvem a podtitulem.
    .DESCRIPTION
        Používá se na začátku interaktivních skriptů a menu. Banner je
        dekorativní, nikdy neobsahuje citlivé údaje.
    .PARAMETER Title
        Hlavní název (výchozí: Portable AI Workspace).
    .PARAMETER Subtitle
        Volitelný podtitul zobrazený pod rámem.
    .PARAMETER NoColor
        Vypne barevný výstup.
    .PARAMETER NoBanner
        Potlačí celý výstup (vypíše jen podtitul, pokud je zadán).
    .EXAMPLE
        Write-Banner -Title 'Portable AI' -Subtitle 'Diagnostics'
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Banner je konzolový výstup; Write-Host je zamýšlený.')]
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Title = 'Portable AI Workspace',

        [Parameter(Position = 1)]
        [string]$Subtitle = '',

        [Parameter()]
        [switch]$NoColor,

        [Parameter()]
        [switch]$NoBanner
    )

    $color = 'Cyan'
    if ($NoColor -or $script:PortableAiNoColor) {
        $color = 'Gray'
    }

    if ($NoBanner) {
        if ($Subtitle) {
            Write-Host $Subtitle -ForegroundColor $color
        }
        return
    }

    $inner = 62
    $top = '  +' + ('-' * $inner) + '+'
    $titleLine = '  | ' + $Title.PadRight($inner - 2) + ' |'
    $bottom = '  +' + ('-' * $inner) + '+'

    Write-Host ''
    Write-Host $top -ForegroundColor $color
    Write-Host $titleLine -ForegroundColor $color
    Write-Host $bottom -ForegroundColor $color
    if ($Subtitle) {
        Write-Host ("  {0}" -f $Subtitle) -ForegroundColor $color
    }
    Write-Host ''
}

function Get-PortableAiLogColor {
    <#
    .SYNOPSIS
        Vrátí barvu konzole pro danou úroveň logu.
    .DESCRIPTION
        Interní helper pro Write-Log. Mapuje úroveň na název barvy
        rozpoznávaný parametrem -ForegroundColor.
    .PARAMETER Level
        Úroveň logu (INFO, OK, WARN, FAIL, DEBUG, STEP, HEAD).
    .OUTPUTS
        System.String
    .EXAMPLE
        Get-PortableAiLogColor -Level FAIL
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet('INFO', 'OK', 'WARN', 'FAIL', 'DEBUG', 'STEP', 'HEAD')]
        [string]$Level
    )

    switch ($Level) {
        'OK' { return 'Green' }
        'WARN' { return 'Yellow' }
        'FAIL' { return 'Red' }
        'STEP' { return 'Cyan' }
        'HEAD' { return 'Magenta' }
        'DEBUG' { return 'DarkGray' }
        default { return 'Gray' }
    }
}

function Test-Command {
    <#
    .SYNOPSIS
        Zjistí, zda je daný příkaz dostupný v PATH.
    .DESCRIPTION
        Bezpečná obdoba `Get-Command` — nikdy nevyhodí výjimku, když příkaz
        neexistuje, a nevypisuje chybu do error streamu.
    .PARAMETER Name
        Název příkazu (např. node, git, pwsh).
    .OUTPUTS
        System.Boolean
    .EXAMPLE
        if (Test-Command -Name 'node') { Write-Log 'Node je dostupný' }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Test-IsAdmin {
    <#
    .SYNOPSIS
        Zjistí, zda běží aktuální proces s administrátorskými právy.
    .DESCRIPTION
        Používá WindowsPrincipal. Workspace je navržen tak, aby administrátorská
        práva nepotřeboval — tato funkce slouží pouze pro diagnostiku.
    .OUTPUTS
        System.Boolean
    .EXAMPLE
        if (Test-IsAdmin) { Write-Log 'Běžíme elevated' -Level WARN }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch [System.PlatformNotSupportedException] {
        # Mimo Windows administrátorská role neexistuje.
        return $false
    }
}

function Get-EnvValueSource {
    <#
    .SYNOPSIS
        Zjistí, odkud se bere hodnota dané proměnné prostředí.
    .DESCRIPTION
        Prohledá zdroje v pořadí priority a vrátí první nalezený:

        ```
        1. Process scope
        2. User scope
        3. Machine scope
        4. hodnoty načtené z `.env` souboru
        ```

        Pořadí je záměrně "env před `.env`": živější zdroj (např. rotovaný
        klíč) musí vyhrát i při expanzi `${VAR}`, ne jen při přímém čtení.
        Stejné pořadí používá `Expand-DotEnvValue`, takže priorita existuje
        na jediném místě.

        Vrácený objekt má vlastnosti `Name`, `Source`, `Value` a `Found`.
        `Source` je jedno z `Process`, `User`, `Machine`, `.env` nebo `none`.
        `Value` je vždy surová (nemaskovaná) hodnota - maskování je věcí
        volajícího.
    .PARAMETER Name
        Název proměnné prostředí.
    .PARAMETER DotEnvValues
        Hashtable hodnot načtených z `.env`. Používá se jako poslední fallback.
    .PARAMETER ProcessValue
        Hodnota Process scope platná před načtením `.env`. Používá se tam, kde
        už `Import-DotEnv` zapsal `.env` do Process scope a přímé čtení by
        zakrylo skutečný původ hodnoty.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    .EXAMPLE
        $source = Get-EnvValueSource -Name 'DEEPSEEK_API_KEY' -DotEnvValues $dotEnv
        if ($source.Found) { Write-Log -Message $source.Source -Level OK }
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,

        [Parameter()]
        [hashtable]$DotEnvValues = @{},

        [Parameter()]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$ProcessValue
    )

    if (-not $PSBoundParameters.ContainsKey('ProcessValue')) {
        $ProcessValue = [Environment]::GetEnvironmentVariable($Name, 'Process')
    }

    if (-not [string]::IsNullOrWhiteSpace($ProcessValue)) {
        return [pscustomobject]@{ Name = $Name; Source = 'Process'; Value = $ProcessValue; Found = $true }
    }

    foreach ($scope in @('User', 'Machine')) {
        $scopeValue = [Environment]::GetEnvironmentVariable($Name, $scope)
        if (-not [string]::IsNullOrWhiteSpace($scopeValue)) {
            return [pscustomobject]@{ Name = $Name; Source = $scope; Value = $scopeValue; Found = $true }
        }
    }

    if ($DotEnvValues -and $DotEnvValues.ContainsKey($Name)) {
        $dotEnvValue = [string]$DotEnvValues[$Name]
        if (-not [string]::IsNullOrWhiteSpace($dotEnvValue)) {
            return [pscustomobject]@{ Name = $Name; Source = '.env'; Value = $dotEnvValue; Found = $true }
        }
    }

    return [pscustomobject]@{ Name = $Name; Source = 'none'; Value = $null; Found = $false }
}

function Expand-DotEnvValue {
    <#
    .SYNOPSIS
        Expanduje reference `${VAR}` a `$VAR` v hodnotě z `.env` souboru.
    .DESCRIPTION
        Nahradí v hodnotě odkazy na jiné proměnné. Podporované tvary:

        ```
        ${VAR}    substituce (preferovaný, jednoznačný tvar)
        $VAR      ekvivalent k ${VAR}
        \${VAR}   escapováno - zůstane doslovně "${VAR}"
        \$VAR     escapováno - zůstane doslovně "$VAR"
        ```

        Neplatné tvary (`$1`, `$-`, osamocené `$`) se ponechávají beze změny
        a nehlásí se u nich WARN.

        Hodnota se hledá stejnou prioritou jako všude jinde v workspace
        (`Get-EnvValueSource`): Process -> User -> Machine -> `.env`.
        Expanze je rekurzivní s limitem `MaxDepth`; přímý cyklus
        (`A=${B}`, `B=${A}`) se detekuje a taková reference zůstane
        neexpandovaná, aby uživatel viděl, co je špatně.

        Hodnota bez `$` se vrací beze změny (rychlá cesta bez expanze).
    .PARAMETER Value
        Hodnota k expanzi.
    .PARAMETER Variables
        Hashtable hodnot načtených z `.env` - fallback pro substituci.
    .PARAMETER MaxDepth
        Maximální hloubka rekurze. Výchozí 10.
    .PARAMETER Stack
        Interní - zásobník právě rozbalovaných jmen pro detekci cyklu.
    .OUTPUTS
        System.String
    .EXAMPLE
        $value = Expand-DotEnvValue -Value '${DEEPSEEK_API_KEY}' -Variables $dotEnv
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Value,

        [Parameter()]
        [hashtable]$Variables = @{},

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$MaxDepth = 10,

        [Parameter(DontShow)]
        [string[]]$Stack = @()
    )

    if ([string]::IsNullOrEmpty($Value) -or $Value.IndexOf('$') -lt 0) {
        return $Value
    }

    $pattern = '\\\$\{(?<escBraced>[A-Za-z_][A-Za-z0-9_]*)\}|\\\$(?<escPlain>[A-Za-z_][A-Za-z0-9_]*)|(?<!\\)\$\{(?<braced>[A-Za-z_][A-Za-z0-9_]*)\}|(?<!\\)\$(?<plain>[A-Za-z_][A-Za-z0-9_]*)'
    $referenceMatches = [regex]::Matches($Value, $pattern)
    if ($referenceMatches.Count -eq 0) {
        return $Value
    }

    $builder = [System.Text.StringBuilder]::new()
    $position = 0

    foreach ($match in $referenceMatches) {
        [void]$builder.Append($Value.Substring($position, $match.Index - $position))
        $position = $match.Index + $match.Length

        if ($match.Groups['escBraced'].Success) {
            [void]$builder.Append('${').Append($match.Groups['escBraced'].Value).Append('}')
            continue
        }
        if ($match.Groups['escPlain'].Success) {
            [void]$builder.Append('$').Append($match.Groups['escPlain'].Value)
            continue
        }

        if ($match.Groups['braced'].Success) {
            $name = $match.Groups['braced'].Value
            $reference = '${' + $name + '}'
            $isBraced = $true
        }
        else {
            $name = $match.Groups['plain'].Value
            $reference = '$' + $name
            $isBraced = $false
        }

        if ($Stack -contains $name) {
            Write-Log -Message ('DotEnv: cyklická substituce {0} - ponechávám neexpandovanou' -f $reference) -Level WARN
            [void]$builder.Append($reference)
            continue
        }
        if ($Stack.Count -ge $MaxDepth) {
            Write-Log -Message ('DotEnv: překročen limit hloubky {0} u {1} - ponechávám neexpandovanou' -f $MaxDepth, $reference) -Level WARN
            [void]$builder.Append($reference)
            continue
        }

        $resolved = Get-EnvValueSource -Name $name -DotEnvValues $Variables
        if (-not $resolved.Found) {
            if ($isBraced) {
                Write-Log -Message ('DotEnv: {0} není definováno v env ani v .env - nahrazuji prázdným řetězcem' -f $reference) -Level WARN
            }
            continue
        }

        $nested = Expand-DotEnvValue -Value ([string]$resolved.Value) -Variables $Variables -MaxDepth $MaxDepth -Stack ($Stack + $name)
        [void]$builder.Append($nested)
    }

    [void]$builder.Append($Value.Substring($position))
    return $builder.ToString()
}

function Import-DotEnv {
    <#
    .SYNOPSIS
        Načte proměnné z `.env` souboru do prostředí a vrátí je jako hashtable.
    .DESCRIPTION
        Podporuje komentáře (`#`), prefix `export `, jednoduché i dvojité
        uvozovky okolo hodnot a prázdné řádky. Existující proměnné prostředí
        nepřepisuje (aby uživatel mohl hodnotu přebít zvenčí).

        Načítání probíhá ve dvou fázích: nejprve se naparsují všechny dvojice
        `KEY=VALUE`, pak se hodnoty expandují a teprve nakonec se zapíší do
        Process scope. Díky tomu fungují i dopředné reference (např.
        `ANTHROPIC_AUTH_TOKEN=${DEEPSEEK_API_KEY}`, i když je klíč v souboru
        uveden až za tokenem).

        Vrací už **expandované** hodnoty, takže opakované volání expanzi
        nezdvojnásobí.

        Když není -Path zadán, hledá v tomto pořadí:
        `env/.env` a poté `.env` v kořeni workspace.
    .PARAMETER Path
        Cesta k `.env` souboru. Volitelná.
    .PARAMETER NoEnvironment
        Načte hodnoty, ale nezapisuje je do proměnných prostředí.
    .OUTPUTS
        System.Collections.Hashtable
    .EXAMPLE
        $config = Import-DotEnv -Path '.\env\.env'
    .EXAMPLE
        $config = Import-DotEnv
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Position = 0)]
        [string]$Path,

        [Parameter()]
        [switch]$NoEnvironment
    )

    if (-not $Path) {
        $root = Get-WorkspaceRoot
        $candidates = @(
            (Join-Path -Path $root -ChildPath 'env/.env'),
            (Join-Path -Path $root -ChildPath '.env')
        )
        $Path = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }

    $raw = @{}

    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Log -Message "DotEnv: soubor nenalezen ($Path)" -Level DEBUG
        return $raw
    }

    foreach ($rawLine in (Get-Content -LiteralPath $Path -Encoding utf8)) {
        $line = ([string]$rawLine).Trim()
        if (-not $line -or $line.StartsWith('#')) {
            continue
        }
        if ($line.StartsWith('export ')) {
            $line = $line.Substring(7).Trim()
        }

        $separator = $line.IndexOf('=')
        if ($separator -lt 1) {
            continue
        }

        $key = $line.Substring(0, $separator).Trim()
        $value = $line.Substring($separator + 1).Trim()

        if ($value.Length -ge 2) {
            $isDoubleQuoted = $value.StartsWith('"') -and $value.EndsWith('"')
            $isSingleQuoted = $value.StartsWith("'") -and $value.EndsWith("'")
            if ($isDoubleQuoted -or $isSingleQuoted) {
                $value = $value.Substring(1, $value.Length - 2)
            }
        }

        $raw[$key] = $value
    }

    # Druhá fáze: expanze ${VAR}/$VAR nad kompletní sadou klíčů, aby fungovaly
    # i dopředné reference. Vracíme už expandované hodnoty.
    $result = @{}
    foreach ($key in $raw.Keys) {
        $result[$key] = Expand-DotEnvValue -Value $raw[$key] -Variables $raw
    }

    if (-not $NoEnvironment) {
        foreach ($key in $result.Keys) {
            if (-not [Environment]::GetEnvironmentVariable($key)) {
                [Environment]::SetEnvironmentVariable($key, [string]$result[$key], 'Process')
            }
        }
    }

    Write-Log -Message ("DotEnv: nacteno {0} klicu z {1}" -f $result.Count, $Path) -Level DEBUG
    return $result
}

function Get-MaskedValue {
    <#
    .SYNOPSIS
        Zamaskuje citlivou hodnotu pro bezpečný výpis do konzole a logu.
    .DESCRIPTION
        Krátké hodnoty nahradí pevným maskovacím řetězcem, delší zkrátí na
        první a poslední čtyři znaky. Nikdy nevrací plnou hodnotu.
    .PARAMETER Value
        Hodnota k zamaskování.
    .OUTPUTS
        System.String
    .EXAMPLE
        Get-MaskedValue -Value $env:DEEPSEEK_API_KEY
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrEmpty($Value)) {
        return '<nenastaveno>'
    }
    if ($Value.Length -le 12) {
        return '<nastaveno, skryto>'
    }

    return '{0}...{1}' -f $Value.Substring(0, 4), $Value.Substring($Value.Length - 4)
}

function Get-WorkspaceManifest {
    <#
    .SYNOPSIS
        Vrátí manifest povinných adresářů a souborů workspace.
    .DESCRIPTION
        Jediný zdroj pravdy o tom, co má portable AI workspace obsahovat.
        Používají ho `Get-AiStackInfo.ps1` (diagnostika) i
        `Test-Workspace.ps1` (self-test), aby se obě kontroly nerozešly.
        Cesty jsou relativní ke kořeni workspace a používají `/` oddělovač.
    .OUTPUTS
        System.Collections.Hashtable
    .EXAMPLE
        $manifest = Get-WorkspaceManifest
        $manifest.Directories
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return @{
        Directories = @(
            'scaffold'
            'scripts'
            'prompts'
            'prompts/templates'
            'docs'
            'docs/adr'
            'manual'
            'launcher'
            'landing'
            'landing/assets'
            'gists'
            'gists/snippets'
            'env'
            'logs'
            'data'
            'bin'
            '.vscode'
        )
        Files = @(
            'README.md'
            'LICENSE'
            'VERSION'
            'CHANGELOG.md'
            'METAPROMPT.md'
            '.gitignore'
            '.gitattributes'
            '.editorconfig'
            '.env.example'
            'scaffold/00-README.md'
            'scaffold/01-STRUCTURE.md'
            'scaffold/directory-tree.txt'
            'scripts/_common.ps1'
            'scripts/Setup-DeepSeekStack.ps1'
            'scripts/Get-AiStackInfo.ps1'
            'scripts/Repair-Repo.ps1'
            'scripts/Test-Workspace.ps1'
            'prompts/README.md'
            'prompts/00-system.md'
            'prompts/01-setup.md'
            'prompts/02-diagnostics.md'
            'prompts/03-coding.md'
            'prompts/04-refactor.md'
            'prompts/05-review.md'
            'prompts/06-debug.md'
            'prompts/templates/task.md'
            'prompts/templates/bugfix.md'
            'prompts/templates/feature.md'
            'docs/00-OVERVIEW.md'
            'docs/01-INSTALL.md'
            'docs/02-CONFIG.md'
            'docs/03-TROUBLESHOOTING.md'
            'docs/04-ARCHITECTURE.md'
            'docs/05-SECURITY.md'
            'docs/06-DEVIATIONS.md'
            'docs/adr/0001-record-architecture-decisions.md'
            'manual/00-quickstart.md'
            'manual/01-cheatsheet.md'
            'manual/02-workflows.md'
            'manual/03-faq.md'
            'manual/04-glossary.md'
            'launcher/Start-PortableAI.cmd'
            'launcher/Menu.ps1'
            'launcher/Launch-Reasonix.cmd'
            'launcher/Launch-Claude.cmd'
            'launcher/Launch-Diagnostics.cmd'
            'launcher/Launch-Setup.cmd'
            'landing/index.html'
            'landing/style.css'
            'landing/script.js'
            'landing/assets/logo.svg'
            'gists/README.md'
            'gists/0001-env-detection.md'
            'gists/0002-reasonix-config.md'
            'gists/0003-claude-deepseek.md'
            'gists/0004-pi-reasonix.md'
            'gists/0005-utf8-console.md'
            'gists/snippets/.env.example'
            'gists/snippets/reasonix.toml'
            'gists/snippets/models.json'
            'gists/snippets/settings.json'
            'env/.env.example'
            'env/README.md'
            '.vscode/settings.json'
            '.vscode/extensions.json'
            '.vscode/tasks.json'
        )
        PowerShellScripts = @(
            'scripts/_common.ps1'
            'scripts/Setup-DeepSeekStack.ps1'
            'scripts/Get-AiStackInfo.ps1'
            'scripts/Repair-Repo.ps1'
            'scripts/Test-Workspace.ps1'
            'launcher/Menu.ps1'
        )
        CmdScripts = @(
            'launcher/Start-PortableAI.cmd'
            'launcher/Launch-Reasonix.cmd'
            'launcher/Launch-Claude.cmd'
            'launcher/Launch-Diagnostics.cmd'
            'launcher/Launch-Setup.cmd'
        )
    }
}

function Get-ComponentShimPath {
    <#
    .SYNOPSIS
        Najde spustitelnou binárku komponenty v zadaném adresáři.
    .DESCRIPTION
        Zkusí postupně `<dir>/<binary>.cmd`, `<binary>.exe`, `<binary>.ps1`,
        `<binary>` a POSIX variantu `<dir>/bin/<binary>`. Vrací první
        existující cestu, nebo `$null`, když adresář nebo binárka neexistuje.
        Nikdy nevyhazuje výjimku.

        Sdílená logika pro `Test-Component` (detekce) i pro
        `Resolve-ComponentShim` v setupu, aby se obě místa nerozešla.
    .PARAMETER Directory
        Adresář, ve kterém se binárka hledá (např. `bin/npm-global`).
    .PARAMETER Binary
        Název binárky bez přípony (např. `reasonix`).
    .OUTPUTS
        System.String - absolutní cesta k binárce, nebo $null
    .EXAMPLE
        Get-ComponentShimPath -Directory 'C:\portableAI\bin\npm-global' -Binary 'reasonix'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string]$Directory,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Binary
    )

    if ([string]::IsNullOrWhiteSpace($Directory) -or -not (Test-Path -LiteralPath $Directory -PathType Container)) {
        return $null
    }

    $candidates = @(
        (Join-Path -Path $Directory -ChildPath ('{0}.cmd' -f $Binary))
        (Join-Path -Path $Directory -ChildPath ('{0}.exe' -f $Binary))
        (Join-Path -Path $Directory -ChildPath ('{0}.ps1' -f $Binary))
        (Join-Path -Path $Directory -ChildPath $Binary)
        (Join-Path -Path $Directory -ChildPath ('bin/{0}' -f $Binary))
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    return $null
}

function Get-ComponentCatalog {
    <#
    .SYNOPSIS
        Vrátí katalog AI komponent workspace včetně kategorií.
    .DESCRIPTION
        Jediný zdroj pravdy o komponentách, které workspace umí nainstalovat
        do `bin/npm-global`. Používají ho `Setup-DeepSeekStack.ps1`
        (instalace), `Get-AiStackInfo.ps1` (diagnostika) a
        `Test-Workspace.ps1` (self-test), aby se kategorie, verze a názvy
        nerozešly.

        Kategorie určuje, jak přísně se komponenta vyžaduje:

          Required      - musí být vždy ve workspace (jinak FAIL)
          Recommended   - instaluje se, pokud není `-SkipOptional`
          Optional      - instaluje se jen na výslovné vyžádání
                          (`-InstallOptional <jméno>`)

        `Category` je zároveň prioritní pořadí v diagnostice.
        Názvy a verze jsou ověřené proti živému npm registry a GitHub
        releases (audit 2026-09-23).
    .OUTPUTS
        System.Object[] - pole `pscustomobject` záznamů komponent
    .EXAMPLE
        (Get-ComponentCatalog | Where-Object { $_.Category -eq 'Required' }).Name
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param()

    return @(
        [pscustomobject]@{
            Name        = 'Reasonix'
            DisplayName = 'Reasonix'
            Category    = 'Required'
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
            DisplayName = 'Claude Code'
            Category    = 'Optional'
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
            AltSources  = @(
                'npm mimo workspace: npm install -g @anthropic-ai/claude-code@2.1.280 (POZOR: zapisuje do profilu uzivatele, NENI portable)'
                'GitHub releases (CHANGELOG, nikoli binarka): https://github.com/anthropics/claude-code/releases'
            )
        }
        [pscustomobject]@{
            Name        = 'DeepSeek Harness'
            DisplayName = 'DeepSeek Harness'
            Category    = 'Optional'
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
            AltSources  = @(
                'npm mimo workspace: npm install -g @deepseek-ai/dsh@0.1.5-rc.3 (POZOR: zapisuje do profilu uzivatele, NENI portable)'
            )
        }
        [pscustomobject]@{
            Name         = 'Pi'
            DisplayName  = 'Pi'
            Category     = 'Recommended'
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
            AltSources   = @(
                'npm mimo workspace: npm install -g @earendil-works/pi-coding-agent@0.87.1 (POZOR: zapisuje do profilu uzivatele, NENI portable)'
            )
            Extension    = 'pi-reasonix@1.1.0'
            ExtensionVar = 'PORTABLEAI_PI_EXTENSIONS'
        }
    )
}

function Test-Component {
    <#
    .SYNOPSIS
        Najde komponentu v pěti režimech a určí, zda je přenositelná.
    .DESCRIPTION
        Prohledá postupně (pořadí je zároveň prioritou vítěze):

          1. workspace       - `<root>/bin/npm-global/<binary>.cmd`
          2. workspace-local - `<root>/node_modules/.bin/<binary>.cmd`
          3. global-npm      - `%APPDATA%\npm\<binary>.cmd`
          4. system          - `Get-Command <binary>`
          5. none            - nenalezeno

        Vítězí první zásah v tomto pořadí; `Portable` je `$true` jen pro
        `workspace` a `workspace-local`, tedy pro cesty uvnitř workspace.
        Zásahy se deduplikují podle adresáře, takže tatáž instalace nalezená
        přes `global-npm` i `system` se počítá jednou a `MultipleFound`
        zůstane `$false`.

        Verze se zjišťuje spuštěním vítězné binárky s `--version`
        (vypnutelné přes `-SkipVersion`); když se nepodaří, je prázdná.
        Funkce nikdy nevyhazuje výjimku a nic neinstaluje.
    .PARAMETER Name
        Název komponenty pro report (obvykle název binárky).
    .PARAMETER Binary
        Název binárky bez přípony. Když není zadán, použije se `Name`.
    .PARAMETER Root
        Kořen workspace. Když není zadán, použije se `Get-WorkspaceRoot`.
    .PARAMETER SkipVersion
        Nezjišťovat verzi (nespouštět binárku) - hodí se pro rychlé kontroly.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    .EXAMPLE
        Test-Component -Name 'reasonix' -Root (Get-WorkspaceRoot)
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Position = 1)]
        [string]$Binary,

        [Parameter()]
        [string]$Root,

        [Parameter()]
        [switch]$SkipVersion
    )

    if ([string]::IsNullOrWhiteSpace($Binary)) {
        $Binary = $Name
    }
    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = Get-WorkspaceRoot
    }

    $globalNpmDirectory = ''
    if (-not [string]::IsNullOrWhiteSpace([string]$env:APPDATA)) {
        $globalNpmDirectory = Join-Path -Path $env:APPDATA -ChildPath 'npm'
    }

    $specs = @(
        [pscustomobject]@{ Source = 'workspace'; Directory = (Join-Path -Path $Root -ChildPath 'bin/npm-global') }
        [pscustomobject]@{ Source = 'workspace-local'; Directory = (Join-Path -Path $Root -ChildPath 'node_modules/.bin') }
        [pscustomobject]@{ Source = 'global-npm'; Directory = $globalNpmDirectory }
    )

    $locations = [System.Collections.Generic.List[object]]::new()
    $seenDirectories = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($spec in $specs) {
        $candidatePath = Get-ComponentShimPath -Directory ([string]$spec.Directory) -Binary $Binary
        if (-not $candidatePath) {
            continue
        }

        $candidateDirectory = Split-Path -Path $candidatePath -Parent
        if ($seenDirectories.Add($candidateDirectory)) {
            [void]$locations.Add([pscustomobject]@{ Source = [string]$spec.Source; Path = $candidatePath })
        }
    }

    $systemCommand = Get-Command -Name $Binary -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($systemCommand) {
        $systemPath = [string]$systemCommand.Source
        if ([string]::IsNullOrWhiteSpace($systemPath)) {
            $systemPath = [string]$systemCommand.Definition
        }
        if (-not [string]::IsNullOrWhiteSpace($systemPath)) {
            $systemDirectory = Split-Path -Path $systemPath -Parent
            if ([string]::IsNullOrWhiteSpace($systemDirectory)) {
                $systemDirectory = $systemPath
            }
            if ($seenDirectories.Add($systemDirectory)) {
                [void]$locations.Add([pscustomobject]@{ Source = 'system'; Path = $systemPath })
            }
        }
    }

    $source = 'none'
    $path = ''
    $portable = $false
    $version = ''

    if ($locations.Count -gt 0) {
        $source = [string]$locations[0].Source
        $path = [string]$locations[0].Path
        $portable = ($source -in @('workspace', 'workspace-local'))

        if (-not $SkipVersion) {
            try {
                $rawVersion = & $path '--version' 2>&1 | Select-Object -First 1
                if ($null -ne $rawVersion) {
                    $version = ([string]$rawVersion).Trim()
                }
            }
            catch [System.Exception] {
                Write-Verbose ('Verzi {0} nelze zjistit: {1}' -f $path, $_.Exception.Message)
            }
        }
    }

    return [pscustomobject]@{
        Name          = $Name
        Binary        = $Binary
        Found         = ($locations.Count -gt 0)
        Source        = $source
        Path          = $path
        Version       = $version
        Portable      = $portable
        MultipleFound = ($locations.Count -gt 1)
    }
}
