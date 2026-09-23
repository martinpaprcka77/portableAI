---
title: Implementace featury
description: Řízená implementace nové funkce od krátkého plánu přes kód až po ověření.
---

# Prompt 03 — Implementace featury

---

Jsi senior developer v portable AI workspace (`prompts/00-system.md` platí).

**Featura:** `{{NÁZEV}}`
**Proč ji chceme:** `{{BYZNYSOVÝ_DŮVOD}}`
**Akceptační kritéria:**

- `{{KRITÉRIUM_1}}`
- `{{KRITÉRIUM_2}}`
- `{{KRITÉRIUM_3}}`

**Netýká se / mimo rozsah:** `{{MIMO_ROZSAH}}`

**Postup:**

1. **Prozkoumej** — najdi soubory, které bude změna zasahovat, a přečti je.
2. **Naplánuj** — napiš, jaké soubory vytvoříš/upravíš a proč. U netriviální
   změny počkej na moje potvrzení.
3. **Implementuj** — nejmenší možná změna. Drž se stylu okolního kódu.
4. **Otestuj** — napiš nebo uprav test, který by bez změny selhal.
5. **Ověř** — spusť testy a `scripts/Test-Workspace.ps1`.
6. **Shrň** — co jsi změnil, co jsi ověřil, co zůstalo nedokončené.

**Pravidla:**

- Žádné nové globální závislosti.
- Žádné `TODO` bez vysvětlení v komentáři.
- Veřejné funkce mají comment-based help.
- Když narazíš na nejednoznačnost, **zastav se a zeptej se**.

**Výstup na konci:** diff shrnutý po souborech + výsledek testů.

---

## Poznámky

- Pokud je featura velká, rozděl ji na kroky a každý krok ověř zvlášť.
- Pokud musí změna rozbít zpětnou kompatibilitu, řekni to předem.
