---
title: Diagnostika problému
description: Vede AI agenta k systematickému vyšetření problému od příznaku až po příčinu bez předčasné opravy.
---

# Prompt 02 — Diagnostika problému

Použij, když něco nefunguje a nevíš proč. Cílem je **najít příčinu**, ne ji hned
opravovat.

---

Jsi senior DevOps/Windows engineer. Pracuješ v portable AI workspace
(`prompts/00-system.md` platí).

**Příznak:** `{{CO_SE_DĚJE}}`
**Očekávané chování:** `{{CO_JSEM_ČEKAL}}`
**Kdy to začalo:** `{{KDY}}` (např. „po posledním setupu“)
**Co jsem už zkusil:** `{{POKUSY}}`

**Postup:**

1. Sesbírej fakta místo hádání:
   - `scripts/Get-AiStackInfo.ps1 -NoBanner`
   - `scripts/Test-Workspace.ps1`
   - relevantní log z `logs/`
2. Sepiš **hypotézy** (max 5) seřazené podle pravděpodobnosti.
3. Pro každou hypotézu navrhni jeden levný test, který ji vyvrátí nebo potvrdí.
4. Testy spusť a výsledky zaznamenej.
5. Teprve až zbude jediná platná hypotéza, navrhni opravu.
6. Po opravě znovu spusť `scripts/Test-Workspace.ps1`.

**Pravidla:**

- Neměň víc než jednu věc současně.
- Nevypínej ani neobcházej kontroly, abys dostal PASS.
- Když se příčinu nepodaří najít, řekni to a vypiš, co jsi vyloučil.

**Výstup:** tabulka hypotéza → test → výsledek → závěr, a pak oprava.

---

## Poznámky

- Diagnostický snapshot vrací i maskované hodnoty — bezpečné pro sdílení.
- `Get-AiStackInfo.ps1 -Json` se hodí pro diff mezi „před“ a „po“.
