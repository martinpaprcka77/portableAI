# 03 — FAQ

## 1. Musím být administrátor?

Ne. Workspace je navržený tak, aby fungoval bez elevace. Když nějaký krok
admin práva vyžaduje, je to chyba — nahlaste ji.

## 2. Kam se ukládá API klíč?

Do `env\.env`, který je v `.gitignore`. Nikdy do shell profilu, `settings.json`
ani do argumentů příkazové řádky. Viz [docs/05-SECURITY.md](../docs/05-SECURITY.md).

## 3. Co se stane, když `.env` neexistuje?

Diagnostika to ohlásí jako `WARN`, setup ho vytvoří ze vzoru. Nástroje se
spustí, ale nebudou moci volat model.

## 4. Proč `.ps1` soubory potřebují UTF-8 BOM?

PowerShell bez BOM interpretuje soubor v systémové znakové sadě (na české
Windows obvykle CP1250), takže se rozbije diakritika. BOM říká jednoznačně
„toto je UTF-8“.

## 5. Proč `.cmd` soubory potřebují CRLF?

`cmd.exe` nedokáže spolehlivě zpracovat soubor s LF koncovkami — příkazy se
slepují nebo se interpretují nesprávně. Proto je vynucujeme přes
`.gitattributes` a kontrolujeme v `Test-Workspace.ps1`.

## 6. Proč se nic neinstaluje globálně?

Globální instalace vyžaduje admin práva, rozbíjí se při reinstalaci systému a
nedá se přenést na USB. Lokální npm prefix v `bin/npm-global` řeší všechny tři
problémy.

## 7. Jak nainstaluji nový nástroj?

Přidejte ho do `$ComponentCatalog` v `scripts/Setup-DeepSeekStack.ps1` a
spusťte setup. Nebo ručně:

```powershell
npm install -g --prefix bin\npm-global <balíček>
```

`-g --prefix` zapíše spustitelné shimy přímo do `bin\npm-global`, takže je
launcher najde v `PATH` (viz [docs/02-CONFIG.md](../docs/02-CONFIG.md)).

## 8. Jak spustím workspace z jiné cesty než `C:\portableAI`?

Stačí složku zkopírovat. Všechny skripty si kořen odvozují z vlastní pozice:

```powershell
pwsh -File E:\ai\scripts\Get-AiStackInfo.ps1
```

Po přesunu spusťte `Test-Workspace.ps1 -Fix`.

## 9. Co dělá `-WhatIf`?

Nic nezmění, jen vypíše, co by se změnilo. Používejte ho u každého skriptu,
který mění stav (`Setup-*`, `Repair-*`, `Test-* -Fix`).

## 10. `Test-Workspace.ps1` hlásí FAIL. Co teď?

Přečtěte detail u selhané kontroly. Nejčastěji pomůže:

```powershell
pwsh -File scripts\Test-Workspace.ps1 -Fix -WhatIf   # náhled
pwsh -File scripts\Test-Workspace.ps1 -Fix           # oprava
```

Chybějící **soubory** s obsahem se neopravují automaticky — ty musíte doplnit.

## 11. Jak přidám vlastní prompt?

Vytvořte `prompts/07-nazev.md`, přidejte ho do tabulky v `prompts/README.md`
a držte stejnou strukturu jako ostatní prompty (kontext, postup, kritérium
hotovo).

## 12. Proč se `Get-AiStackInfo.ps1` nezapisuje do `logs/` automaticky?

Diagnostika je read-only nástroj. Nechceme, aby pouhé „podívej se, jak to
vypadá“ vytvářelo soubory. Log do souboru zapnete přes `-LogFile`.

## 13. Jak otestuji, že workspace přežije přesun?

```powershell
Copy-Item C:\portableAI E:\portableAI -Recurse
pwsh -File E:\portableAI\scripts\Test-Workspace.ps1 -Fix
```

Pak zkontrolujte, že neexistuje žádná absolutní cesta:

```powershell
Get-ChildItem E:\portableAI -Recurse -File | Select-String 'C:\\portableAI'
```

## 14. Můžu workspace verzovat v gitu?

Ano, a doporučujeme to. `logs/`, `data/`, `bin/` a `.env` jsou ignorované.
Po `git init` spusťte `Repair-Repo.ps1`, který nastaví atributy a koncovky.

## 15. Co když mám jiný model než DeepSeek?

Změňte v `env\.env` proměnné `DEEPSEEK_BASE_URL` a `DEEPSEEK_MODEL` na svůj
OpenAI-kompatibilní endpoint. Workspace je na konkrétním poskytovateli
nezávislý — jde jen o proměnné prostředí.

## 16. Jak zjistím, které verze nástrojů mám?

```powershell
pwsh -File scripts\Get-AiStackInfo.ps1 -NoBanner
```

Sekce `7. AI nástroje` vypíše verze pro node, npm, git a `pwsh` a dostupnost
jednotlivých agentů.

## 17. Proč `Write-Log` zobrazuje DEBUG řádky jen někdy?

DEBUG řádky jsou určené pro ladění. Zobrazí se pouze při spuštění skriptu
s `-Verbose`; do log souboru (`-LogFile`) se zapisují vždy.

## 18. Jak workspace řeší diakritiku v konzoli?

`scripts/_common.ps1` nastaví `[Console]::OutputEncoding` na UTF-8 při každém
načtení. Pokud to host nepodporuje, jen to tiše přeskočí. Viz
[gists/0005-utf8-console.md](../gists/0005-utf8-console.md).

## 19. Kde najdu, proč je něco udělané tak, jak je?

V `docs/adr/`. Každé významné rozhodnutí má vlastní záznam s kontextem a
důsledky.

## 20. Jak workspace odinstaluju?

Smažte složku `C:\portableAI\`. Nic se nezapisuje do registru ani do
`%APPDATA%`. Nezapomeňte nejdřív zneplatnit API klíč, pokud ho jinde
nepoužíváte.
