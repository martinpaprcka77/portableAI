# Audit `prompts/`

Revize knihovny promptů provedená 2026-09-23 pro verzi workspace `1.0.3`.
Cílem bylo ověřit, že prompty odpovídají aktuálnímu kódu a struktuře.

**Revidováno:** 11 souborů — 7 promptů (`00-system.md` … `06-debug.md`),
`README.md` a 3 šablony v `templates/`.

**Metodika:** YAML frontmatter ověřen ručně i kontrolou 14 v
`scripts/Test-Workspace.ps1`; u každé zmíněné cesty a každého příkazu
v promptu se ověřovalo, že cíl existuje a že parametr/volba skutečně
existují v odpovídajícím skriptu.

## Výsledky

| Soubor | Frontmatter OK | Příklady OK | Poznámky |
| --- | --- | --- | --- |
| `00-system.md` | ano | ano | **Opraveno:** sekce „Dostupné nástroje“ vyjmenovávala všechny čtyři agenty bez rozlišení. Doplněno, že nástroje patří do `bin/npm-global`, že `reasonix` je primární a ostatní volitelné, a že volitelné rozšíření `pi-reasonix` zapíná `PORTABLEAI_PI_EXTENSIONS=1`. Vyřazené komponenty prompt nezmiňoval. Strom struktury odpovídá realitě. |
| `01-setup.md` | ano | ano | Odkazy `scaffold/01-STRUCTURE.md`, `data/<projekt>/`, `.vscode/tasks.json` a `scripts/Test-Workspace.ps1` míří na existující cíle. Příkaz `npm install --prefix …` odpovídá zásadě „nic globálně“. |
| `02-diagnostics.md` | ano | ano | `scripts/Get-AiStackInfo.ps1 -NoBanner` i `-Json` jsou skutečné parametry skriptu. Odkaz na `logs/` platí (adresář existuje). |
| `03-coding.md` | ano | ano | Bez konkrétních cest; `scripts/Test-Workspace.ps1` v kroku 5 existuje. Pravidla odpovídají `docs/04-ARCHITECTURE.md` (comment-based help, žádné globální závislosti). |
| `04-refactor.md` | ano | ano | Bez cest a příkazů — pouze postup a pravidla. Žádná zastaralá zmínka. |
| `05-review.md` | ano | ano | Zmiňuje `Invoke-ScriptAnalyzer` a kontrolu BOM; obojí je skutečná kontrola workspace (kontroly 3 a 4 v `Test-Workspace.ps1`). |
| `06-debug.md` | ano | ano | Příkazy `Set-PSDebug -Trace 1`, `-Verbose` a `Get-Error` jsou platné; `node --trace-uncaught` a `NODE_OPTIONS=--enable-source-maps` jsou platné přepínače Node. |
| `README.md` | ano | ano | **Doplněno:** sekce „Verze a kompatibilita“ s datem poslední revize, počtem souborů a odkazem na tento audit. Tabulka přehledu odkazuje na všech 10 ostatních souborů — ověřeno, že všechny existují. |
| `templates/task.md` | ano | ano | Placeholdery `{{…}}` konzistentní s ostatními šablonami; bez cest. |
| `templates/bugfix.md` | ano | ano | „Definice hotovo“ odkazuje na `scripts/Test-Workspace.ps1` — existuje. |
| `templates/feature.md` | ano | ano | „Definice hotovo“ odkazuje na `scripts/Test-Workspace.ps1` — existuje. |

## Souhrn

- **Frontmatter:** 11/11 v pořádku (`title` i `description`, platný blok `---`).
- **Příklady a cesty:** 11/11 v pořádku po ověření cílů a parametrů.
- **Vyřazené komponenty:** 0 výskytů. Žádný prompt netvrdí, že by `dsh`
  (nebo jiná komponenta) byl povinný; `00-system.md` byl nicméně doplněn,
  aby rozlišení primární/volitelné bylo explicitní.
- **Změněné soubory:** `prompts/00-system.md`, `prompts/README.md`.

## Poznámka k údržbě

Frontmatter promptů ověřuje kontrola 14 v `scripts/Test-Workspace.ps1`, takže
chybějící `title`/`description` odhalí self-test. Ověření *obsahu* a *cest*
v promptech je ale ruční záležitost — při přidání nového promptu nebo změně
struktury workspace aktualizujte tento dokument.
