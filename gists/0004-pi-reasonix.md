# 0004 — Instalace a konfigurace Pi a rozšíření `pi-reasonix`

**Kdy to použít:** chcete Pi coding agent ve workspace a volitelně k němu
DeepSeek optimalizace z rozšíření `pi-reasonix`.

## Dva různé balíčky

| Co | Balíček | Verze | V čem je |
| --- | --- | --- | --- |
| Pi (agent, binárka `pi`) | `@earendil-works/pi-coding-agent` | 0.87.1 | povinná komponenta `Pi` |
| Rozšíření pro DeepSeek | `pi-reasonix` | 1.1.0 | volitelné, zapíná `PORTABLEAI_PI_EXTENSIONS=1` |

`pi-reasonix` **není** náhrada Pi — je to rozšíření, které se načítá do Pi.
Proto se do `$ComponentCatalog` přidává jako `Extension`, ne jako samostatná
komponenta. Podrobnosti: [docs/06-DEVIATIONS.md](../docs/06-DEVIATIONS.md).

## Instalace (do workspace, bez admin práv)

```powershell
. .\scripts\_common.ps1
$prefix = Join-Path -Path (Get-WorkspaceRoot) -ChildPath 'bin/npm-global'

# 1. Pi agent (povinné)
npm install -g --prefix $prefix --no-fund --no-audit @earendil-works/pi-coding-agent@0.87.1

# 2. Volitelné rozšíření s DeepSeek optimalizacemi
npm install -g --prefix $prefix --no-fund --no-audit pi-reasonix@1.1.0

# 3. Ověření
$env:PATH = "$prefix;$env:PATH"
& (Join-Path $prefix 'pi.cmd') --version
```

Nebo použijte `scripts\Setup-DeepSeekStack.ps1`, který to dělá automaticky
(komponenta `Pi` v `$ComponentCatalog`).

## Konfigurace

Pi čte stejné proměnné prostředí jako Reasonix, takže stačí sdílený `.env`:

```dotenv
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
DEEPSEEK_BASE_URL=https://api.deepseek.com/v1
REASONIX_CONFIG_DIR=./data/reasonix
REASONIX_MODEL=deepseek-chat
REASONIX_REASONING_EFFORT=medium
PORTABLEAI_PI_EXTENSIONS=1
```

## Proč `REASONIX_CONFIG_DIR`

Pi i Reasonix tak sdílejí jeden `config.toml` v `data/reasonix/`. Když
nakonfigurujete model na jednom místě, projeví se to u obou — a po přesunu
workspace na jiný disk se konfigurace přenese s ním.

## Ověření

```powershell
. .\scripts\_common.ps1
$null = Import-DotEnv -Path (Join-Path (Get-WorkspaceRoot) 'env/.env')
$prefix = Join-Path (Get-WorkspaceRoot) 'bin/npm-global'
$env:PATH = "$prefix;$prefix\node_modules\.bin;$env:PATH"
pi --version
```

> Pro běžnou práci použijte `pwsh -File launcher\Menu.ps1 -Action pi`, které
> prostředí připraví automaticky (`Initialize-LauncherEnvironment`).

## Odinstalace

```powershell
npm uninstall -g --prefix bin\npm-global pi-reasonix
```

Nic se nezapisuje mimo složku workspace.

## Časté chyby

| Chyba | Řešení |
| --- | --- |
| `pi` není rozpoznán | `bin\npm-global` není v `PATH`; spusťte launcher, ten ho přidá |
| `EACCES` / `EPERM` při instalaci | běžíte v chráněném adresáři; přesuňte workspace mimo `Program Files` |
| Pi ignoruje konfiguraci | není nastavený `REASONIX_CONFIG_DIR` |
| Rozšíření se nenainstalovalo | v `.env` není `PORTABLEAI_PI_EXTENSIONS=1` |
| Instalace spadne na síti | nastavte `npm config set proxy` nebo použijte `-SkipInstall` |
