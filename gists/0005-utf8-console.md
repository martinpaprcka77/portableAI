# 0005 — Oprava diakritiky v PowerShell konzoli

**Kdy to použít:** místo `á` vidíte `Ã¡`, místo `ř` vidíte `Å™`, nebo se
výstup skriptu v `cmd.exe` rozsype.

## Proč se to děje

PowerShell 5.1 a `cmd.exe` používají ve výchozím stavu OEM znakovou sadu
(na českých Windows CP852 / CP1250). Skript uložený v UTF-8 se pak přečte
špatně. PowerShell 7 má ve výchozím stavu UTF-8, ale i tak se to rozbije,
když výstup prochází přes starší `cmd.exe`.

## Oprava v aktuální session

```powershell
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
```

Toto dělá `scripts/_common.ps1` automaticky při každém načtení, takže stačí:

```powershell
. .\scripts\_common.ps1
```

## Trvalá oprava pro PowerShell 5.1

Do `$PROFILE` (např. `notepad $PROFILE`):

```powershell
if ($PSVersionTable.PSEdition -eq 'Desktop') {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
}
```

## Oprava pro `cmd.exe`

`cmd.exe` nemá přepínač pro kódovou stránku na úrovni skriptu. Použijte:

```cmd
chcp 65001 >nul
```

Nebo — lépe — nespouštějte PowerShell skripty přes `cmd.exe`, ale přes
`pwsh.exe -File`. Wrappery ve `launcher/` to dělají správně.

## Kontrola, že to funguje

```powershell
'Příliš žluťoučký kůň úpěl ďábelské ódy'
```

Musí se zobrazit přesně. Dále:

```powershell
[Console]::OutputEncoding.WebName     # očekáváno: utf-8
$PSVersionTable.PSVersion             # 5.1 / 7.x
```

## Pozor na soubory, ne jen konzoli

Samotná konzole nestačí. Skript uložený bez BOM se přečte ve špatné sadě:

```powershell
# Ověření BOM u všech .ps1
Get-ChildItem scripts\*.ps1 | ForEach-Object {
    $b = [System.IO.File]::ReadAllBytes($_.FullName)
    [pscustomobject]@{
        File   = $_.Name
        HasBom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
    }
}
```

Oprava: `pwsh -File scripts\Test-Workspace.ps1 -Fix`.

## Shrnutí pravidel workspace

| Co | Jak |
| --- | --- |
| `.ps1` | UTF-8 **s BOM** + CRLF |
| `.cmd` / `.bat` | CRLF, ideálně jen ASCII |
| `.md` / `.json` / `.toml` | UTF-8 bez BOM + LF |
| Konzole | `[Console]::OutputEncoding` = UTF-8 |
