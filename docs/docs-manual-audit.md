# Audit `docs/` a `manual/`

Revize dokumentace provedená 2026-09-23 pro verzi workspace `1.0.3`.
Cílem bylo ověřit, že dokumentace nelže o verzi, počtech ani o cestách.

**Revidováno:** 8 souborů v `docs/` (7 tématických + 1 ADR) a 5 souborů
v `manual/`.

**Kontrolovaná realita:** `VERSION` = `1.0.2` před touto revizí (po ní `1.0.3`),
`Test-Workspace.ps1` = **15 kontrol**, `Get-AiStackInfo.ps1` = **8 sekcí**,
`scripts/` = 5 skriptů + `_common.ps1`, `launcher/` = `Menu.ps1` + 5 `.cmd`.

## Výsledky

| Soubor | Verze OK | Příkazy OK | Odkazy OK | Poznámky |
| --- | --- | --- | --- | --- |
| `docs/00-OVERVIEW.md` | ano | ano | ano | „`Get-AiStackInfo.ps1` (8 sekcí, `-Json`)“ odpovídá realitě — skript má sekce 1–8. Sedm designových principů odpovídá chování skriptů (`-WhatIf` u všech měnících, read-only diagnostika). Bez změny. |
| `docs/01-INSTALL.md` | ano | ano | ano | Nabídka menu `[1]`–`[9]`/`[0]` je shodná s `Show-PortableAiMenu` v `launcher/Menu.ps1`. `-Fix -WhatIf` u `Test-Workspace.ps1` funguje (`SupportsShouldProcess`). Řetězec `=== CELKOVÝ STAV: … ===` existuje v `Get-AiStackInfo.ps1`. Bez změny. |
| `docs/02-CONFIG.md` | ano | ano | ano | Tabulka „Ověřené balíčky“ odpovídá `$ComponentCatalog` (reasonix 1.38.11, claude-code 2.1.280, `@deepseek-ai/dsh` 0.1.5-rc.3, `@earendil-works/pi-coding-agent` 0.87.1, rozšíření `pi-reasonix` 1.1.0). `PORTABLEAI_PI_EXTENSIONS=1` odpovídá `env/.env.example`. Bez změny. |
| `docs/03-TROUBLESHOOTING.md` | ano | ano | ano | **Opraveno:** řádek 19 citoval `analyzátor: FAIL`, ale kontrola se jmenuje `PSScriptAnalyzer` — citace nesouhlasila se skutečným výstupem. Tabulka má 20 řádků a je v souladu s opravami, které umí `Test-Workspace.ps1 -Fix`. |
| `docs/04-ARCHITECTURE.md` | **ne → opraveno** | ano | ano | „self-test **osmi** oblastí“ bylo zastaralé (skript má 15 kontrol). Sloupec „Mění stav?“ jinak sedí: `Setup`/`Repair` mají `-WhatIf`, `Test-Workspace` mění jen s `-Fix`, `Get-AiStackInfo` je read-only. |
| `docs/05-SECURITY.md` | ano | ano | ano | Tabulka umístění secrets odpovídá `.gitignore` i kontrole 5 („Secrets (.env)“). Maskovací příklady odpovídají `Get-MaskedValue` (12 znaků = hranice). Bez změny. |
| `docs/06-DEVIATIONS.md` | **ne → opraveno** | ano | ano | Dvě zastaralosti: (1) „Skript má nyní **14 kontrol**“ — realita je 15 (chyběla „Integrita .env“ z 1.0.2); (2) u landing page uváděno „14 relativních odkazů“, dnes 22. Obě doplněny tak, aby zůstala auditní stopa i aktuální stav. Ostatní záznamy (vyvrácené premisy, tabulka balíčků) odpovídají kódu. |
| `docs/adr/0001-record-architecture-decisions.md` | ano | ano | ano | Šablona ADR a pravidla nemluví o konkrétní verzi ani počtu kontrol. Bez změny. |
| `manual/00-quickstart.md` | ano | ano | ano | Nabídka menu shodná s `Menu.ps1`; `Setup-DeepSeekStack.ps1 -WhatIf` funguje; `GetEnvironmentVariable(..., "User")` je platný příkaz; `=== WORKSPACE TEST: PASS ===` odpovídá skutečnému výstupu. Bez změny. |
| `manual/01-cheatsheet.md` | **ne → opraveno** | **ne → opraveno** | ano | „**8 kontrol**, PASS/FAIL“ bylo nejzastaralejší místo v dokumentaci (skript má 15). Opraveno na „15 kontrol“. Ostatní příkazy i přepínače (`-NoBanner`, `-NoColor`, `-Json`, `-SkipInstall`, `-SkipLineEndings`, `-SkipUntrack`) existují. |
| `manual/02-workflows.md` | ano | ano | ano | „Před verzí 1.0.0 (bez gitu)“ je podmíněný historický postup, nikoli tvrzení o aktuální verzi — ponecháno. Všechny příkazy (`Compare-Object`, `git pull --ff-only`, `Test-Workspace.ps1 -Fix`) jsou platné. |
| `manual/03-faq.md` | ano | ano | ano | Odkazy na sekce „6. API“ a „7. AI nástroje“ odpovídají skutečným názvům sekcí v `Get-AiStackInfo.ps1`. Citovaná hláška `DEEPSEEK_API_KEY nalezen v prostředí` existuje v `Setup-DeepSeekStack.ps1`. Bez změny. |
| `manual/04-glossary.md` | ano | ano | ano | Termíny (`DSH`, `REASONIX_REASONING_EFFORT`, `npm prefix`, `UTF-8 BOM`, `WhatIf`) odpovídají konfiguraci i skriptům. Bez změny. |

## Souhrn oprav

| Soubor | Co bylo zastaralé | Oprava |
| --- | --- | --- |
| `manual/01-cheatsheet.md` | „8 kontrol“ | „15 kontrol“ |
| `docs/04-ARCHITECTURE.md` | „self-test osmi oblastí“ | „self-test patnácti oblastí“ |
| `docs/06-DEVIATIONS.md` | „nyní 14 kontrol“ | „15 kontrol“ + doplněna „integrita `.env`“ |
| `docs/06-DEVIATIONS.md` | „všech 14 relativních odkazů“ (landing) | doplněna revizní poznámka: 22 odkazů, všechny existují |
| `docs/03-TROUBLESHOOTING.md` | citace `analyzátor: FAIL` | `PSScriptAnalyzer: … FAIL` |
| `landing/index.html` | `v1.0.1` (2×) | `v1.0.3` (sladěno s `VERSION`) |

## Komentáře ve skriptech

Zadání zakazuje měnit **funkční** kód ve `scripts/` — povolena je pouze
údržba dokumentace uvnitř komentářů. V comment-based helpu se našly dvě
zastaralosti; obě jsou opravené **jen v komentáři**, logika, parametry
ani návratové hodnoty se nemění (diff: 3 vložené, 2 odebrané řádky, vše
uvnitř bloku komentářové nápovědy):

| Soubor | Zastaralý komentář | Oprava |
| --- | --- | --- |
| `scripts/Test-Workspace.ps1` | „Ověří **čtrnáct** oblastí“ a výčet 14 kontrol | „Ověří **patnáct** oblastí“ + doplněna položka 15 (`DEEPSEEK_API_KEY` je konzistentní mezi prostředím a `.env`) |
| `scripts/Setup-DeepSeekStack.ps1` | „Postupuje ve **čtyřech** krocích“ (skript přitom loguje `Krok N/5`) | „Postupuje v **pěti** krocích“ |

Ověřeno po zápisu: oba soubory mají nadále UTF-8 **BOM** i **CRLF**
(0 osamocených LF) a procházejí `Invoke-ScriptAnalyzer -Severity Warning, Error`.

Prošel jsem i comment-based help ostatních skriptů:

- `scripts/Get-AiStackInfo.ps1` — „Projde **osm** sekcí“ a `Sekce N/8`:
  v pořádku, sekcí je skutečně 8.
- `scripts/_common.ps1`, `scripts/Repair-Repo.ps1`, `launcher/Menu.ps1` —
  bez počtů, bez verzí, bez odkazů na neexistující soubory.

## Známé zbytkové nepřesnosti

1. **`METAPROMPT.md` je historický dokument** a záměrně obsahuje vlastní
   vnitřní rozpory („Postupuj v 8 fázích“ vs. FÁZE 0–10). Neopravuje se;
   vysvětlení je v [`METAPROMPT-REVISION.md`](METAPROMPT-REVISION.md).
2. **`docs/06-DEVIATIONS.md` je auditní stopa** — historické údaje
   (např. „14 odkazů na landing page“) se přepisují jen s poznámkou,
   aby zůstalo dohledatelné, co platilo kdy.
3. **`scaffold/directory-tree.txt`** je generovaný artefakt; po této revizi
   byl aktualizován (přesun `FOLLOWUP-METAPROMPT.md`, nové soubory).
4. **`docs/history/`** je archiv hotových zadání, nikoli součást manifestu
   `Get-WorkspaceManifest` — záměrně, aby self-test nevyžadoval soubor,
   který se může v budoucnu archivovat jinam.
