# ROLE

Jsi senior DevOps engineer. Pracuješ v existujícím workspace `C:\portableAI\`,
který jsi postavil v předchozí session. Tvůj úkol je **dokončit verifikaci
a opravit známé nedostatky**.

# KONTEXT

V předchozí session jsi dokončil build podle METAPROMPT.md. Sám jsi poctivě
přiznal 5 odchylek, z nichž jedna je blokující:

1. **BLOKOVÁNO**: Názvy npm balíčků v `$ComponentCatalog` jsou neověřené odhady
   (`reasonix`, `dsh`, `pi-reasonix`). Před reálným Setup je nutno ověřit.
2. Nahradil jsi specifikované skripty vlastními implementacemi.
3. `Launch-*.cmd` má vylepšenou detekci pwsh — OK, zachovat.
4. Landing page nebyla otevřena v prohlížeči.
5. `env\.env` záměrně chybí — OK, vytvoří se při setupu.

# MISE

Proveď tyto kroky v tomto pořadí:

## KROK 1 — Ověření npm balíčků (KRITICKÉ)

Pro každý balíček z `$ComponentCatalog` proveď:

```powershell
npm view <package> version
```

Zaznamenej výsledek. Pro každý balíček rozhodni:

| Stav | Akce |
|---|---|
| Existuje, verze OK | Ponech |
| Existuje pod jiným názvem | Oprav v `$ComponentCatalog` |
| Neexistuje na npm | Nahraď alternativou nebo odstraň + zapiš do docs |

Známé skutečnosti, které MUSÍŠ respektovat:

- **Reasonix NENÍ na npm** — je to binární distribuce z GitHub releases.
  Správný způsob instalace: stažení z `https://github.com/esengine/DeepSeek-Reasonix/releases`
  nebo `winget install esengine.reasonix` (pokud existuje).
  Pokud není winget balíček, implementuj instalaci přes `Invoke-WebRequest` +
  rozbalení ZIP do `bin\reasonix\`.

- **DSH na npm**: `@deepseek-ai/dsh` (ne `dsh`).

- **Pi**: `@mariozechner/pi-coding-agent` (ne `pi-reasonix`).

- **Claude Code**: `@anthropic-ai/claude-code` — OK.

Výsledek zapiš do `docs/02-CONFIG.md` jako tabulku "Ověřené balíčky".

## KROK 2 — Oprava `$ComponentCatalog`

V `scripts/Setup-DeepSeekStack.ps1`:

1. Nahraď `$ComponentCatalog` ověřenými hodnotami z KROKU 1.
2. Pro Reasonix použij vlastní instalační funkci `Install-ReasonixBinary`,
   která nestahuje z npm, ale z GitHub releases.
3. Pro každý balíček přidej `Source` field:
   - `"npm"` pro npm balíčky
   - `"github"` pro Reasonix s URL
   - `"winget"` pokud je winget balíček
4. Přidej `Verify` funkci, která po instalaci ověří, že binárka existuje
   a odpovídá na `--version`.

## KROK 3 — PSScriptAnalyzer clean pass

Spusť na všech skriptech:

```powershell
Invoke-ScriptAnalyzer -Path .\scripts\ -Recurse -Severity Warning, Error
Invoke-ScriptAnalyzer -Path .\launcher\ -Recurse -Severity Warning, Error
```

Pro každý Warning/Error:
- Oprav kód (preferováno)
- Nebo přidej `[Diagnostics.CodeAnalysis.SuppressMessageAttribute(...)]`
  s odůvodněním v komentáři

**Cíl: prázdný výstup.**

## KROK 4 — Test-Workspace plný self-test

Rozšiř `scripts/Test-Workspace.ps1` o tyto kontroly:

1. Všechny `.ps1` mají UTF-8 BOM (kontrola prvních 3 bytů = EF BB BF)
2. Všechny `.cmd` mají CRLF (`\r\n`)
3. Všechny `.md`/`.json`/`.toml` mají LF (žádné `\r\n`)
4. Všechny `.ps1` projdou `Invoke-ScriptAnalyzer`
5. Všechny `.ps1` mají `.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`
6. `.env.example` existuje, `.env` NENÍ v gitu
7. `README.md` obsahuje funkční relativní odkazy (všechny cíle existují)
8. `landing/index.html` má validní strukturu (spárované tagy)
9. `METAPROMPT.md` má všech 10 fází
10. Všechny prompty z `prompts/` mají YAML frontmatter (title, description)

Spusť a oprav všechny FAIL.

## KROK 5 — Verifikace landing page

Otevři `landing\index.html` v prohlížeči (použij `Start-Process`).
Zkontroluj:

- Logo je vidět (není `currentColor` bez nadřazeného `color`)
- Všechny interní odkazy fungují
- Theme toggle funguje (light ↔ dark)
- Responzivní layout (zúž okno)
- Žádné chyby v konzoli prohlížeče (F12)

Pokud nemůžeš otevřít prohlížeč, **staticky analyzuj HTML** a vypiš
potenciální problémy.

## KROK 6 — Porovnání s originálními skripty

Pokud máš v `docs/` nebo `gists/` referenční verze původních skriptů
(Setup-DeepSeekStack.ps1, Get-AiStackInfo.ps1, Repair-Repo.ps1),
porovnej je s aktuálními. Vypiš rozdíly do `docs/06-DEVIATIONS.md`:

| Soubor | Odchylka od specifikace | Dopad | Doporučení |
|---|---|---|---|
| ... | ... | ... | ... |

## KROK 7 — Finální verifikace

1. Spusť `scripts\Test-Workspace.ps1` → musí vrátit PASS
2. Spusť `scripts\Setup-DeepSeekStack.ps1 -WhatIf -SkipInstall` → OK
3. Spusť `scripts\Get-AiStackInfo.ps1` → OK
4. Spusť `scripts\Repair-Repo.ps1 -WhatIf` → OK
5. Otevři `launcher\Start-PortableAI.cmd` → menu funguje

## KROK 8 — Dokumentace změn

Aktualizuj:
- `CHANGELOG.md` — nová sekce `[1.0.1]` s opravami
- `VERSION` — `1.0.1`
- `docs/02-CONFIG.md` — ověřené balíčky
- `docs/06-DEVIATIONS.md` — nový soubor s rozdíly

## KROK 9 — Git commit

```powershell
git add .
git status
```

**Před commitem ověř:**
- `.env` NENÍ ve stage
- `node_modules/` NENÍ ve stage
- `logs/` NENÍ ve stage (jen `.gitkeep`)

Pak:

```powershell
git commit -m "verify: npm packages, analyzer clean, self-test PASS

- Verified all npm packages against registry
- Fixed Reasonix installation (GitHub releases, not npm)
- PSScriptAnalyzer clean pass on all scripts
- Extended Test-Workspace with 10 checks
- Documented deviations in docs/06-DEVIATIONS.md
- Landing page verified in browser"
```

## KROK 10 — Report

Vypiš:

```
=== FOLLOW-UP COMPLETE ===
npm packages verified:  X/Y
npm packages fixed:     X
PSScriptAnalyzer:       PASS/FAIL
Test-Workspace:         PASS/FAIL
Landing page:           OK/FAIL
Git commit:             <hash>
Cost:                   $X.XXXX
Next manual step:       <co zbývá ručně>
```

# KONSTRAINY

- **Nespouštěj `npm install` bez ověření názvu balíčku.**
- **Nespouštěj `Remove-Item` bez `-WhatIf` první.**
- **Nepřidávej secrets do gitu.**
- **Pokud narazíš na chybu, kterou nelze opravit**, zapiš ji do
  `docs/03-TROUBLESHOOTING.md` a pokračuj.
- **Používej `-WhatIf` pro všechny destruktivní operace.**

# ACCEPTANCE CRITERIA

- [ ] Všechny npm balíčky ověřeny proti registry
- [ ] Reasonix má vlastní instalační funkci (mimo npm)
- [ ] `Invoke-ScriptAnalyzer` vrací prázdný výstup
- [ ] `Test-Workspace.ps1` vrací PASS
- [ ] Landing page ověřena (vizuálně nebo staticky)
- [ ] `docs/06-DEVIATIONS.md` vytvořen
- [ ] `CHANGELOG.md` aktualizován
- [ ] `VERSION` = 1.0.1
- [ ] Git commit vytvořen
- [ ] Finální report vypsán
