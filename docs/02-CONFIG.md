# 02 — Konfigurace

## Přehled konfiguračních souborů

| Soubor | Verzovaný | Účel |
| --- | --- | --- |
| `.env.example` | ano | vzor konfigurace v kořeni workspace |
| `env/.env.example` | ano | vzor konfigurace pro runtime |
| `env/.env` | **ne** (gitignored) | skutečné hodnoty včetně API klíče |
| `gists/snippets/*` | ano | hotové konfigurační soubory ke zkopírování |
| `data/reasonix/config.toml` | **ne** | vygenerovaná konfigurace Reasonixu |
| `.vscode/settings.json` | ano | nastavení editoru (encoding, EOL) |
| `.editorconfig` | ano | vynucení konvencí v editorech |

## Proměnné prostředí

| Proměnná | Význam | Výchozí |
| --- | --- | --- |
| `DEEPSEEK_API_KEY` | autentizace vůči DeepSeek API | — (nutné vyplnit) |
| `DEEPSEEK_BASE_URL` | endpoint OpenAI-kompatibilního API | `https://api.deepseek.com/v1` |
| `DEEPSEEK_MODEL` | model pro běžné úlohy | `deepseek-chat` |
| `DEEPSEEK_REASONER_MODEL` | model pro reasoning | `deepseek-reasoner` |
| `ANTHROPIC_BASE_URL` | endpoint pro Claude Code | `https://api.deepseek.com/anthropic` |
| `ANTHROPIC_AUTH_TOKEN` | token pro Claude Code | odvozeno z `DEEPSEEK_API_KEY` |
| `ANTHROPIC_MODEL` | model pro Claude Code | `deepseek-chat` |
| `REASONIX_CONFIG_DIR` | kam ukládat konfiguraci Reasonixu | `./data/reasonix` |
| `REASONIX_MODEL` | model Reasonixu | `deepseek-chat` |
| `REASONIX_REASONING_EFFORT` | úsilí reasoningu | `medium` |
| `PORTABLEAI_PI_EXTENSIONS` | `1` nainstaluje volitelné rozšíření Pi (`pi-reasonix`) | `1` |
| `PORTABLE_AI_LOG_LEVEL` | výchozí úroveň logování | `INFO` |
| `NODE_ENV` | režim Node | `development` |

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
$env:DEEPSEEK_MODEL = 'deepseek-reasoner'
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
a proti GitHub API (`/repos/esengine/DeepSeek-Reasonix/releases`). Verze
v `$ComponentCatalog` v `scripts/Setup-DeepSeekStack.ps1` odpovídají této tabulce.

| Komponenta | Balíček (skutečný název) | Verze | Zdroj | Ověřovací příkaz |
| --- | --- | --- | --- | --- |
| Reasonix | `reasonix` | 1.38.11 | npm | `reasonix --version` |
| Claude Code | `@anthropic-ai/claude-code` | 2.1.280 | npm | `claude --version` |
| DeepSeek Harness | `@deepseek-ai/dsh` | 0.1.5-rc.3 | npm | `dsh --version` |
| Pi | `@earendil-works/pi-coding-agent` | 0.87.1 | npm | `pi --version` |
| Pi rozšíření (volitelné) | `pi-reasonix` | 1.1.0 | npm | bez binárky — načítá ho Pi |

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
```
