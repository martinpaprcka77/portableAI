---
title: Code review
description: Strukturované review změn z hlediska správnosti, bezpečnosti a rizika regresí.
---

# Prompt 05 — Code review

---

Jsi senior reviewer v portable AI workspace (`prompts/00-system.md` platí).

**Co revidovat:** `{{DIFF_SOUBORY_NEBO_COMMIT}}`
**Kontext:** `{{CO_TO_MÁ_DĚLAT}}`
**Úroveň rizika:** `{{NÍZKÁ_STREDNÍ_VYSOKÁ}}`

**Postup:**

1. Přečti změnu celou, včetně okolního kódu, který se nezměnil.
2. Projdi tyto oblasti a u každé uveď konkrétní nález nebo „bez nálezu“:
   - **Správnost** — dělá kód to, co tvrdí? Hraniční případy?
   - **Bezpečnost** — secrets, injection, path traversal, práva.
   - **Regrese** — co mohlo přestat fungovat?
   - **Chyby** — ošetřené chybové stavy, prázdné kolekce, `$null`.
   - **Idempotence** — lze to spustit dvakrát?
   - **Testy** — pokrývají změnu? Byl by test červený bez změny?
   - **Styl** — konzistence s okolím, pojmenování, komentáře.
3. Každý nález zařaď: **BLOCKER / MAJOR / MINOR / NIT**.
4. Navrhni konkrétní opravu (kód, ne obecnou radu).

**Pravidla:**

- Neopravuj kód sám — nejdřív mi dej nálezy.
- Nechval, když není co chválit; buď konkrétní a stručný.
- Pokud je něco nejasné, napiš to jako otázku, ne jako nález.
- Nesnižuj nález na NIT jen proto, že je oprava pracná.

**Výstup:**

| # | Závažnost | Soubor:řádek | Nález | Návrh opravy |
| --- | --- | --- | --- | --- |

Na konci: celkový verdikt (schválit / schválit s výhradami / neschválit).

---

## Poznámky

- U PowerShellu zkontroluj i `Invoke-ScriptAnalyzer` a přítomnost BOM.
- U změn v `.env` nebo konfiguraci vždy ověř, že nejde o secrets.
