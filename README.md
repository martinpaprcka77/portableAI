# Portable AI Workspace

> Samostatné AI vývojové prostředí pro Windows 11 — bez admin práv, bez globálních instalací.

![Windows](https://img.shields.io/badge/Windows-11-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue)
![Node](https://img.shields.io/badge/Node-22.19%2B-green)
![License](https://img.shields.io/badge/License-MIT-green)

## Co to je

Portable AI workspace je jedna složka, kterou zkopírujete na disk nebo USB a máte
v ní pohromadě AI coding agenty (Reasonix, Claude Code, DSH, Pi) s DeepSeek
backendem, jejich konfiguraci, diagnostiku, opravné skripty, knihovnu promptů,
dokumentaci, manuál a rozcestník. Nic se neinstaluje globálně a nic nepotřebuje
administrátorská práva.

## Quick start

1. Rozbalte ZIP nebo naklonujte repozitář do `C:\portableAI\` (funguje i jiná cesta).
2. Spusťte `launcher\Start-PortableAI.cmd`.
3. V menu zvolte `[1] Setup`, potom `[2] Diagnostics`.
4. Doplňte `DEEPSEEK_API_KEY` do `env\.env` a spusťte `[1] Setup` znovu.

Podrobný pětiminutový průvodce: [`manual/00-quickstart.md`](manual/00-quickstart.md).

## Co obsahuje

| Komponenta | Popis | Cesta |
| --- | --- | --- |
| Skripty | setup, diagnostika, oprava repa, self-test | `scripts/` |
| Prompty | 7 promptů + 3 šablony pro AI agenty | `prompts/` |
| Dokumentace | architektura, instalace, konfigurace, security, ADR | `docs/` |
| Manuál | quickstart, cheatsheet, workflows, FAQ, glosář | `manual/` |
| Launcher | `.cmd` spouštěče a interaktivní menu | `launcher/` |
| Landing page | statický HTML rozcestník | `landing/index.html` |
| Gisty | snippety, one-linery a konfigurační šablony | `gists/` |
| Konfigurace | vzory `.env`, runtime data, lokální npm prefix | `env/`, `data/`, `bin/` |

## Struktura

Vygenerovaný strom, který odpovídá realitě na disku:
[`scaffold/directory-tree.txt`](scaffold/directory-tree.txt).
Popis vrstev a vlastnictví složek: [`scaffold/01-STRUCTURE.md`](scaffold/01-STRUCTURE.md).

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
pwsh -File scripts\Test-Workspace.ps1        # self-test, PASS/FAIL
pwsh -File scripts\Get-AiStackInfo.ps1       # diagnostický snapshot
pwsh -File scripts\Test-Workspace.ps1 -Fix   # opraví encoding, koncovky, git init
```

## Bezpečnost

Secrets patří výhradně do `env\.env`, který je v `.gitignore`. Podrobnosti:
[`docs/05-SECURITY.md`](docs/05-SECURITY.md).

## Licence

MIT — viz [`LICENSE`](LICENSE). Historie změn: [`CHANGELOG.md`](CHANGELOG.md).
