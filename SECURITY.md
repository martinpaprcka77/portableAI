# Security Policy

Bezpečnostní politika portable AI workspace. Tento dokument je **high-level
policy** — jak hlásit zranitelnosti, co nikdy necommitovat a jaký je
bezpečnostní model. Technické detaily (kde přesně bydlí secrets, jak se
maskují hodnoty v lozích, jak rotovat klíče) jsou v
[`docs/05-SECURITY.md`](docs/05-SECURITY.md).

## Podporované verze

| Verze | Podporováno |
| --- | --- |
| `1.0.x` | ✅ ano |
| `< 1.0` | ❌ ne |

Opravy zranitelností dostávají jen aktuální `1.0.x`. Aktuální verze je
v [`VERSION`](VERSION), historie změn v [`CHANGELOG.md`](CHANGELOG.md).

## Hlášení zranitelnosti

**Neotvírejte veřejný issue.** Veřejný issue vidí každý, kdo by zranitelnost
mohl zneužít dřív, než bude opravená.

Napište místo toho na:

**martin.paprcka77 [at] gmail [dot] com**

Do emailu uveďte:

1. **Popis** — co je špatně a které části workspace se to týká.
2. **Reprodukce** — konkrétní kroky nebo příkaz, který problém vyvolá.
3. **Dopad** — co může útočník získat, přečíst nebo změnit.
4. **Návrh opravy** — pokud ho máte; není povinný.
5. **Kontakt** — GitHub handle nebo email pro zpětnou vazbu.

**Odpovídáme do 72 hodin** od doručení emailu, včetně potvrzení, že zpráva
dorazila. Pokud do té doby nedostanete odpověď, pošlete ji znovu — filtr
se mohl splést.

Prosíme o **odpovědné zveřejnění**: detaily držte mimo veřejné kanály do
doby, než bude oprava vydaná.

## Co NIKDY necommituj

- **`.env` soubor** — skutečné hodnoty patří jen do `env/.env` (nebo `.env`),
  který je v `.gitignore`. V gitu je pouze vzor `env/.env.example`.
- **API klíče** — `DEEPSEEK_API_KEY` ani klíče jiných poskytovatelů.
- **Session tokeny** — tokeny agentů, přístupové tokeny, `*.pem`, `*.pfx`,
  certifikáty a privátní klíče.
- **Runtime artefakty** — `.reasonix/` (tasky a snapshoty agenta)
  a `session-*.md` v kořeni; jsou to stopy běhů, ne zdrojový kód.
- **Osobní údaje** — logy z `logs/`, exporty diagnostiky s nemaskovanými
  hodnotami, cesty s uživatelským jménem, screenshoty s klíčem.

### Když se to stane omylem

1. **Zneplatněte klíč hned** v konzoli poskytovatele (revokace je důležitější
   než úklid gitu) a vygenerujte nový.
2. Aktualizujte `env/.env` a ověřte, že nic nehlásí chybu:
   `pwsh -File scripts\Get-AiStackInfo.ps1`.
3. **Přepište historii** — smazání souboru v novém commitu nestačí. Použijte
   `git filter-repo` (nebo BFG), nahraďte hodnotu a teprve pak
   `git push --force` na `origin/main`.
4. Ověřte, že je hodnota mimo historii: `git log -p --all | Select-String 'sk-'`.
5. Po force pushi přenastavte lokální klony (`git fetch && git reset --hard origin/main`).

## Bezpečnostní opatření v repu

| Opatření | Kde | Co dělá |
| --- | --- | --- |
| CI kontrola `.env` | `.github/workflows/ci.yml` → `Test-Workspace.ps1` (kontrola „Secrets (.env)“) | ověří, že `env/.env` je ignorovaný a netrackovaný a že `env/.env.example` existuje |
| PSScriptAnalyzer | `SelfHeal.ps1`, `Test-Workspace.ps1` (nad `scripts/` a `launcher/`) | Warning nebo Error v PowerShell skriptu shodí kontrolu |
| `.gitignore` | kořen repozitáře | vyjímá `env/.env`, `.env`, `logs/`, `data/`, `bin/`, `node_modules/`, `.reasonix/`, `session-*.md` |
| GitHub secret scanning | nastavení repozitáře (Settings → Code security) | při zapnutí zachytí klíč už při pushi; doporučujeme zapnout i push protection |

Součástí je i mazání hodnot v logu — každá citlivá hodnota se do logu píše
přes `Get-MaskedValue` (viz [`docs/05-SECURITY.md`](docs/05-SECURITY.md)).

## Bezpečnostní model

- **User-scope, zero-admin.** Workspace nikdy nevyžaduje administrátorská
  práva. Pokud vám nějaký krok admin práva nabízí, něco je špatně.
- **Žádné systémové zápisy.** Vše zůstává ve složce workspace: instalace do
  `bin/npm-global`, konfigurace v `env/`, runtime v `data/` a `logs/`.
  Jediný zásah mimo workspace je záznam `bin/npm-global` do **User** PATH.
- **Žádná elevace.** `launcher/*.cmd` nikdy nevolá `runas` a skripty nic
  neeskalují.
- **Žádná telemetrie.** Workspace sám neposílá žádná data. Síť komunikuje jen
  to, co používáte vy: `npm` při instalaci, AI agenti a DeepSeek API.
- **Lokální konfigurace.** Jediné povolené místo pro skutečný klíč je
  `env/.env` (nebo `.env`) — nikdy `$PROFILE`, `setx`, argumenty příkazové
  řádky ani soubor v gitu.
- **Vědomé spouštění kódu.** `Setup-DeepSeekStack.ps1` volitelné rozšíření
  `pi-reasonix` instaluje s `--ignore-scripts`, takže se z balíčku nespouští
  `postinstall`.

## Bezpečnostní doporučení pro uživatele

1. **Nekommitovat `.env`** — před commitem zkontrolujte `git status` a `git diff --staged`.
2. **Rotovat klíče** — alespoň každých 90 dní, a vždy po použití na cizím stroji.
3. **Silné klíče** — klíč generovaný poskytovatelem, ideálně samostatný pro každý stroj nebo workspace.
4. **Kontrolovat `git status`** — untracked soubory hlásí i `Update.cmd` (self-heal, kontrola „Git status“).
5. **Používat `-WhatIf`** — všechny skripty měnící stav podporují `-WhatIf`; např. `Update.cmd` bez argumentů běží jen jako report.
6. **Aktualizovat pravidelně** — `git pull` (nebo `Update.cmd -Fix`) a po přesunu workspace vždy `Test.cmd`.

## Kontakt

| Účel | Kanál |
| --- | --- |
| Zranitelnosti | martin.paprcka77 [at] gmail [dot] com |
| Obecné dotazy a bugy | [GitHub Issues](https://github.com/martinpaprcka77/portableAI/issues) |
| Nápady a diskuse | [GitHub Discussions](https://github.com/martinpaprcka77/portableAI/discussions) |

---

**Datum poslední revize:** 2026-09-23

<!-- TODO: Nahraď skutečným emailem, nebo použij GitHub
     Security Advisories URL:
     https://github.com/martinpaprcka77/portableAI/security/advisories/new -->
