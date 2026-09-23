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

function Import-DotEnv {
    <#
    .SYNOPSIS
        Načte proměnné z `.env` souboru do prostředí a vrátí je jako hashtable.
    .DESCRIPTION
        Podporuje komentáře (`#`), prefix `export `, jednoduché i dvojité
        uvozovky okolo hodnot a prázdné řádky. Existující proměnné prostředí
        nepřepisuje (aby uživatel mohl hodnotu přebít zvenčí).

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

    $result = @{}

    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Log -Message "DotEnv: soubor nenalezen ($Path)" -Level DEBUG
        return $result
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

        $result[$key] = $value

        if (-not $NoEnvironment -and -not [Environment]::GetEnvironmentVariable($key)) {
            [Environment]::SetEnvironmentVariable($key, $value, 'Process')
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
