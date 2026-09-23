# Portable AI Workspace

[![CI](https://github.com/martinpaprcka77/portableAI/actions/workflows/ci.yml/badge.svg)](https://github.com/martinpaprcka77/portableAI/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.8-blue.svg)](VERSION)
[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-5391FE.svg?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/platform-Windows%2011-0078D6.svg?logo=windows&logoColor=white)](https://www.microsoft.com/windows/windows-11)
[![DeepSeek](https://img.shields.io/badge/DeepSeek-Ready-4B6BFB.svg)](https://api-docs.deepseek.com/)

> Samostatné AI vývojové prostředí pro Windows 11 — bez admin práv, bez globálních instalací.

## Co to je

Portable AI workspace je jedna složka, kterou zkopírujete na disk nebo USB a máte
v ní pohromadě AI coding agenty (Reasonix, Claude Code, DSH, Pi) s DeepSeek
backendem, jejich konfiguraci, diagnostiku, opravné skripty, knihovnu promptů,
dokumentaci, manuál a rozcestník. Nic se neinstaluje globálně a nic nepotřebuje
administrátorská práva.

## Rychlý start

Nejkratší cesta jsou zástupci v kořeni workspace. Dvojklik i spuštění
z terminálu fungují stejně:

| Zástupce | Co udělá | Volá |
| --- | --- | --- |
| [`Setup.cmd`](Setup.cmd) | nainstaluje a nakonfiguruje AI stack | `scripts/Setup-DeepSeekStack.ps1` |
| [`Start.cmd`](Start.cmd) | otevře interaktivní menu | `launcher/Start-PortableAI.cmd` |
| [`Diag.cmd`](Diag.cmd) | vypíše diagnostický snapshot | `scripts/Get-AiStackInfo.ps1` |
| [`Test.cmd`](Test.cmd) | spustí self-test workspace | `scripts/Test-Workspace.ps1` |
| [`Update.cmd`](Update.cmd) | zkontroluje odchylky a nabídne opravu | `scripts/SelfHeal.ps1` |
| [`Portal.cmd`](Portal.cmd) | otevře landing page v prohlížeči | `landing/index.html` |

Zástupci předávají argumenty dál, takže funguje i `Test.cmd -Fix`,
`Diag.cmd -Json` nebo `Update.cmd -Fix`. Bez argumentů nic nemění —
`Update.cmd` běží v režimu „jen report“.

Klasický postup:

1. Rozbalte ZIP nebo naklonujte repozitář do `C:\portableAI\` (funguje i jiná cesta).
2. Spusťte `Start.cmd` (nebo `launcher\Start-PortableAI.cmd`).
3. V menu zvolte `[1] Setup`, potom `[2] Diagnostics`.
4. Doplňte `DEEPSEEK_API_KEY` do `env\.env` a spusťte `[1] Setup` znovu.

Podrobný pětiminutový průvodce: [`manual/00-quickstart.md`](manual/00-quickstart.md).

## Co obsahuje

| Komponenta | Popis | Cesta |
| --- | --- | --- |
| Zástupci | rychlý přístup k setupu, diagnostice, self-testu a údržbě | `*.cmd` v kořeni |
| Skripty | setup, diagnostika, oprava repa, self-test, self-heal, generátor stromu | `scripts/` |
| Prompty | 7 promptů + 3 šablony pro AI agenty | `prompts/` |
| Dokumentace | architektura, instalace, konfigurace, security, ADR | `docs/` |
| Manuál | quickstart, cheatsheet, workflows, FAQ, glosář | `manual/` |
| Launcher | `.cmd` spouštěče a interaktivní menu | `launcher/` |
| Landing page | statický HTML rozcestník | `landing/index.html` |
| Gisty | snippety, one-linery a konfigurační šablony | `gists/` |
| Konfigurace | vzory `.env`, runtime data, lokální npm prefix | `env/`, `data/`, `bin/` |

## Struktura workspace

Zkrácený přehled; úplný strom včetně každého souboru je v
[`scaffold/directory-tree.txt`](scaffold/directory-tree.txt):

Pro regeneraci stromu: `pwsh -File scripts\Update-Tree.ps1` (report bez
zápisu: `-WhatIf`).

```
portableAI\
├── *.cmd                    root zástupci: Start, Portal, Diag, Test, Setup, Update
├── README.md                vstupní bod
├── README-HISTORY.md        rozcestník historie zadání
├── VERSION / CHANGELOG.md / LICENSE
├── METAPROMPT.md            historické zadání (označeno jako historické)
├── scaffold/                dokumentace struktury + vygenerovaný strom
├── scripts/                 _common.ps1, Setup-*, Get-*, Repair-*, Test-*, SelfHeal.ps1, Update-Tree.ps1
├── prompts/                 knihovna promptů pro AI agenty
├── docs/                    technická dokumentace (včetně adr/ a history/)
├── manual/                  uživatelský manuál
├── launcher/                .cmd spouštěče + Menu.ps1
├── landing/                 statický HTML rozcestník
├── gists/                   snippety a konfigurační šablony
├── env/ logs/ data/ bin/    konfigurace a runtime (negitované)
└── .vscode/                 doporučené nastavení editoru
```

Vrstvy a vlastnictví složek popisuje [`scaffold/01-STRUCTURE.md`](scaffold/01-STRUCTURE.md).

## Požadavky

- Windows 11 (22H2+) nebo Windows 10 jako fallback
- PowerShell 7+ (`pwsh.exe`), funguje i Windows PowerShell 5.1
- Node.js 22.19+ v `PATH`
- Git for Windows
- DeepSeek API klíč

Chybějící závislosti workspace **neinstaluje** — jen je ohlásí jako WARN.

## Instalace

Krok za krokem: [`docs/01-INSTALL.md`](docs/01-INSTALL.md)

## Konfigurace

Konfigurační soubory, proměnné prostředí a priority: [`docs/02-CONFIG.md`](docs/02-CONFIG.md)

## Manuál

- [Quickstart](manual/00-quickstart.md)
- [Cheatsheet](manual/01-cheatsheet.md)
- [Workflows](manual/02-workflows.md)
- [FAQ](manual/03-faq.md)
- [Glosář](manual/04-glossary.md)

## Troubleshooting

Tabulka symptom → příčina → řešení: [`docs/03-TROUBLESHOOTING.md`](docs/03-TROUBLESHOOTING.md)

## Kontrola stavu

```powershell
Test.cmd                                     # = pwsh -File scripts\Test-Workspace.ps1
Diag.cmd                                     # = pwsh -File scripts\Get-AiStackInfo.ps1
Update.cmd                                   # jen report odchylek, nic nemění
Test.cmd -Fix                                # opraví encoding, koncovky, git init
Update.cmd -Fix                              # opraví encoding, koncovky, adresáře, PATH
```

Bez zástupců:

```powershell
pwsh -File scripts\Test-Workspace.ps1        # self-test, PASS/FAIL
pwsh -File scripts\Get-AiStackInfo.ps1       # diagnostický snapshot
pwsh -File scripts\SelfHeal.ps1              # report odchylek (self-heal)
pwsh -File scripts\Update-Tree.ps1           # přegeneruje scaffold\directory-tree.txt
```

V repozitáři běží stejné kontroly i v CI (`.github/workflows/ci.yml`, Windows
runner): `Setup-DeepSeekStack.ps1 -SkipOptional` → `SelfHeal.ps1 -Json` →
`Test-Workspace.ps1`. Detail: [`docs/04-ARCHITECTURE.md`](docs/04-ARCHITECTURE.md).

## Verze

Aktuální verze je v [`VERSION`](VERSION); historie změn je v [`CHANGELOG.md`](CHANGELOG.md).

| Kde hledat | Co tam je |
| --- | --- |
| [`VERSION`](VERSION) | aktuální semver workspace |
| [`CHANGELOG.md`](CHANGELOG.md) | co se změnilo a proč, po verzích |
| [`docs/METAPROMPT-REVISION.md`](docs/METAPROMPT-REVISION.md) | revize původního zadání: vyvrácené premisy a co vzniklo mimo plán |
| [`docs/06-DEVIATIONS.md`](docs/06-DEVIATIONS.md) | detailní auditní stopa odchylek od zadání |
| [`README-HISTORY.md`](README-HISTORY.md) | rozcestník historických zadání |
| [`docs/history/FOLLOWUP-1-METAPROMPT.md`](docs/history/FOLLOWUP-1-METAPROMPT.md) | archivované zadání follow-upu #1 |

## Bezpečnost

Secrets patří výhradně do `env\.env`, který je v `.gitignore`.

- [Security Policy](SECURITY.md) — hlášení zranitelností, co nikdy
  necommitovat, bezpečnostní model
- [Technické detaily bezpečnosti](docs/05-SECURITY.md) — kde bydlí secrets,
  maskování hodnot v lozích, rotace klíčů

## Licence

MIT — viz [`LICENSE`](LICENSE).
