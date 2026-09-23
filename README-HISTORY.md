# Historie zadání

Tento soubor vysvětluje, proč v rootu workspace leží historická zadání
a kde je najít.

## Co je v `docs/history/`

Archiv **zadání, která jsou už hotová**. Leží tam proto, aby zůstala
dohledatelná auditní stopa, ale nemátla jako „aktuální zadání“ v rootu:

| Soubor | Co to je |
| --- | --- |
| [`docs/history/FOLLOWUP-1-METAPROMPT.md`](docs/history/FOLLOWUP-1-METAPROMPT.md) | Zadání follow-upu #1 — ověření npm balíčků, oprava katalogu komponent a doplnění self-testu. Hotovo ve verzích `1.0.1` a `1.0.2`. |

Další follow-up zadání (`FOLLOWUP-2`, `FOLLOWUP-3`) v repozitáři neexistují —
kdyby vznikla, patří do stejného adresáře.

## Co je v rootu

| Soubor | Role |
| --- | --- |
| [`METAPROMPT.md`](METAPROMPT.md) | **Historické** původní zadání workspace. Nahoře je označené jako historické; obsahuje premisy, které realizace vyvrátila. |
| [`README-HISTORY.md`](README-HISTORY.md) | Tento soubor — rozcestník historie. |

## Kde je aktuální stav

Historická zadání **nepopisují současný workspace**. Aktuální stav hledejte v:

- [`VERSION`](VERSION) — aktuální verze workspace.
- [`CHANGELOG.md`](CHANGELOG.md) — co se v které verzi změnilo a proč.
- [`docs/METAPROMPT-REVISION.md`](docs/METAPROMPT-REVISION.md) — revize původního
  zadání: vyvrácené premisy, aktuální fáze a co vzniklo mimo plán.
- [`docs/06-DEVIATIONS.md`](docs/06-DEVIATIONS.md) — detailní auditní stopa odchylek.

## Konvence pro historické soubory

1. Historické zadání se **nepřepisuje** — jen se na začátek přidá poznámka,
   že jde o historický dokument, a odkaz na aktuální stav.
2. Hotové zadání se z rootu **přesune** do `docs/history/` a v rootu zůstane
   jen tento rozcestník.
3. Archiv se nepromazává — slouží k dohledání „proč to tak je“.
