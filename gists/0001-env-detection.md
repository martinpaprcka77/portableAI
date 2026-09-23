# 0001 — Detekce `.env` napříč Windows cestami

**Kdy to použít:** potřebujete načíst konfiguraci a nevíte, jestli `.env` leží
v kořeni projektu, v `env\`, nebo vůbec neexistuje.

## Problém

Na Windows se `.env` obvykle hledá na několika místech a skript, který spoléhá
na jednu pevnou cestu, tiše selže. Zároveň se nesmí stát, že `null` hodnota
shodí parsování.

## Řešení

```powershell
function Find-DotEnvFile {
    <#
    .SYNOPSIS
        Najde první existující .env soubor v očekávaných umístěních.
    .PARAMETER Root
        Kořen workspace.
    .OUTPUTS
        System.String - plná cesta, nebo $null
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $candidates = @(
        (Join-Path -Path $Root -ChildPath 'env/.env')
        (Join-Path -Path $Root -ChildPath '.env')
        (Join-Path -Path $Root -ChildPath 'configs/.env')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $null
}
```

V tomto workspace je to hotové jako `Import-DotEnv` v `scripts/_common.ps1`:

```powershell
. .\scripts\_common.ps1
$config = Import-DotEnv          # najde a nastaví proměnné prostředí
$config = Import-DotEnv -Path 'env\.env'   # nebo explicitně
```

## Časté chyby

| Chyba | Proč je to problém |
| --- | --- |
| `Test-Path` bez `-LiteralPath` | závorky a hranaté závorky v cestě se berou jako wildcard |
| `Get-Content` bez `-Encoding utf8` | na CP1250 Windows rozbije diakritiku |
| `$value.Split('=')[1]` | rozbije hodnoty, které obsahují `=` |
| Test na soubor bez `-PathType Leaf` | adresář jménem `.env` projde jako soubor |

## Ověření

```powershell
$path = Find-DotEnvFile -Root (Get-Location).Path
if ($path) { "Nalezeno: $path" } else { 'Chybí .env - zkopírujte env\.env.example' }
```
