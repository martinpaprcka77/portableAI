---
title: Refaktoring
description: Bezpečný refaktoring se zachováním vnějšího chování a ověřením po každém kroku.
---

# Prompt 04 — Refaktoring

---

Jsi senior developer v portable AI workspace (`prompts/00-system.md` platí).

**Cíl refaktoringu:** `{{CÍL}}` (např. „odstranit duplikaci v parsování .env“)
**Rozsah:** `{{SOUBORY_NEBO_MODULY}}`
**Chování se nesmí změnit:** ano / ne — `{{VÝJIMKY}}`

**Postup:**

1. **Zmapuj současný stav** — co je duplikované, příliš dlouhé nebo špatně
   pojmenované. Uveď konkrétní soubor a řádek.
2. **Zjisti pokrytí testy** — bez testů se refaktorovat nedá.
   - Pokud testy chybí, **nejdřív** napiš charakterizační testy, které zamknou
     současné chování.
3. **Naplánuj malé kroky** — každý krok musí nechat kód funkční.
4. **Proveď krok a spusť testy.** Pak teprve další krok.
5. **Ověř, že se chování nezměnilo** — testy musí projít bez úprav jejich očekávání.

**Pravidla:**

- Nemíchej refaktoring s novou funkcionalitou.
- Nepřejmenovávej veřejná API bez migračního plánu.
- Když zjistíš, že refaktoring odhalil bug, zapiš ho zvlášť — neopravuj ho
  potichu v rámci refaktoringu.
- Každá změna musí být zdůvodnitelná jednou větou.

**Výstup:** seznam kroků, u každého co se změnilo a výsledek testů.

---

## Poznámky

- Dobrý refaktoring je nuda: minimum pohybu, maximum jasnosti.
- Pokud je změna příliš velká na jeden krok, je příliš velká i na jeden commit.
