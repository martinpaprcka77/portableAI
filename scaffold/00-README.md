# scaffold/

Tato složka popisuje **strukturu** portable AI workspace. Není to kód — je to
kontrakt: co kde bydlí, proč, a co se nesmí přesunout.

| Soubor | Význam |
| --- | --- |
| `00-README.md` | tento soubor — konvence a pravidla |
| `01-STRUCTURE.md` | detailní popis každé složky |
| `directory-tree.txt` | vygenerovaný strom, který odpovídá realitě na disku |

## Rychlé konvence

1. **Vše relativně k rootu workspace** — nikdy hardcoded `C:\portableAI\`.
2. **`.ps1` = UTF-8 with BOM + CRLF**, ostatní texty **UTF-8 no BOM + LF**.
3. **Secrets patří do `.env`** (gitignored), do repa jde pouze `.env.example`.
4. **Runtime data** (`logs/`, `data/`, `bin/`) nejsou verzovaná — jen `.gitkeep`.
5. Po každé změně struktury přegeneruj `directory-tree.txt`
   (`pwsh -File scripts\Update-Tree.ps1` - když se nic nezmění, nezapíše
   nic) a spusť `scripts/Test-Workspace.ps1`.
