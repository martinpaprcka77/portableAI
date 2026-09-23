# 0004 — Instalace a konfigurace Pi a rozšíření `pi-reasonix`

**Kdy to použít:** chcete Pi coding agent ve workspace a volitelně k němu
DeepSeek optimalizace z rozšíření `pi-reasonix`.

## Dva různé balíčky

| Co | Balíček | Verze | V čem je |
| --- | --- | --- | --- |
| Pi (agent, binárka `pi`) | `@earendil-works/pi-coding-agent` | 0.87.1 | komponenta `Pi`, kategorie `Recommended` |
| Rozšíření pro DeepSeek | `pi-reasonix` | 1.1.0 | volitelné, zapíná `PORTABLEAI_PI_EXTENSIONS=1` |

`pi-reasonix` **není** náhrada Pi — je to rozšíření, které se načítá do Pi.
Proto se do katalogu (`Get-ComponentCatalog` ve `scripts/_common.ps1`) přidává
jako `Extension`, ne jako samostatná komponenta. Podrobnosti:
[docs/06-DEVIATIONS.md](../docs/06-DEVIATIONS.md).

## Instalace (do workspace, bez admin práv)

```powershell
. .\scripts\_common.ps1
$prefix = Join-Path -Path (Get-WorkspaceRoot) -ChildPath 'bin/npm-global'

# 1. Pi agent (kategorie Recommended)
npm install -g --prefix $prefix --no-fund --no-audit @earendil-works/pi-coding-agent@0.87.1

# 2. Volitelné rozšíření s DeepSeek optimalizacemi
#    --ignore-scripts  : postinstall "npm run build || true" na Windows selže
#                        (tsc bez tsconfig.json, "|| true" není cmd příkaz),
#                        přitom balíček už veze předpřipravený dist/.
#    --legacy-peer-deps: peer závislosti jsou volné ("*"); bez přepínače npm
#                        stáhne druhou kopii Pi agenta do vnořeného node_modules.
npm install -g --prefix $prefix --no-fund --no-audit --ignore-scripts --legacy-peer-deps pi-reasonix@1.1.0

# 3. Ověření
$env:PATH = "$prefix;$env:PATH"
& (Join-Path $prefix 'pi.cmd') --version
Test-Path (Join-Path $prefix 'node_modules\pi-reasonix\package.json')
```

Nebo použijte `scripts\Setup-DeepSeekStack.ps1`, který to dělá automaticky
(komponenta `Pi` v katalogu `Get-ComponentCatalog`).

## Konfigurace

Z `.env` potřebuje Pi jen klíč; endpoint a model si řídí sám (settings.json,
`/model`). Zapnutí rozšíření stačí jedním přepínačem:

```dotenv
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
PORTABLEAI_PI_EXTENSIONS=1
```

Rozšíření `pi-reasonix` má vlastní přepínače — výchozí hodnoty fungují, měňte
je jen vědomě:

| Proměnná | Výchozí | Význam |
| --- | --- | --- |
| `PI_REASONIX_ENABLED` | `1` | `0` rozšíření vůbec neaktivuje |
| `PI_REASONIX_CACHE` | `1` | cache-first smyčka: stabilizace prefixu (byte 0 = systémový prompt) |
| `PI_REASONIX_COST` | `1` | cost control: kompakce dlouhých tool výsledků |
| `PI_REASONIX_METRICS` | `1` | sběr cache a cost metrik |
| `REASONIX_RESULT_CAP_TOKENS` | `3000` | strop tokenů na jeden tool výsledek (kompakce drží hlavu i ocas) |
| `REASONIX_SCAVENGE` | `0` | `1` doplní tool calls vytažené z `<think>` |

## Cache a cena v Pi

Rozšíření dělá v Pi totéž, co dělá Reasonix nativně: hlídá, aby prefix requestu
zůstal byte-stabilní (z toho plynou cache hity), a aby dlouhé tool výstupy
nepolykaly kontext. Aktivaci i živé statistiky zobrazíte příkazem
`/reasonix-status` — zajímavé jsou `Prefix stable`, `Hit ratio` (cíl 85-97 %)
a `Results compacted`.

Model se v Pi volí přes `/model`; držte se názvů z aktuálního ceníku
(`deepseek-flash`, `deepseek-v4-flash`, `deepseek-v4-pro`) — viz
`docs/02-CONFIG.md`, sekce „Reasonix: cachování a cena“.

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
| Pi ignoruje rozšíření | session neběží na DeepSeek modelu (`deepseek-*`), nebo je `PI_REASONIX_ENABLED=0` |
| Rozšíření se nenainstalovalo | v `.env` není `PORTABLEAI_PI_EXTENSIONS=1`, nebo jste spustili setup s `-SkipOptional` |
| Rozšíření hlásí `command failed: npm run build \|\| true` | chybí `--ignore-scripts` (viz „Instalace“ výše); `dist/` je v balíčku už hotové |
| V `node_modules` je druhá kopie Pi agenta | chybí `--legacy-peer-deps` (peer závislosti `pi-reasonix` jsou volné `*`) |
| Instalace spadne na síti | nastavte `npm config set proxy` nebo použijte `-SkipInstall` |
