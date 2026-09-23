# Revize METAPROMPT.md po realizaci

Tento dokument je revize původního METAPROMPT.md po realizaci.

Původní zadání zůstává v repozitáři jako **historický artefakt**
([`METAPROMPT.md`](../METAPROMPT.md), na začátku označen jako historický).
Tento dokument k němu vede aktuální stopu: co bylo vyvráceno, co platí
a co vzniklo nad rámec plánu.

Zdroj dat pro tabulku premis: [`06-DEVIATIONS.md`](06-DEVIATIONS.md).
Zdroj dat pro aktuální stav: [`VERSION`](../VERSION) a [`CHANGELOG.md`](../CHANGELOG.md).

## Vyvrácené premisy

| Původní premisa | Skutečnost | Dopad |
| --- | --- | --- |
| „Reasonix NENÍ na npm — je to binární distribuce z GitHub releases.“ | `reasonix` na npm **je** (1.38.11, `esengine/DeepSeek-Reasonix`), navíc existuje winget balíček `ESEngine.ReasonixCLI`. | Požadavek na vlastní `Install-ReasonixBinary` se ruší. Reasonix se instaluje z npm do lokálního prefixu `bin/npm-global`, workspace zůstává přenosný. winget a GitHub ZIP zůstávají zdokumentované jako alternativy. |
| „Pi je `@mariozechner/pi-coding-agent`.“ | Název existuje (0.73.1), ale kanonický scope je dnes `@earendil-works/pi-coding-agent` (0.87.1). `pi-reasonix` deklaruje peer závislost **výhradně** na scope `@earendil-works`. | Instalace ze zastaralého scope by rozbila volitelné rozšíření. Katalog používá `@earendil-works/pi-coding-agent`; `@mariozechner/…` v katalogu záměrně není (kolize o binárku `pi`). |
| „`dsh` je balíček DeepSeek Harness.“ | `dsh` na npm je „A shell written in JavaScript“ (`infusion/node-dsh`). Skutečný název je `@deepseek-ai/dsh` (0.1.5-rc.3). | Bez opravy by setup nainstaloval JS shell místo DeepSeek Harness. Katalog i `docs/02-CONFIG.md` používají ověřený název. |
| „`pi-reasonix` je Pi agent.“ | `pi-reasonix` (1.1.0) je **rozšíření** pro Pi, ne agent. Instaluje se jako `Extension`, zapínané `PORTABLEAI_PI_EXTENSIONS=1`. | Pi agent = `@earendil-works/pi-coding-agent`; rozšíření je volitelné a v katalogu vedeno jako `Extension`. |
| „METAPROMPT má 10 fází (FÁZE 1–10).“ | Dokument definuje **FÁZE 0 až FÁZE 10** — tedy 11 fází. Sám o sobě navíc na dvou místech mluví o „8 fázích“ a o „Všech 10 fází“. | Off-by-one v původním zadání. Kontrola v `Test-Workspace.ps1` ověřuje přítomnost FÁZE 0–10, protože jinak by buď ignorovala FÁZI 0, nebo prohlásila hotový dokument za neúplný. Žádný funkční dopad. |
| „Referenční kopie původních skriptů jsou k dispozici.“ | V repozitáři **žádné** referenční kopie nebyly — `docs/` obsahuje jen dokumentaci a `gists/` jediný fragment (`Find-DotEnvFile`). | Srovnání proti originálům nešlo provést; `docs/reference/` nevzniklo. Srovnání je připravené na doplnění v `06-DEVIATIONS.md`. |

## Aktuální fáze

- **Aktuální verze workspace:** [`VERSION`](../VERSION) → `1.0.3`.
- **Historie změn a rozsah jednotlivých verzí:** [`CHANGELOG.md`](../CHANGELOG.md).
- **Původní zadání definovalo** FÁZE 0–10 (recon, scaffold, skripty, README,
  prompty, dokumentace, manuál, launcher, landing page, gisty, verifikace).
- **Realizace proběhla v iteracích** nad tento plán:
  1. `1.0.0` — build podle zadání.
  2. `1.0.1` — verify: ověření npm balíčků proti živému registry, oprava
     katalogu, zavedení kroku `Verify` v setupu.
  3. `1.0.2` — polish: expanze `${VAR}` v `.env`, priorita env vs. `.env`,
     ředění skenovaných cest a nová kontrola 15 „Integrita .env“.
  4. `1.0.3` — docs + self-heal: revize zadání, archiv historie, audit
     `prompts/`, `docs/` a `manual/`, root zástupci, `scripts/SelfHeal.ps1`.
- **Kontrolní mechanismus:** `scripts/Test-Workspace.ps1` (15 kontrol, PASS/FAIL)
  a `scripts/Get-AiStackInfo.ps1` (8 sekcí diagnostiky). Oba sdílejí manifest
  `Get-WorkspaceManifest`, takže se nemohou rozejít.

## Co bylo mimo plán

| Rozšíření rozsahu | Proč vzniklo | Kde je zdokumentované |
| --- | --- | --- |
| Self-test rozšířen z 8 na **14** a posléze **15** kontrol | Zadání specifikovalo 8 kontrol; follow-up vyžadoval 10 dalších okruhů a verze 1.0.2 přidala integritu `.env`. | `CHANGELOG.md` (1.0.1, 1.0.2), `06-DEVIATIONS.md` |
| Instalace Reasonixu z npm místo `Install-ReasonixBinary` | Vyvrácená premisa „Reasonix není na npm“. | `06-DEVIATIONS.md` § 1, `CHANGELOG.md` (1.0.1) |
| Expanze `${VAR}` v `.env` (`Expand-DotEnvValue`, `Get-EnvValueSource`, dvoufázový `Import-DotEnv`) | Původní vzory používaly substituci, kterou `Import-DotEnv` neuměl → Claude Code padal na `401`. | `CHANGELOG.md` (1.0.2), `docs/02-CONFIG.md` |
| Explicitní priorita env (Process/User/Machine) před `.env` | Aby existoval jediný zdroj pravdy pro klíč a setup nepřepisoval hodnoty. | `docs/02-CONFIG.md`, `manual/03-faq.md` |
| `launcher/Menu.ps1 -Action pi` | Pi je plnohodnotná komponenta katalogu, ale nabídka menu měla zůstat dle specifikace. | `06-DEVIATIONS.md`, `CHANGELOG.md` (1.0.1) |
| YAML frontmatter u všech 11 souborů v `prompts/` | Původní zadání frontmatter nevyžadovalo; umožňuje strojové indexování promptů. | `CHANGELOG.md` (1.0.1) |
| Root zástupci (`Start`, `Portal`, `Diag`, `Test`, `Setup`, `Update`) a `scripts/SelfHeal.ps1` | Rychlý přístup a automatická oprava běžných odchylek portable workspace. | `CHANGELOG.md` (1.0.3), [`README.md`](../README.md) |
| `docs/history/` s archivem historických zadání | Root měl obsahovat jen aktuální vstupy, ne dávno hotová zadání. | `CHANGELOG.md` (1.0.3), [`README-HISTORY.md`](../README-HISTORY.md) |
| Audit `prompts/`, `docs/` a `manual/` | Dokumentace a meta-soubory zaostávaly za realitou (verze, počty kontrol, přesunutý soubor). | [`prompts-audit.md`](prompts-audit.md), [`docs-manual-audit.md`](docs-manual-audit.md) |

## Obnovení čitelného markdownu (revize 1.0.3)

`METAPROMPT.md` i `FOLLOWUP-METAPROMPT.md` byly v repozitáři uložené
s **artefakty escapování** vzniklými při kopírování textu: každý markdown
znak měl před sebou zpětné lomítko (`\# ROLE`, `\*\*bold\*\*`), každá
zpětná lomítka v cestách byla zdvojená (`C:\\portableAI\\`) a každý nový
řádek byl zdvojený (odstavce oddělovaly tři prázdné řádky, odsazení se
změnilo na entitu `&#x20;`). Dokumenty se proto renderovaly doslovně jako
`\# ROLE`.

Revize 1.0.3 obsah vrátila do čitelné podoby:

| Artefakt | Obnova |
| --- | --- |
| `\#`, `\*`, `\-`, `\.`, `\[`, `\_`, `\~` a další escapované znaky | odstraněno zpětné lomítko |
| `\\` (zdvojená zpětná lomítka v cestách a regexech) | zpět na jediné `\` |
| zdvojení nových řádků (`\n` → `\n\n`, `\n\n` → `\n\n\n\n`) | půlení běhů nových řádků |
| `&#x20;` (odsazení na začátku řádku) | zpět na mezeru |
| zpětné lomítko před zavíracím `` ` `` inline kódu | zachováno — jde o skutečné cesty `C:\portableAI\` |

**Text se nezměnil** — mění se jen escape artefakty a výsledné formátování.
Ověřeno: soubor začíná `# ROLE`, obsahuje `**bold**`, mezi odstavci je
jeden prázdný řádek, žádné `&#`, koncovky LF.
