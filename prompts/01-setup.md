---
title: Setup nového projektu
description: Založí nový projekt ve workspace včetně kostry, izolovaných závislostí a ověření self-testem.
---

# Prompt 01 — Setup nového projektu

Použij tento prompt, když chceš ve workspace založit nový projekt.

---

Jsi senior developer v portable AI workspace (`prompts/00-system.md` platí).

**Úkol:** Založ ve workspace nový projekt `{{NÁZEV_PROJEKTU}}`.

**Kontext:**

- Typ projektu: `{{TYP}}` (např. Node CLI, PowerShell modul, statický web)
- Cíl projektu v jedné větě: `{{CÍL}}`
- Omezení: `{{OMEZENÍ}}` (např. žádné externí závislosti)

**Postup, který očekávám:**

1. Projdi `scaffold/01-STRUCTURE.md`, ať víš, kam projekt patří.
2. Navrhni umístění (např. `data/{{NÁZEV_PROJEKTU}}/`) a zdůvodni ho.
3. Vytvoř minimální kostru: vstupní bod, `README.md` projektu, `.gitignore`.
4. Pokud projekt potřebuje závislosti, nainstaluj je **lokálně**
   (`npm install --prefix data/{{NÁZEV_PROJEKTU}}`), nikdy globálně.
5. Přidej task do `.vscode/tasks.json`, pokud dává smysl.
6. Ověř, že `scripts/Test-Workspace.ps1` stále vrací PASS.

**Kritérium hotovo:** kostra existuje, projekt se dá spustit jedním příkazem,
self-test workspace je PASS.

Než začneš psát kód, napiš mi plán ve třech odrážkách a počkej na potvrzení.

---

## Poznámky

- Prompt drží projekt uvnitř workspace, aby zůstal přenositelný.
- Pokud projekt potřebuje vlastní `node_modules`, patří do `data/<projekt>/`,
  ne do kořene workspace.
