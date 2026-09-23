# 00 — Přehled

## Co workspace je

Portable AI workspace je **jedna přenositelná složka**, která obsahuje všechno
potřebné k práci s AI coding agenty na Windows: samotné agenty s DeepSeek
backendem, jejich konfiguraci, automatizaci, diagnostiku, dokumentaci a
rozcestník.

Nejsou to „nainstalované programy“. Je to **prostředí**: struktura, konvence,
skripty a konfigurace, které drží AI nástroje pohromadě a reprodukovatelně.

## Proč existuje

Běžný stav na vývojářském Windows je tento:

- AI agenti jsou nainstalovaní globálně (`npm install -g`), takže se verze
  rozcházejí mezi stroji a reinstalace Windows je zničí.
- API klíče leakují do shell profilů, do historie a občas i do gitu.
- Konfigurace je rozesetá po `%APPDATA%`, `%USERPROFILE%` a projektových
  složkách, takže „funguje to jen mně“.
- Neexistuje způsob, jak rychle zjistit, co je vlastně špatně.

Workspace tato čtyři místa řeší tím, že **vše drží v jedné složce s relativními
cestami** a přidává nástroje, které stav kdykoli ověří.

## Jaké problémy řeší

| Problém | Řešení ve workspace |
| --- | --- |
| Globální instalace a verze | lokální npm prefix v `bin/npm-global`; globální instalace se za přenositelnou nepovažuje |
| Secrets v repu a shellu | `env/.env` v `.gitignore`, maskované výpisy |
| „Nevím, co je špatně“ | `scripts/Get-AiStackInfo.ps1` (8 sekcí, `-Json`) |
| „Rozbilo se to“ | `scripts/Repair-Repo.ps1` a `Test-Workspace.ps1 -Fix` |
| Rozcházející se řádkové koncovky | `.gitattributes` + renormalizace |
| Nejasná priorita nástrojů | kategorie komponent (`Required`/`Recommended`/`Optional`) v `Get-ComponentCatalog` |
| Duplikované zadávání agentům | knihovna promptů v `prompts/` |
| Ztráta know-how | `docs/`, `manual/`, `gists/`, ADR |

## Designové principy

1. **Žádná elevace.** Nic nepotřebuje administrátorská práva.
2. **Žádná globální instalace.** Vše žije v `bin/` a `data/`.
3. **Relativní cesty.** `$PSScriptRoot` místo `C:\portableAI\`.
4. **Idempotence.** Každý skript lze spustit opakovaně.
5. **Read-only diagnostika.** Kontrolní skripty nic nemění.
6. **Náhled před změnou.** `-WhatIf` u všeho, co mění stav.
7. **Jediný zdroj pravdy.** `Get-WorkspaceManifest` definuje, co má existovat.

## Co workspace není

- Není to instalátor — chybějící závislosti (Node, Git) jen ohlásí.
- Není to kontejner ani VM — běží přímo na hostitelském Windows.
- Není to náhrada za git ani za správu secrets (Vault, 1Password).
- Není to build systém — je to prostředí a jeho údržba.

## Další kroky

- Instalace: [01-INSTALL.md](01-INSTALL.md)
- Konfigurace: [02-CONFIG.md](02-CONFIG.md)
- Architektura: [04-ARCHITECTURE.md](04-ARCHITECTURE.md)
- Bezpečnost: [05-SECURITY.md](05-SECURITY.md)
