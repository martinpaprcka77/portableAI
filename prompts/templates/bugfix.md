---
title: Šablona opravy chyby
description: Šablona zadání pro hlášenou chybu včetně příznaku, očekávaného chování a způsobu ověření.
---

# Šablona — bugfix

> Nahraďte všechny `{{...}}` a teprve pak pošlete agentovi.

---

## Příznak

`{{CO_SE_DĚJE}}`

## Očekávané chování

`{{CO_MÁ_DĚLAT}}`

## Reprodukce

```powershell
{{MINIMÁLNÍ_REPRODUKČNÍ_PŘÍKAZ}}
```

## Chybový výstup

```
{{CHYBOVÁ_ZPRÁVA}}
```

## Prostředí

| Co | Hodnota |
| --- | --- |
| PowerShell | `{{PS_VERZE}}` |
| Node | `{{NODE_VERZE}}` |
| Windows | `{{WIN_VERZE}}` |
| Naposledy funkční | `{{POSLEDNÍ_FUNKČNÍ_STAV}}` |

## Rozsah opravy

- Smí se měnit: `{{POVOLENÉ_SOUBORY}}`
- Nesmí se měnit: `{{ZAKÁZANÉ_SOUBORY}}`

## Definice hotovo

- [ ] Reprodukce už chybu nevyvolá.
- [ ] Existuje test, který bez opravy selže.
- [ ] `scripts/Test-Workspace.ps1` vrací PASS.
- [ ] Příčina je vysvětlená v jedné větě.
