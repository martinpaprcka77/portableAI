# 0001 — Zaznamenávání architektonických rozhodnutí

- **Status:** Accepted
- **Datum:** 2026-09-23
- **Autor:** Portable AI Workspace contributors

## Kontext

Portable AI workspace je určen k tomu, aby ho šlo zkopírovat na jiný disk nebo
USB a aby fungoval bez instalace. Během návrhu vzniklo několik rozhodnutí, která
nejdou snadno odvodit z kódu: proč žádná globální instalace, proč právě takové
řádkové koncovky, proč vlastní logování místo `Write-Host`.

Bez záznamu se tato rozhodnutí budou při každé další úpravě znovu rozporovat.

## Rozhodnutí

Zavádíme **Architecture Decision Records** ve formátu popsaném níže. Každé
významné rozhodnutí dostane vlastní soubor `docs/adr/NNNN-nazev.md`.

Pravidla:

1. ADR je **neměnný záznam v čase** — existující ADR se nepřepisuje, jen
   doplní status (`Superseded by NNNN`).
2. Číslování je sekvenční a mezerami se neplýtvá (`0001`, `0002`, …).
3. Název souboru je krátký, malými písmeny, bez diakritiky.
4. ADR se píše, když se rozhodnutí týká **dvou a více komponent** nebo když by
   jeho změna rozbila přenositelnost.
5. Drobná rozhodnutí patří do komentáře v kódu, ne do ADR.

## Šablona

```markdown
# NNNN — Krátký název rozhodnutí

- **Status:** Proposed | Accepted | Deprecated | Superseded by NNNN
- **Datum:** YYYY-MM-DD
- **Autor:** jméno nebo role

## Kontext

Jaká situace si žádá rozhodnutí? Jaká omezení platí?

## Rozhodnutí

Co jsme se rozhodli udělat. Formulujte to jako fakt, ne jako úvahu.

## Důsledky

Co je díky tomu jednodušší, co složitější, co se tím znemožnilo.

## Alternativy

Co jsme zvažovali a proč to nebylo zvoleno.
```

## Důsledky

**Jednodušší:** nový přispěvatel zjistí „proč“ bez čtení celé historie.

**Složitější:** každé větší rozhodnutí znamená napsat jeden krátký soubor navíc.

**Riziko:** ADR se mohou rozejít s realitou. Mírníme to pravidlem, že při
změně rozhodnutí se zakládá nové ADR s odkazem na předchozí, nikdy se needituje
staré.

## Alternativy

- **Komentáře v kódu.** Zamítnuto — rozhodnutí přesahují jeden soubor a v kódu
  se ztrácejí.
- **Wiki nebo externí dokument.** Zamítnuto — workspace má být soběstačný i bez
  připojení a bez přístupu k externímu systému.
- **Jen commit messages.** Zamítnuto — historie se při migraci repozitáře často
  ztratí, ADR zůstává součástí složky.
