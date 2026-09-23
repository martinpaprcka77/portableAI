# 04 — Glosář

## AI a agenti

**Agent** — program, který dostane cíl a sám rozhoduje, jaké kroky podnikne
(čte soubory, spouští příkazy, píše kód). Na rozdíl od chatbota pracuje
s nástroji a mění stav.

**Agentic coding** — styl práce, kdy agent samostatně prochází cyklem
prozkoumej → naplánuj → implementuj → ověř. Člověk zadává cíl a kontroluje
výsledek.

**Harness** — vrstva, která obaluje model a poskytuje mu nástroje, kontext a
řízení toku (DSH = DeepSeek Harness). Model sám o sobě nástroje nemá.

**Halucinace** — výstup modelu, který je plynulý a sebevědomý, ale věcně
nesprávný. Mírní se konkrétním zadáním a ověřováním proti realitě.

**Kontext** — vše, co model v daném okamžiku „vidí“ (systémový prompt,
historie, obsah souborů). Kontextové okno je omezené, proto se používá
komprese a sumarizace.

**Prompt** — zadání pro model. V tomto workspace je prompt **kontrakt**:
obsahuje kontext, postup a kritérium hotovo.

**System prompt** — úvodní, trvale platné zadání, které definuje roli a
pravidla. V workspace je to `prompts/00-system.md`.

**Tool use / function calling** — schopnost modelu vyžádat si spuštění
nástroje (čtení souboru, shell příkaz) místo aby si výsledek vymyslel.

## Modely a inference

**MoE (Mixture of Experts)** — architektura, kde se pro každý token aktivuje
jen část parametrů (experti). Umožňuje velký model s nižšími náklady na
výpočet.

**Reasoning effort** — míra, jak dlouho má model „přemýšlet“ před odpovědí.
Vyšší úsilí znamená lepší výsledky u složitých úloh a vyšší cenu.
V konfiguraci Reasonixu `default_effort` (případně `/effort` v relaci).

**Chain-of-thought (CoT)** — explicitní kroky uvažování, které model generuje
před odpovědí. Zlepšuje přesnost u vícekrokových úloh.

**Token** — základní jednotka textu pro model (přibližně část slova). Cena a
limity se počítají v tokenech.

**Reasoner model** — model optimalizovaný pro uvažování (`deepseek-v4-pro`)
na rozdíl od obecného a levnějšího modelu (`deepseek-flash`).

## Protokoly a konfigurace

**MCP (Model Context Protocol)** — standard pro připojení externích nástrojů a
datových zdrojů k AI agentům. Server poskytuje schopnosti, klient (agent) je
volá.

**OpenAI-kompatibilní API** — rozhraní `/v1/chat/completions`, které používá
mnoho poskytovatelů. DeepSeek ho implementuje, proto s ním fungují nástroje
napsané pro OpenAI.

**`.env`** — textový soubor s proměnnými prostředí ve tvaru `KEY=hodnota`.
V tomto workspace je jediným povoleným místem pro secrets.

**npm prefix** — adresář, do kterého se instalují balíčky (`--prefix`). Používá
se pro **lokální** instalaci bez admin práv a bez globálního zápisu.

**UTF-8 BOM** — tři bajty (EF BB BF) na začátku souboru, které říkají „toto je
UTF-8“. PowerShell bez nich rozbije diakritiku.

**CRLF / LF** — konce řádků. Windows shell potřebuje CRLF (`\r\n`), git a
Markdown chtějí LF (`\n`). Workspace to řeší přes `.gitattributes`.

**Idempotence** — vlastnost operace, která při opakovaném spuštění nezmění
výsledek. Základní požadavek na všechny skripty workspace.

## Praxe a dokumentace

**ADR (Architecture Decision Record)** — krátký neměnný záznam o tom, jaké
rozhodnutí bylo přijato, v jakém kontextu a s jakými důsledky. V `docs/adr/`.

**Portable (přenositelný)** — funguje z libovolné cesty a po zkopírování, bez
instalace a bez zápisu mimo vlastní složku.

**Self-documenting** — kód, který nese svou dokumentaci (comment-based help,
`.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`).

**Self-test** — skript, který ověří, že prostředí odpovídá očekávání
(`scripts/Test-Workspace.ps1`).

**Snippet** — krátký znovupoužitelný kus kódu nebo konfigurace. V `gists/`.

**Scaffold** — kostra struktury projektu nebo workspace. V `scaffold/`.

**WhatIf** — režim, kdy skript nic nezmění a jen vypíše, co by udělal.

**Globální instalace** — instalace do systémových cest, obvykle vyžaduje admin
práva a rozbije se při reinstalaci OS. Workspace ji nepoužívá.
