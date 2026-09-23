---
title: Prompt library
description: Přehled promptů a šablon ve workspace a návod, jak je kopírovat, referencovat a skládat.
---

# Prompt library

Knihovna znovupoužitelných promptů pro AI agenty pracující v tomto workspace.

## Jak prompty používat

**1. Copy-paste.** Otevřete soubor, zkopírujte obsah a vložte ho agentovi jako
první zprávu. Placeholdery `{{...}}` nahraďte svými údaji.

**2. Reference.** Místo kopírování celého textu stačí agentovi říct:
„Řiď se `prompts/00-system.md` a `prompts/03-coding.md`.“ Agent si soubor přečte.

**3. Kompozice.** System prompt je základ, ostatní prompty se na něj nabalují:

```
00-system.md  →  vždy (pravidla workspace)
   ├── 01-setup.md        inicializace nového projektu
   ├── 02-diagnostics.md  diagnostika problému
   ├── 03-coding.md       implementace featury
   ├── 04-refactor.md     refaktoring bez změny chování
   ├── 05-review.md       code review
   └── 06-debug.md        debugging
```

**4. Šablony.** `templates/*.md` obsahují placeholdery `{{...}}`, které před
použitím vyplníte. Hodí se pro opakující se zadání.

## Přehled

| Soubor | Kdy použít |
| --- | --- |
| [00-system.md](00-system.md) | vždy na začátku session — pravidla a kontext workspace |
| [01-setup.md](01-setup.md) | zakládáte nový projekt ve workspace |
| [02-diagnostics.md](02-diagnostics.md) | něco nefunguje a nevíte proč |
| [03-coding.md](03-coding.md) | máte zadání featury |
| [04-refactor.md](04-refactor.md) | chcete zlepšit strukturu kódu |
| [05-review.md](05-review.md) | chcete zkontrolovat cizí změny |
| [06-debug.md](06-debug.md) | máte konkrétní chybu nebo stack trace |
| [templates/task.md](templates/task.md) | obecné zadání úkolu |
| [templates/bugfix.md](templates/bugfix.md) | hlášení a oprava bugu |
| [templates/feature.md](templates/feature.md) | specifikace featury |

## Zásady

- Prompt je **kontrakt**: čím konkrétnější zadání, tím méně halucinací.
- Vždy uveďte **kritérium hotovo** (test, který musí projít).
- Nikdy nevkládejte secrets do promptu — odkazujte na `env/.env`.
- Pokud agent poruší pravidla ze system promptu, připomeňte je odkazem na
  `prompts/00-system.md`.
