# Changelog

Všechny významné změny tohoto projektu jsou dokumentovány v tomto souboru.

Formát vychází z [Keep a Changelog](https://keepachangelog.com/cs/1.1.0/)
a projekt dodržuje [Semantic Versioning](https://semver.org/lang/cs/).

## [Unreleased]

## [1.0.3] - 2026-09-23

### Added

- **Root zástupci pro rychlý přístup** - `Start.cmd`, `Portal.cmd`,
  `Diag.cmd`, `Test.cmd`, `Setup.cmd` a `Update.cmd`. Každý má `@echo off`
  + `setlocal`, detekci `pwsh.exe` s fallbackem na `powershell.exe`, obsah
  v ASCII kvůli konzoli a koncovky CRLF. Argumenty předávají dál
  (`Test.cmd -Fix`, `Diag.cmd -Json`, `Update.cmd -Fix`).
- **`scripts/SelfHeal.ps1`** - self-healing kontrola a oprava odchylek
  portable workspace: UTF-8 BOM, řádkové koncovky podle `.gitattributes`,
  chybějící runtime adresáře, `bin/npm-global` v User PATH, `env/.env`
  proti vzoru, `VERSION` vs `CHANGELOG.md`, duplicity v `PATH`,
  untracked soubory, `PSScriptAnalyzer`, povinná komponenta `reasonix`
  a escape artefakty v markdownu. Výchozí režim nic nemění; `-Fix`
  provádí jen bezpečné idempotentní opravy, `-SkipAnalyzer` zrychlí běh
  a `-Json` vrací strojově čitelný výstup pro CI.
- **`docs/METAPROMPT-REVISION.md`** - revize původního zadání po realizaci:
  tabulka vyvrácených premis, aktuální fáze a přehled toho, co vzniklo
  mimo plán.
- **`docs/prompts-audit.md`** a **`docs/docs-manual-audit.md`** - audity
  promptů, dokumentace a manuálu s tabulkou po souborech.
- **`docs/history/`** - archiv hotových zadání; přesunut tam
  `FOLLOWUP-1-METAPROMPT.md` (dříve `FOLLOWUP-METAPROMPT.md` v kořeni).
- **`README-HISTORY.md`** v kořeni - rozcestník, proč jsou historická
  zadání v archivu a kde je aktuální stav workspace.
- **Sekce „Verze a kompatibilita“** v `prompts/README.md` s datem
  poslední revize, počtem promptů a odkazem na audit.

### Changed

- **`METAPROMPT.md` označen jako historický** - na začátku má poznámku
  s odkazem na `VERSION`, `CHANGELOG.md` a `docs/METAPROMPT-REVISION.md`.
  Obsah zadání se nepřepisuje, jen se jednoznačně určuje jeho role.
- **`METAPROMPT.md` a `FOLLOWUP-METAPROMPT.md`: obnoven čitelný markdown.**
  Oba soubory měly v repu artefakty vzniklé kopírováním textu: escapované
  markdown znaky (`\#` → `#`, `\*\*` → `**`), zdvojená zpětná lomítka
  v cestách (`C:\\portableAI\\`), zdvojené nové řádky (odstavce oddělovaly
  tři prázdné řádky) a odsazení zapsané jako entita `&#x20;`. Dokumenty se
  proto renderovaly doslovně jako `\# ROLE`. **Text se nezměnil** - mění se
  jen escape artefakty a výsledné formátování.
- **`README.md` aktualizováno** - nové sekce „Rychlý start“ (tabulka
  zástupců), „Struktura workspace“ (zkrácený strom) a „Verze“ (odkazy na
  `VERSION`, `CHANGELOG.md`, revizi zadání a auditní stopu).
- **`prompts/00-system.md`** - sekce „Dostupné nástroje“ rozlišuje primární
  agent `reasonix` od volitelných, popisuje instalaci do `bin/npm-global`
  a volitelné rozšíření `pi-reasonix`.
- **`scaffold/directory-tree.txt`** přegenerován podle skutečné struktury
  po přesunu historického zadání a přidání nových souborů.

### Fixed

- **Zastaralé údaje v dokumentaci** (viz `docs/docs-manual-audit.md`):
  - `manual/01-cheatsheet.md` uváděl „8 kontrol“ u `Test-Workspace.ps1` -
    realita je 15. Nejzastaralejší místo v dokumentaci.
  - `docs/04-ARCHITECTURE.md` uváděl „self-test osmi oblastí“ - opraveno
    na patnáct.
  - `docs/06-DEVIATIONS.md` uváděl „nyní 14 kontrol“ - doplněna 15.
    kontrola („Integrita .env“) a revizní poznámka u počtu odkazů
    na landing page.
  - `docs/03-TROUBLESHOOTING.md` citoval `analyzátor: FAIL`, ale kontrola
    se jmenuje `PSScriptAnalyzer`.
  - `landing/index.html` zobrazoval `v1.0.1` - srovnáno s `VERSION`.
- **Zastaralé komentáře ve skriptech** (jen comment-based help, žádná
  změna logiky ani parametrů):
  - `scripts/Test-Workspace.ps1`: „Ověří čtrnáct oblastí“ → „patnáct“,
    do výčtu doplněna kontrola 15 („Integrita .env“).
  - `scripts/Setup-DeepSeekStack.ps1`: „Postupuje ve čtyřech krocích“ →
    „v pěti“ (skript loguje `Krok N/5`).
- **`CHANGELOG.md`**: doplněny chybějící odkazy na verze `1.0.2` a `1.0.3`
  a srovnán odkaz `[Unreleased]`, který mířil na `v1.0.1`.

### Verified

- `Test-Workspace.ps1` → `WORKSPACE TEST: PASS` (15/15 kontrol).
- `SelfHeal.ps1` → report `OK: 8 | WARN: 3 | FAIL: 0` (bez `-Fix` nic nemění).
- `SelfHeal.ps1 -WhatIf` i `SelfHeal.ps1 -Fix` ověřeny v sandbox kopii
  workspace: `-WhatIf` nezměnil žádný soubor, `-Fix` opravil BOM,
  koncovky oběma směry, vytvořil chybějící adresáře i `env/.env`
  a byl idempotentní při druhém běhu.
- `Invoke-ScriptAnalyzer -Path .\scripts\ -Recurse -Severity Warning, Error`
  → prázdný výstup (7 skriptů včetně `SelfHeal.ps1`).
- Všech 11 zástupců `.cmd` (5 v `launcher/` + 6 v kořeni) má CRLF a ASCII obsah.

## [1.0.2] - 2026-09-23

### Fixed

- **`ANTHROPIC_AUTH_TOKEN=${DEEPSEEK_API_KEY}` se ukládal doslovně.** Vzory
  používaly substituci, kterou `Import-DotEnv` neuměl, takže hodnota tokenu
  byla doslova `${DEEPSEEK_API_KEY}` a Claude Code proti DeepSeek padal na
  `401`. `Import-DotEnv` nyní hodnoty expanduje.
- **`Test-Workspace.ps1` skenoval vendor a runtime soubory.** Rekurzivní
  kontroly (UTF-8 BOM, CRLF/LF, `PSScriptAnalyzer`, komentářová nápověda)
  procházely celý workspace a vylučovaly jen `.git`, takže po instalaci npm
  balíčků do `bin/npm-global` hlásily `FAIL` na cizích souborech a `-Fix`
  by na ně sahal. Nový `Get-TestableFiles` s `$script:ExcludedPathPatterns`
  (`node_modules`, `bin/*`, `logs`, `data`, `temp`, `.git`) filtruje na
  jednom místě a používá ho každá kontrola.
  (`Get-TestableFiles` je záměrně v množném čísle - vrací kolekci; názvové
  pravidlo `PSUseSingularNouns` je cíleně potlačeno u funkce.)

### Added

- **`Expand-DotEnvValue` v `scripts/_common.ps1`.** Podporuje `${VAR}`,
  `$VAR`, escape `\${VAR}` / `\$VAR` (zůstane doslovně) a nechává neplatné
  tvary (`$1`, `$-`, osamocené `$`) beze změny. Expanze je rekurzivní
  (limit 10 úrovní). Přímý cyklus (`A=${B}`, `B=${A}`) se ohlásí jako `WARN`
  a reference zůstane neexpandovaná; nedefinovaná `${VAR}` se ohlásí jako
  `WARN` a nahradí prázdným řetězcem.
- **`Get-EnvValueSource`** - jediné místo s prioritou zdrojů
  (Process -> User -> Machine -> `.env`). Vrací `Source`, `Value`, `Found`;
  hodnota je raw, maskuje až volající.
- **`Import-DotEnv` je dvoufázový** (parse -> expand -> zápis do Process
  scope), takže fungují i dopředné reference. Vrací už expandované hodnoty.
- **`Get-AiStackInfo.ps1`** vypisuje v sekci `6. API` zdroje klíče
  (`zdroj: Process/User/Machine/.env`, `aktivní zdroj`) a maskovaný
  `ANTHROPIC_AUTH_TOKEN`. Sekce `5. Prostředí` kontroluje neexpandované
  substituce.
- **`Setup-DeepSeekStack.ps1`** detekuje klíč v prostředí před prací
  s `.env` a ohlásí, že env přebíjí `.env`.
- **Nová kontrola 15 „Integrita .env"** v `Test-Workspace.ps1`: `WARN` jen
  při různých hodnotách env vs. `.env`, při chybějícím klíči nebo při
  neexpandovaných substitucích; stejná hodnota v obou je `OK`.

### Changed

- **Vzory `.env.example`, `env/.env.example` a `gists/snippets/.env.example`**
  srovnány: hlavička s pravidly a detekcí klíče, `DEEPSEEK_API_KEY`
  zakomentovaný, dokumentace substitucí a neaktivní referenční příklad
  `TEST_A`/`TEST_B`.
- **`DEEPSEEK_API_KEY`: priorita env před `.env`** je nyní explicitní
  v `Get-EnvValueSource` i v expanzi `${VAR}`.
- **Dokumentace**: `docs/02-CONFIG.md` (priorita zdrojů a expanze,
  `Formát .env` už neuvádí substituci jako nepodporovanou),
  `manual/00-quickstart.md` (krok 3 ověří env), `manual/03-faq.md`
  (nové otázky 21 a 22), `gists/0003-claude-deepseek.md`.
- **`docs/02-CONFIG.md`** popisuje i „Sémantiku zápisu do Process scope"
  a `docs/06-DEVIATIONS.md` má záznam o zavádějícím zdroji v diagnostice.

### Known issues

- **`Get-AiStackInfo` může v ojedinělých případech hlásit nepřesný zdroj
  klíče** (`User` místo `.env`) kvůli seedu do Process scope. Funkční
  chování je správné, jde o kosmetickou nepřesnost v reportu.
  Detail: `docs/06-DEVIATIONS.md`.

## [1.0.1] - 2026-09-23

### Fixed

- **Ověřeny všechny npm balíčky proti živému registry.** Původní odhady
  v `$ComponentCatalog` obsahovaly dvě chybná jména:
  - DeepSeek Harness: `dsh` → **`@deepseek-ai/dsh`** (`dsh` na npm je
    „A shell written in JavaScript“ z `infusion/node-dsh`)
  - Pi: `pi-reasonix` → **`@earendil-works/pi-coding-agent`** (`pi-reasonix`
    je rozšíření pro Pi, ne agent)
- **Vyřešena blokující odchylka „Reasonix mimo npm“.** Audit zjistil, že
  `reasonix` na npm existuje (oficiální, `esengine/DeepSeek-Reasonix`,
  v1.38.11), a že existuje i winget balíček `ESEngine.ReasonixCLI`.
  Požadavek na vlastní `Install-ReasonixBinary` se ruší — Reasonix se
  instaluje z npm do lokálního prefixu a workspace tak zůstává přenosný.
- **Instalace změněna na `npm install -g --prefix bin/npm-global`.** Shimy
  (`reasonix.cmd`, `claude.cmd`, `dsh.cmd`, `pi.cmd`) leží přímo v prefixu;
  `launcher/Menu.ps1` přidává do `PATH` i `bin/npm-global/node_modules/.bin`
  kvůli zpětné kompatibilitě.
- **Přidán krok `Verify`.** Setup po každé instalaci ověří, že binárka
  odpovídá na `--version`; výsledek se hlásí i při `-SkipInstall`. Chybějící
  shim je `FAIL` jen v běhu, který komponentu skutečně instaloval.
- **`PSScriptAnalyzer` clean pass** na `scripts/` i `launcher/` (0 nálezů
  při `-Severity Warning, Error`).
- **Opravena koncovka `FOLLOWUP-METAPROMPT.md`** (CRLF → LF), aby odpovídala
  `.gitattributes`.

### Added

- **`docs/06-DEVIATIONS.md`** — auditní stopa: vyvrácené premisy zadání,
  tabulka ověřených balíčků a tabulka odchylek s dopadem a doporučením.
- **`docs/02-CONFIG.md`** — sekce „Ověřené balíčky“ (verze, zdroj, ověřovací
  příkaz), tabulka alternativních zdrojů pro Reasonix (npm / winget / GitHub
  release) a popis skutečného tvaru lokálního npm prefixu.
- **`Test-Workspace.ps1` rozšířen z 8 na 14 kontrol**: LF u `.md`/`.json`/`.toml`
  (s `-Fix`), komentářová nápověda u `.ps1`, relativní odkazy v `README.md`,
  spárované HTML tagy v `landing/index.html`, fáze 0–10 v `METAPROMPT.md`
  a YAML frontmatter promptů.
- **YAML frontmatter (`title`, `description`)** u všech 11 souborů v `prompts/`.
- **`PORTABLEAI_PI_EXTENSIONS`** v `.env.example`, `env/.env.example`
  a `gists/snippets/.env.example` — zapíná volitelné rozšíření `pi-reasonix@1.1.0`.
- **`Menu.ps1 -Action pi`** pro spuštění Pi (nabídka menu zůstává dle
  specifikace beze změny).

### Changed

- `scripts/Setup-DeepSeekStack.ps1`: nové funkce `Get-ComponentInstallTarget`,
  `Resolve-ComponentShim`, `Install-NpmComponent`, `Test-ComponentBinary`
  a `Test-SwitchEnabled`; katalog komponent má pole `Source`, `Version`,
  `Install`, `Verify`, `VerifyArgs`, `AltSources` a `Extension`.
- `docs/02-CONFIG.md`, `manual/03-faq.md`, `gists/0004-pi-reasonix.md`:
  aktualizované instalační příkazy a rozlišení Pi agenta vs. rozšíření.
- `_common.ps1`: `docs/06-DEVIATIONS.md` přidán do manifestu povinných souborů.

### Verified

- `reasonix` end-to-end v dočasném prefixu: `npm install -g --prefix <tmp>
  reasonix@1.38.11` → `reasonix.cmd --version` → `reasonix v1.38.11`, exit 0.
- `Invoke-ScriptAnalyzer -Path .\scripts\ -Recurse -Severity Warning, Error`
  → prázdný výstup.
- `Test-Workspace.ps1` → `WORKSPACE TEST: PASS` (14/14).
- `Setup-DeepSeekStack.ps1 -WhatIf -SkipInstall` → exit 0.
- Landing page: staticky ověřena (spárované tagy, 14/14 relativních odkazů).

## [1.0.0] - 2026-09-23

### Added

- Initial portable workspace
- Setup script for Reasonix, Claude Code, DSH, Pi
- Diagnostics script with banner + logging + JSON output
- Repair script for encoding and git issues
- Launcher with interactive menu
- Static landing page
- Prompt library (7 promptů + 3 šablony)
- Full documentation + manual
- 5 gists with reusable snippets

[Unreleased]: https://example.invalid/portable-ai/compare/v1.0.3...HEAD
[1.0.3]: https://example.invalid/portable-ai/compare/v1.0.2...v1.0.3
[1.0.2]: https://example.invalid/portable-ai/compare/v1.0.1...v1.0.2
[1.0.1]: https://example.invalid/portable-ai/compare/v1.0.0...v1.0.1
[1.0.0]: https://example.invalid/portable-ai/releases/tag/v1.0.0

