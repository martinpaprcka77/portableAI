# 02 — Konfigurace

## Přehled konfiguračních souborů

| Soubor | Verzovaný | Účel |
| --- | --- | --- |
| `.env.example` | ano | vzor konfigurace v kořeni workspace |
| `env/.env.example` | ano | vzor konfigurace pro runtime |
| `env/.env` | **ne** (gitignored) | skutečné hodnoty včetně API klíče |
| `gists/snippets/*` | ano | hotové konfigurační soubory ke zkopírování |
| `data/reasonix/config.toml` | **ne** | vzor konfigurace Reasonixu vysazený ze `gists/snippets/reasonix.toml`; Reasonix ho sám nečte — zkopírujte ho tam, odkud ho čte (viz „Reasonix: cachování a cena“) |
| `.reasonix/` | **ne** (gitignored) | runtime stav agenta (tasky, snapshoty), stejně jako `logs/` a `bin/` |
| `session-*.md` | **ne** (gitignored) | transkript běžící session agenta v kořeni workspace |
| `.vscode/settings.json` | ano | nastavení editoru (encoding, EOL) |
| `.editorconfig` | ano | vynucení konvencí v editorech |

## Proměnné prostředí

| Proměnná | Význam | Výchozí |
| --- | --- | --- |
| `DEEPSEEK_API_KEY` | autentizace vůči DeepSeek API | — (nutné vyplnit) |
| `DEEPSEEK_BASE_URL` | endpoint OpenAI-kompatibilního API | `https://api.deepseek.com/v1` |
| `DEEPSEEK_MODEL` | model pro běžné úlohy | `deepseek-flash` |
| `DEEPSEEK_REASONER_MODEL` | model pro reasoning | `deepseek-v4-pro` |
| `ANTHROPIC_BASE_URL` | endpoint pro Claude Code | `https://api.deepseek.com/anthropic` |
| `ANTHROPIC_AUTH_TOKEN` | token pro Claude Code | odvozeno z `DEEPSEEK_API_KEY` |
| `ANTHROPIC_MODEL` | model pro Claude Code | `deepseek-chat` — Anthropic-kompatibilní brána má vlastní názvy |
| `REASONIX_HOME` | celý Reasonix home (konfigurace, stav, cache) | `%APPDATA%\reasonix` |
| `REASONIX_CACHE_HOME` | jen cache Reasonixu | `%LOCALAPPDATA%\reasonix\cache` |
| `PORTABLEAI_PI_EXTENSIONS` | `1` nainstaluje volitelné rozšíření Pi (`pi-reasonix`) | `1` |
| `PI_REASONIX_ENABLED` | `0` vypne rozšíření `pi-reasonix` | `1` |
| `PI_REASONIX_CACHE` | cache-first smyčka rozšíření (stabilizace prefixu) | `1` |
| `PI_REASONIX_COST` | cost control rozšíření (kompakce tool výsledků) | `1` |
| `PI_REASONIX_METRICS` | sběr cache a cost metrik | `1` |
| `REASONIX_RESULT_CAP_TOKENS` | strop tokenů na jeden tool výsledek | `3000` |
| `REASONIX_SCAVENGE` | `1` doplní tool calls vytažené z `<think>` | `0` |
| `PORTABLE_AI_LOG_LEVEL` | výchozí úroveň logování | `INFO` |
| `NODE_ENV` | režim Node | `development` |

Model a ceny Reasonixu v `.env` nejsou — Reasonix je čte ze své konfigurace
(`reasonix.toml` / `config.toml`), protože se vážou na konkrétního
poskytovatele, ne na proces. Proměnné `REASONIX_*` výše mění jen umístění
jeho souborů.

## Reasonix: cachování a cena

Reasonix stojí na **byte-stabilním prefixu** DeepSeeku: dokud se začátek
requestu nemění, vrací DeepSeek většinu promptu z diskové cache a cachovaný
vstup je řádově levnější než cache miss. Konfigurace tedy „nezapíná cache“ —
hlídá, aby prefix zůstal stabilní, a aby se náklady daly odečíst.

### Kde konfigurace bydlí

```
flag > ./reasonix.toml (projekt) > <Reasonix home>/config.toml > výchozí hodnoty
```

`<Reasonix home>` je na Windows `%APPDATA%\reasonix` a přesune ho
`REASONIX_HOME` (i se stavem a cache). Vzor drží
`gists/snippets/reasonix.toml`; setup ho vysadí do `data/reasonix/config.toml`,
což je jen výchozí bod ke zkopírování — Reasonix ten soubor sám nečte.
Postup: [`gists/0002-reasonix-config.md`](../gists/0002-reasonix-config.md).

### Cache

| Klíč | Význam |
| --- | --- |
| `[agent] compact_ratio` | jediný automatický trigger kompakce (0.30–0.85). Nižší hodnota = dřívější summary a kratší prefix → **méně cache hitů**. Výchozí `0.80`. |
| `[environment] enabled` | vloží stabilní souhrn prostředí do promptu; vypnutý souhrn znamená méně stabilní prefix. |
| `[ui] show_turn_usage` | u každého requestu vypíše tokeny a cenu včetně cachované části. |
| `[desktop] status_bar_items` | obsahuje `cache`, `cache_avg`, `turn_cache_tokens` a `cost`. |

Efektivní hodnotu a její zdroj vypíše `reasonix config compact-ratio`; živé
statistiky `/status` v interaktivní relaci. Denní ledger leží v
`%APPDATA%\reasonix\stats\<datum>.jsonl` (položky `cache_hit`, `cache_miss`,
`cost_amount`, `pricing_fingerprint`).

### Cena

Ceny nepinujte, dokud k tomu nemáte důvod: Reasonix má vlastní **oficiální
tabulku** (`cache_hit` / `input` / `output` za 1M tokenů) a klíč `prices`
v `[[providers]]` ji přebije — ručně zapsaná sazba se pak hlásí jako
„custom price protected“ a dál se neaktualizuje.

| Klíč | Význam |
| --- | --- |
| `billing_currency` | měna pevných sazeb poskytovatele (`CNY`/`USD`), ke které se ceny vážou. |
| `[billing] display_currency` | `auto`/`CNY`/`USD`; mění jen zobrazení (totéž `reasonix config currency`). |
| `max_output_tokens` | strop výstupu na jeden turn — cost control. `0` = ponechat serveru. |
| `model_overrides` | per-model override stropu (dražší model dostane větší prostor). |

`price` (jedna sazba pro celého poskytovatele) je jen záložní hodnota pro
modely, které katalog nezná; teprve `prices` (per-model) katalog přebíjí
a hlásí se jako „custom price protected“.

Ověřeno na Reasonixu 1.38.11: katalog zná `deepseek-flash` a `deepseek-v4-flash`
(`cache_hit` 0.006, `input` 0.3, `output` 1.2 USD za 1M) i `deepseek-v4-pro`
(`0.044` / `1.32` / `3.96`), zdroj
`https://api-docs.deepseek.com/quick_start/pricing`. Stav ověříte příkazem:

```powershell
reasonix doctor billing    # display currency, sazby a fingerprinty poskytovatelů
```

Když je model v katalogu neznámý (starší nebo přejmenovaný název), zůstane bez
ceny a cost receipt se nevyplní — teprve pak má smysl `prices` dopsat ručně.

## Priority

Hodnoty se čtou v tomto pořadí (první vyhrává):

```
1. Existující proměnná prostředí procesu   ← nejvyšší priorita
2. Hodnota z env/.env
3. Hodnota z .env v kořeni workspace
4. Výchozí hodnota v kódu / ve vzoru
```

`Import-DotEnv` **nepřepisuje** už nastavené proměnné prostředí. Díky tomu lze
jednorázově přebít hodnotu bez editace souboru:

```powershell
$env:DEEPSEEK_MODEL = 'deepseek-v4-pro'
pwsh -File scripts\Get-AiStackInfo.ps1
```

### Priorita zdrojů DEEPSEEK_API_KEY

Původ klíče určuje `Get-EnvValueSource` v tomto pořadí:

```
1. Process scope   ← nejvyšší priorita, označeno POUŽITO
2. User scope
3. Machine scope
4. env/.env
```

Environment má přednost před `.env`. Když klíč rotatedíte v prostředí,
`.env` se automaticky ignoruje a `Setup-DeepSeekStack.ps1` do něj nic
nezapisuje — existuje jediný zdroj pravdy. Aktivní zdroj i maskovaný klíč
vypíše `Get-AiStackInfo.ps1` v sekci `6. API` (položky `zdroj: …`
a `aktivní zdroj`).

### Priorita při expanzi ${VAR}

Hodnota z env (Process/User/Machine) má přednost při expanzi `${VAR}`.
Pokud chcete referenci na hodnotu z `.env`, použijte `${VAR}` s vědomím,
že env může přebít.

### Sémantika zápisu do Process scope

`Import-DotEnv` zapisuje hodnoty z `.env` do Process scope vždy, když
nejsou v Process scope přítomny. To zaručuje, že potomkové procesy
(`claude.cmd`, `dsh`, `pi`) hodnotu zdědí.

Důsledek: pokud shell vznikl před nastavením User scope a Process
scope byl prázdný, diagnostika může hlásit „User scope" jako zdroj,
i když hodnota reálně pochází z `.env`.

Toto je vědomá vlastnost, ne bug. Funkční chování je správné: potomek
vždy dostane klíč, i když diagnostika zdroj interpretuje nepřesně.

## Formát `.env`

Podporované tvary:

```dotenv
# komentář
KEY=hodnota
KEY2="hodnota v uvozovkách"
KEY3='hodnota v apostrofech'
export KEY4=hodnota
```

Podporované substituce uvnitř hodnot:

```dotenv
KEY=${OTHER}      # substituce (hledá v env, teprve pak v .env)
KEY=$OTHER        # ekvivalent k ${OTHER}
KEY=\${OTHER}     # escapováno - zůstane doslovně "${OTHER}"
KEY=\$OTHER       # escapováno - zůstane doslovně "$OTHER"
```

Substituce je rekurzivní (limit 10 úrovní). Přímý cyklus (`A=${B}`, `B=${A}`)
zůstane neexpandovaný a ohlásí se jako `WARN`. Nedefinovaná proměnná v `${VAR}`
se nahradí prázdným řetězcem (též `WARN`). Neplatné tvary (`$1`, `$-`,
osamocené `$`) zůstávají beze změny.

Nepodporované: víceřádkové hodnoty a escape sekvence. Držte se jednoduchého
`KEY=hodnota`.

## Ověřené balíčky

Audit proběhl 2026-09-23 přímo proti živému npm registry (`npm view <pkg> version`)
a proti GitHub API (`/repos/esengine/DeepSeek-Reasonix/releases`). Definici
katalogu drží `Get-ComponentCatalog` ve `scripts/_common.ps1` (setup si ji
načítá do `$ComponentCatalog`); hodnoty odpovídají této tabulce.

| Komponenta | Kategorie | Balíček (skutečný název) | Verze | Zdroj | Ověřovací příkaz |
| --- | --- | --- | --- | --- | --- |
| Reasonix | Required | `reasonix` | 1.38.11 | npm | `reasonix --version` |
| Pi | Recommended | `@earendil-works/pi-coding-agent` | 0.87.1 | npm | `pi --version` |
| Claude Code | Optional | `@anthropic-ai/claude-code` | 2.1.280 | npm | `claude --version` |
| DeepSeek Harness | Optional | `@deepseek-ai/dsh` | 0.1.5-rc.3 | npm | `dsh --version` |
| Pi rozšíření (volitelné) | — | `pi-reasonix` | 1.1.0 | npm | bez binárky — načítá ho Pi |

Jména, která jsou v oběhu, ale **nejsou** správná, a proč:

| Název | Stav | Vysvětlení |
| --- | --- | --- |
| `dsh` (bez scope) | špatně | Na npm existuje, ale je to „A shell written in JavaScript“ (`infusion/node-dsh`), nikoli DeepSeek Harness. |
| `@deepseek-ai/deepseek-harness` | neexistuje | 404. Skutečný název balíčku je `@deepseek-ai/dsh`. |
| `@mariozechner/pi-coding-agent` | zastaralé | Existuje (0.73.1, `badlogic/pi-mono`), ale kanonický scope je dnes `@earendil-works/pi-coding-agent` (0.87.1). `pi-reasonix` deklaruje peer závislost jen na scope `@earendil-works`. |
| `pi-reasonix` jako „Pi agent“ | špatně | Je to rozšíření pro Pi, ne náhrada agenta. Instaluje se jako `Extension`, ne jako komponenta. |

### Alternativní zdroje pro Reasonix

Reasonix je zároveň na npm, ve wingetu i jako GitHub release. Workspace volí npm
kvůli přenositelnosti; ostatní cesty jsou zdokumentované pro offline instalaci:

| Zdroj | Příkaz / URL | Poznámka |
| --- | --- | --- |
| npm | `npm install -g --prefix bin/npm-global reasonix@1.38.11` | **zvoleno** — vše zůstane ve workspace |
| winget | `winget install --id ESEngine.ReasonixCLI --exact` | instaluje do profilu uživatele ⇒ **není** portable |
| winget (desktop) | `winget install --id ESEngine.ReasonixDesktop --exact` | desktop aplikace, ne CLI |
| GitHub release (CLI) | `reasonix-windows-amd64.zip` z tagu `v1.38.11` | pro offline instalaci; release obsahuje i `SHA256SUMS` |
| GitHub release (desktop) | `Reasonix-windows-amd64.zip` z tagu `desktop-v1.38.11` | ~223 MB, desktop aplikace |

## Kategorie komponent a výběr instalace

Každá komponenta má v katalogu `Category`, které určuje, kdy ji setup
instaluje:

| Kategorie | Komponenty | Kdy se instaluje |
| --- | --- | --- |
| `Required` | `reasonix` | vždy |
| `Recommended` | `pi` | vždy, kromě `-SkipOptional` |
| `Optional` | `claude`, `dsh` | jen když je jmenovitě vyžádáte v `-InstallOptional` |

`-InstallOptional` přijímá `DisplayName`, `Name`, `Binary` i `Package`
(bez ohledu na velikost písmen):

```powershell
pwsh -File scripts\Setup-DeepSeekStack.ps1 -InstallOptional claude,dsh
pwsh -File scripts\Setup-DeepSeekStack.ps1 -SkipOptional          # jen reasonix
```

### Kde se komponenta hledá

`Test-Component` (`scripts/_common.ps1`) prohledá pět režimů a vrací `Found`,
`Source`, `Path`, `Version`, `Portable` a `MultipleFound`. Vítězí první zásah
v tomto pořadí:

| Pořadí | `Source` | Cesta |
| --- | --- | --- |
| 1 | `workspace` | `<root>/bin/npm-global/<binárka>.cmd` |
| 2 | `workspace-local` | `<root>/node_modules/.bin/<binárka>.cmd` |
| 3 | `global-npm` | `%APPDATA%\npm\<binárka>.cmd` |
| 4 | `system` | `Get-Command <binárka>` |
| 5 | `none` | nenalezeno |

`Portable` je `$true` jen pro `workspace` a `workspace-local`, tedy pro cesty
uvnitř workspace. Setup se podle toho rozhoduje:

1. `Portable` → hotovo, instalace se přeskočí.
2. Nalezeno mimo workspace → **instaluje se do `bin/npm-global`**; globální
   instalace se za přenositelnou nepovažuje. S `-UseGlobalIfPresent` se místo
   toho použije globální instalace a ohlásí se `WARN`.
3. Nenalezeno → instaluje se podle kategorie (tabulka výše).

Nalezení nástroje v globálním `PATH` tedy **nikdy** není důvod instalaci do
workspace vynechat. Stav hlídače hlásí `Get-AiStackInfo.ps1` v sekci
`7. AI nástroje` (rozdělená podle kategorií) a `Test-Workspace.ps1`
v kontrole 16 (`Required` komponenty v workspace).

## Lokální npm prefix

Nástroje se instalují do `bin/npm-global`, ne globálně. Používá se globální
režim npm s vlastním prefixem, takže spustitelné shimy leží přímo v prefixu:

```
bin/npm-global/
├── reasonix.cmd          ← shim (Windows)
├── claude.cmd
├── dsh.cmd
├── pi.cmd
└── node_modules/
    ├── reasonix/
    └── .bin/             ← shimy pro balíčky instalované v lokálním režimu
```

`launcher/Menu.ps1` přidává do `PATH` obě cesty — `bin/npm-global` i
`bin/npm-global/node_modules/.bin`. Ručně to uděláte takto:

```powershell
$env:PATH = "$PWD\bin\npm-global;$PWD\bin\npm-global\node_modules\.bin;$env:PATH"
```

Instalace a ověření jedné komponenty:

```powershell
npm install -g --prefix bin\npm-global reasonix@1.38.11
& .\bin\npm-global\reasonix.cmd --version
```

## Nastavení editoru

`.vscode/settings.json` vynucuje:

- `files.encoding = utf8`, `files.eol = \n` (globálně)
- `editor.tabSize = 4` pro PowerShell, `2` pro JSON a Markdown
- zapnutý PSScriptAnalyzer

`.editorconfig` navíc vynucuje `utf-8-bom` + `crlf` pro `*.ps1` a `crlf` pro
`*.cmd`. To je zásadní — PowerShell potřebuje BOM kvůli diakritice.

## Změna konfigurace

Po jakékoli změně konfigurace:

```powershell
pwsh -File scripts\Get-AiStackInfo.ps1   # ověř, že se hodnoty načetly
pwsh -File scripts\Test-Workspace.ps1    # ověř, že struktura drží
reasonix doctor billing                  # ověř, že Reasonix zná sazby poskytovatelů
```
