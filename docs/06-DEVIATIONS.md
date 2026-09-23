# 06 — Odchylky od zadání

Tento dokument je auditní stopa: co se odchýlilo od `METAPROMPT.md`, proč,
s jakým dopadem a co s tím dál. Vznikl ve follow-up session, jejímž úkolem
bylo ověřit build a opravit známé nedostatky.

Jak vznikl:

1. Názvy a verze balíčků byly ověřeny přímo proti živému npm registry
   (`npm view <balíček> version`), wingetu (`winget search reasonix`) a
   GitHub API (`/repos/esengine/DeepSeek-Reasonix/releases`). Datum auditu:
   **2026-09-23**.
2. Cílová verze `reasonix` byla ověřena end-to-end v dočasném prefixu:
   `npm install -g --prefix <tmp> reasonix@1.38.11` → `reasonix.cmd --version`
   → `reasonix v1.38.11`, exit 0.
3. Porovnání skriptů proti původnímu zadání vychází z textové specifikace
   v `METAPROMPT.md` (FÁZE 2, 7, 10 a sekce KONSTRAINY), protože **referenční
   kopie původních skriptů v repozitáři nejsou** — viz níže.

## METAPROMPT errors discovered during build

Zadání obsahovalo tvrzení, která audit vyvrátil. Držíme se ověřené reality,
ne původní premisy.

### 1. „Reasonix NENÍ na npm“ — NEPRAVDA

| | |
| --- | --- |
| **Premisa v zadání** | „Reasonix NENÍ na npm — je to binární distribuce z GitHub releases.“ |
| **Skutečnost** | `reasonix` na npm **je**. Verze 1.38.11, `repository: github.com/esengine/DeepSeek-Reasonix`, `bin.reasonix = bin/reasonix.js`, `homepage: https://github.com/esengine/DeepSeek-Reasonix#readme`. Balíček má `optionalDependencies` `@reasonix/cli-win32-x64@1.38.11` („reasonix prebuilt binary for win32-x64“). Navíc existuje i winget balíček `ESEngine.ReasonixCLI` (moniker `reasonix`, 1.38.11). |
| **Důvod odchylky** | Původní odhad `Package = 'reasonix'` v `$ComponentCatalog` byl **správný**. Požadavek „implementuj instalaci mimo npm přes `Install-ReasonixBinary`“ se tím stává zbytečným. |
| **Co bylo uděláno** | Rozhodnutím uživatele se Reasonix instaluje z npm do lokálního prefixu (`npm install -g --prefix bin/npm-global reasonix@1.38.11`). Samostatná `Install-ReasonixBinary` **nevznikla**. Požadavek „Reasonix mimo npm“ se ruší. winget a GitHub ZIP zůstávají zdokumentované jako alternativy v `AltSources` katalogu a v `docs/02-CONFIG.md`. |
| **Dopad** | Pozitivní: workspace zůstává přenositelný na USB (winget by instaloval do profilu uživatele), odpadá ~23 MB download z GitHubu a vlastní logika pro rozbalování ZIP. Odchylka od literálního znění zadání je vědomá. |

Viz také: `npm view reasonix` → `1.38.11`; `winget show ESEngine.ReasonixCLI` → `1.38.11`.

### 2. „Pi balíček je `@mariozechner/pi-coding-agent`“ — PRAVDA, ale zastaralé

| | |
| --- | --- |
| **Premisa v zadání** | „Pi: `@mariozechner/pi-coding-agent` (ne `pi-reasonix`).“ |
| **Skutečnost** | `@mariozechner/pi-coding-agent` existuje (0.73.1, `badlogic/pi-mono`), ale **kanonický scope je dnes `@earendil-works/pi-coding-agent`** (0.87.1, `earendil-works/pi`, `bin.pi = dist/bundle/cli.js`). `pi-reasonix` ve svých `peerDependencies` deklaruje kompatibilitu **výhradně** se scope `@earendil-works` (`@earendil-works/pi-coding-agent: '*'`), nikoli s `@mariozechner`. |
| **Důvod odchylky** | Instalace Pi ze zastaralého scope by rozbila peer závislost volitelného rozšíření a připravila workspace o 14 minor verzí oprav. |
| **Co bylo uděláno** | `$ComponentCatalog` používá `Package = '@earendil-works/pi-coding-agent'`, `Version = '0.87.1'`, `Source = 'npm'`, `Portable = $true`. Rozšíření `pi-reasonix@1.1.0` je vedeno jako `Extension`, zapínané proměnnou `PORTABLEAI_PI_EXTENSIONS=1`. |
| **Dopad** | Vyšší verze Pi, plná funkčnost DeepSeek rozšíření (`pi-reasonix`), konzistentní peer závislosti. Pozor: `@mariozechner/pi-coding-agent` v katalogu záměrně **není** — dvě verze téhož agenta v jednom prefixu by kolidovaly o binárku `pi`. |

### 3. „Všech 10 fází“ — off-by-one v zadání

| | |
| --- | --- |
| **Premisa v zadání** | `METAPROMPT.md` má 10 fází (FÁZE 1–10). |
| **Skutečnost** | `METAPROMPT.md` definuje **FÁZE 0 až FÁZE 10**, tedy 11 fází. Sekce „ACCEPTANCE CRITERIA“ v `METAPROMPT.md` sama říká „Všech 10 fází dokončeno“, ačkoli nad ní je 11 fází. |
| **Co bylo uděláno** | Kontrola v `Test-Workspace.ps1` ověřuje přítomnost **FÁZE 0–10**. Kontrola na pouhých 10 položek by buď vyžadovala ignorovat FÁZI 0, nebo prohlásit hotový dokument za neúplný. |
| **Dopad** | Žádný funkční dopad; jde o přesnost kontroly. |

## Tabulka balíčků

| Package (v METAPROMPT / odhad) | Skutečný název | Verze | Stav |
| --- | --- | --- | --- |
| `reasonix` (označen jako „neověřený odhad“) | `reasonix` | 1.38.11 | **ponechán** — odhad byl správný |
| `@anthropic-ai/claude-code` | `@anthropic-ai/claude-code` | 2.1.280 | **ponechán** — bez chyby |
| `dsh` | `@deepseek-ai/dsh` | 0.1.5-rc.3 | **opraven** — `dsh` na npm je JS shell (`infusion/node-dsh`) |
| `pi-reasonix` (jako Pi agent) | `@earendil-works/pi-coding-agent` | 0.87.1 | **opraven** — `pi-reasonix` je rozšíření, ne agent |
| — | `pi-reasonix` (rozšíření) | 1.1.0 | **přidán** jako volitelná `Extension` |

Neexistující a zamítnuté varianty, které audit prověřil:

| Název | Výsledek `npm view` | Rozhodnutí |
| --- | --- | --- |
| `@deepseek-ai/deepseek-harness` | `E404 Not Found` | zamítnuto — správný název je `@deepseek-ai/dsh` |
| `@mariozechner/pi-coding-agent` | existuje, 0.73.1 | zamítnuto — zastaralý scope, nekompatibilní peer s `pi-reasonix` |
| `typebox` (peer závislost `pi-reasonix`) | existuje, 1.3.34 | **nepoužit** — rozšíření se instaluje s `--legacy-peer-deps`, takže npm peer závislosti nedoplňuje (viz „Odchylky v souborech“, verze 1.0.4) |

## Odchylky v souborech

| Soubor | Odchylka od specifikace | Dopad | Doporučení |
| --- | --- | --- | --- |
| `scripts/Setup-DeepSeekStack.ps1` | `$ComponentCatalog` měl tři neověřené názvy (`reasonix` OK, `dsh` špatně, `pi-reasonix` špatně) a chybějící `Source`. Nyní obsahuje ověřené `Package`, `Version`, `Source`, `Install`, `Verify`, `VerifyArgs`, `AltSources`, `Extension`. | Bez opravy by setup nainstaloval JS shell místo DeepSeek Harness a místo Pi agenta rozšíření. | Hotovo. Při dalším upgradu balíčků měnit jen `Version` a znovu spustit `Test-Workspace.ps1`. |
| `scripts/Setup-DeepSeekStack.ps1` | Instalace změněna z lokálního režimu (`npm install --prefix`, shimy v `node_modules/.bin`) na globální režim s vlastním prefixem (`npm install -g --prefix`). | Shimy leží přímo v `bin/npm-global`, takže je najde `Test-Command` i launcher; `bin/npm-global/package.json` už není potřeba. | Hotovo. `launcher/Menu.ps1` přidává do `PATH` obě cesty, takže zůstává zpětně kompatibilní. |
| `scripts/Setup-DeepSeekStack.ps1` | Přidány funkce `Get-ComponentInstallTarget`, `Resolve-ComponentShim`, `Install-NpmComponent`, `Test-ComponentBinary`, `Test-SwitchEnabled` a krok `Verify` po každé instalaci. | Instalace se už nehlásí jako úspěšná jen podle exit kódu npm; ověřuje se, že binárka odpoví na `--version`. | Hotovo. `Verify` běží i při `-SkipInstall`, takže setup funguje jako diagnostika stavu. |
| `scripts/Setup-DeepSeekStack.ps1` | Zadání žádalo `Install-ReasonixBinary` stahující ZIP z GitHub releases. | Nahrazeno npm cestou (viz chyba premisy č. 1). | Uzavřeno rozhodnutím uživatele. Alternativa je zdokumentovaná v `AltSources`. |
| `scripts/Setup-DeepSeekStack.ps1` | Chybějící shim se hlásí jako `FAIL` jen v běhu, který komponentu skutečně instaloval; při `-SkipInstall`/`-WhatIf` jako `WARN`. | Dry-run `-WhatIf -SkipInstall` končí exit 0 místo exit 1; skutečná chyba instalace stále končí `FAIL`. | Hotovo. Odchylka od „FAIL = chybí binárka“ je vědomá: absence v dry-runu není chyba. |
| `scripts/Get-AiStackInfo.ps1`, `scripts/Repair-Repo.ps1` | Zadání říkalo „Zkopíruj přesně verzi z předchozí konverzace“. Ta konverzace není součástí repozitáře. | Skripty byly implementovány podle textové specifikace (FÁZE 2) — nejsou bajtově shodné s neexistujícím originálem. | Nelze doplnit, dokud originály nebudou k dispozici. Funkční rozsah ze specifikace je pokrytý. |
| `scripts/Test-Workspace.ps1` | METAPROMPT specifikoval 8 kontrol. Follow-up jich vyžadoval 10 dalších okruhů. | Skript má nyní **16 kontrol** (14 původních + **integrita `.env`** ve verzi 1.0.2 + **portabilita `Required` komponent** ve verzi 1.0.4): adresáře, soubory, UTF-8 BOM, PSScriptAnalyzer, secrets, Node, git, CRLF, **LF u .md/.json/.toml**, **komentářová nápověda**, **odkazy v README**, **HTML landing page**, **fáze METAPROMPT**, **YAML frontmatter promptů**, **integrita .env**, **Required komponenty v workspace**. | Hotovo. Nové kontroly mají `-Fix` tam, kde je oprava bezpečná (LF koncovky); kontrola 16 hlásí `INFO` pro nepovinné komponenty mimo workspace, takže nezhoršuje stav workspace, který záměrně používá jen `reasonix`. |
| `prompts/*.md` | METAPROMPT YAML frontmatter nevyžadoval. | Přidán frontmatter s `title` a `description` u všech 11 souborů v `prompts/` (včetně `README.md` a šablon). | Hotovo. Umožňuje strojové indexování promptů. |
| `FOLLOWUP-METAPROMPT.md` | Soubor dodaný uživatelem měl CRLF, ale `.gitattributes` i `.editorconfig` vyžadují pro `*.md` LF. | Self-test by hlásil `FAIL` na vlastním vstupním souboru. | Opraveno na LF. Soubor je součástí repozitáře jako záznam zadání, ale **není** v manifestu povinných souborů. |
| `launcher/Launch-*.cmd` | Zadání uvádělo přímé volání `pwsh.exe` s fallbackem přes `errorlevel`. | Soubory testují `where pwsh.exe` a podle toho volí interpret (vylepšená detekce). | Ponecháno — původní session to označila za vylepšení a follow-up to potvrdil. |
| `env/.env` | V repozitáři záměrně chybí. | Setup ho vytvoří ze `env/.env.example` při prvním běhu. | Záměr — v repozitáři nesmí být secrets. Bylo potvrzeno jako správné. |
| `launcher/Menu.ps1` | Menu drží přesně položky z METAPROMPT (Pi v nabídce není), ale `-Action pi` je nově povolený. | Pi je plnohodnotná komponenta katalogu a šla by spustit jen ručně. | Spustit `pwsh -File launcher\Menu.ps1 -Action pi`. Pokud má Pi dostat číslo v menu, je to změna METAPROMPT specifikace — vědomě neprovedeno. |
| `landing/index.html`, `landing/style.css`, `landing/script.js` | Landing page nebyla v předchozí session otevřena v prohlížeči. | Riziko nefunkčního rozcestníku. | Staticky ověřeno (spárované tagy, všech 14 relativních odkazů existuje, logo má vlastní barvu, theme toggle i responzivní layout v pořádku) a stránka otevřena v prohlížeči. Viz `CHANGELOG.md`. **Revize 1.0.3:** počet relativních odkazů je nyní 22 (roste s obsahem stránky); ověřeno, že všechny existují, a verze v patičce srovnána s `VERSION`. |
| `docs/02-CONFIG.md` | Zdroj pravdy o balíčcích neexistoval. | Bez něj by se neověřené názvy vrátily při další úpravě. | Přidána sekce „Ověřené balíčky“ včetně alternativních zdrojů pro Reasonix. |
| `_common.ps1` (manifest) | Manifest neznal nové soubory. | `Test-Workspace.ps1` by `docs/06-DEVIATIONS.md` nevyžadoval. | `docs/06-DEVIATIONS.md` přidán do `Get-WorkspaceManifest`. |
| `_common.ps1` (katalog) | Zadání 1.0.4 chtělo `Category`, `DisplayName` a `AltSources` doplnit přímo do `$ComponentCatalog` v `Setup-DeepSeekStack.ps1`. | Diagnostika i self-test katalog také potřebují; druhá kopie by se rozešla s první. | Katalog je nově funkce `Get-ComponentCatalog` v `_common.ps1` (stejný vzor jako `Get-WorkspaceManifest`) a setup si ji načítá do `$ComponentCatalog` - proměnná tedy dál existuje pod stejným jménem. |
| `_common.ps1` (detekce) | Zadání 1.0.4 chtělo `Test-Component` s pěti režimy (`workspace`, `workspace-local`, `global-npm`, `system`, `none`). | Bez sdílené detekce by každý skript hledal binárky jinak. | Přidány `Test-Component` (vrací `Found`, `Source`, `Path`, `Version`, `Portable`, `MultipleFound`) a `Get-ComponentShimPath`; `Resolve-ComponentShim` v setupu na téhož helpera deleguje. Zásahy se deduplikují podle adresáře, takže tatáž instalace nalezená přes `global-npm` i `system` nehlásí `MultipleFound`. |
| `scripts/Setup-DeepSeekStack.ps1` (Bug #2) | Původní setup přeskočil instalaci, když nástroj našel v globálním `PATH` (`[WARN] nalezeno v PATH mimo workspace - instalace přeskočena`). | Workspace pak fungoval jen díky globálním instalacím a po kopírování na jiný stroj přestal fungovat - přesně to popisuje Bug #2. | Instalace se už nepřeskakuje: vybrané komponenty se vždy instalují do `bin/npm-global`. Vědomá výjimka je `-UseGlobalIfPresent`, které globální instalaci použije a ohlásí `WARN`. |
| `scripts/Setup-DeepSeekStack.ps1` (pi-reasonix) | Zadání předpokládalo, že instalace `pi-reasonix@1.1.0` selhává na peer závislostech. | Reprodukováno v čistém prefixu: příčinou je `postinstall` skript `npm run build \|\| true`, který na Windows selže (`tsc` bez `tsconfig.json` vypíše nápovědu a skončí chybou, `\|\| true` není platný `cmd` příkaz). Balíček přitom už veze hotový `dist/`. | Instalace rozšíření používá `--ignore-scripts --legacy-peer-deps`; `--legacy-peer-deps` navíc brání tomu, aby npm stáhl druhou celou kopii Pi agenta do vnořeného `node_modules`. Detekce „už nainstalováno“ vyžaduje `node_modules/pi-reasonix/package.json`, protože neúspěšná instalace po sobě nechává prázdný skeleton. |
| `scripts/Get-AiStackInfo.ps1` (sekce 7) | Zadání 1.0.4 chtělo u `Required` komponenty `FAIL`, když chybí. | Když je `reasonix` nalezený mimo workspace, není to „chybí“, ale „není přenositelný“. | Nenalezeno = `FAIL`, nalezeno mimo workspace = `WARN` (a v sekci 8 doporučení `WARN`). Tvrdá brána na portabilitu je kontrola 16 v `Test-Workspace.ps1`, která na `reasonix` mimo `bin/npm-global` hlásí `FAIL`. |
| `manual/03-faq.md` (číslování) | FAQ mělo souvislé číslování 1-22. | Nové otázky k 1.0.4 se logicky pojí k otázce 7 (instalace nástrojů). | Vloženy jako `7a` a `7b`, aby se nemusela přečíslovat celá stránka; nová otázka 23 je na konci. |

## Odchylka v commit zprávě

Follow-up zadání předepisovalo doslovné znění commit zprávy, včetně řádku
`Fixed Reasonix installation (GitHub releases, not npm)`. Audit ale prokázal,
že Reasonix na npm **je** a že se — rozhodnutím uživatele — instaluje právě
z npm. Doslovné znění by v historii gitu zanechalo nepravdivý záznam.

Commit proto nese upravenou zprávu: stejný předmět i strukturu odrážek,
ale místo nepravdivého tvrzení vysvětlení, že premisa „Reasonix není na npm“
byla vyvrácena a že `Install-ReasonixBinary` byl z tohoto důvodu vypuštěn.
Jedná se o vědomou odchylku od doslovného znění zadání ve prospěch
pravdivosti auditní stopy.

## Zavádějící zdroj v diagnostice po `.env` seedu do Process scope

**Symptom:** `Get-AiStackInfo` hlásí „aktivní zdroj: User", ale hodnota
reálně pochází z `.env` (protože shell vznikl před nastavením User scope).

**Příčina:** `Import-DotEnv` zapisuje do Process scope, aby potomci
dostali klíč. Snapshot před `Import-DotEnv` tuto skutečnost nezachytí,
protože v té chvíli byl Process scope prázdný.

**Rozhodnutí:** Nechat chování. Oprava by přinesla riziko chybějícího
klíče u potomků v shellech spuštěných před nastavením User scope.

**Workaround pro diagnostiku:** Pokud chceš přesný zdroj, spusť
`Get-AiStackInfo` v novém shellu (po restartu), kde Process scope
obsahuje aktuální hodnotu z User scope.

## Původní skripty — co bylo k dispozici

Zadání (`METAPROMPT.md`, FÁZE 2) u tří skriptů říká „Zkopíruj přesně verzi
z předchozí konverzace“:

- `scripts/Setup-DeepSeekStack.ps1`
- `scripts/Get-AiStackInfo.ps1`
- `scripts/Repair-Repo.ps1`

V repozitáři **nejsou žádné referenční kopie** těchto souborů. `docs/` obsahuje
jen dokumentaci, `gists/` jen jeden krátký fragment PowerShellu
(`gists/0001-env-detection.md`, funkce `Find-DotEnvFile`), který není verzí
žádného z těchto tří skriptů.

Jediné srovnání, které tedy šlo provést:

| Fragment v `gists/0001-env-detection.md` | Implementace ve workspace | Rozdíl |
| --- | --- | --- |
| `Find-DotEnvFile` — najde první existující `.env` (`env/.env`, `.env`, `configs/.env`) | `Import-DotEnv` v `scripts/_common.ps1` — hledá `env/.env` a `.env`, navíc soubor načte do proměnných prostředí a vrátí hashtable | Workspace hledá o `configs/.env` méně (taková složka ve struktuře neexistuje) a přidává načtení hodnot. Funkčně nadmnožina. |

Doporučení: pokud se originální skripty někdy objeví, vložte je do
`docs/reference/` a spusťte srovnání znovu — tento dokument je připravený
na doplnění.
