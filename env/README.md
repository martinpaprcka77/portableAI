# env/

Runtime konfigurace workspace.

## Soubory

| Soubor | V gitu? | Význam |
| --- | --- | --- |
| `.env.example` | **ano** | vzor konfigurace, bezpečný ke sdílení |
| `.env` | **ne** (gitignored) | skutečné hodnoty včetně `DEEPSEEK_API_KEY` |

## První nastavení

```powershell
Copy-Item env\.env.example env\.env
notepad env\.env        # doplňte DEEPSEEK_API_KEY
```

Nebo to nechte na setupu, který `.env` vytvoří sám, pokud chybí:

```powershell
pwsh -File scripts\Setup-DeepSeekStack.ps1
```

## Jak se `.env` načítá

`Import-DotEnv` v `scripts/_common.ps1` hledá v tomto pořadí:

1. `env/.env`
2. `.env` v kořeni workspace

Nalezené hodnoty zapíše do proměnných prostředí **aktuálního procesu**.
Už existující proměnné nepřepisuje — můžete tedy hodnotu přebít zvenčí:

```powershell
$env:DEEPSEEK_MODEL = 'deepseek-reasoner'
pwsh -File scripts\Get-AiStackInfo.ps1
```

## Bezpečnost

- `env\.env` necommitujte, neposílejte e-mailem, nedávejte do chatu.
- Diagnostika hodnoty maskuje (`Get-MaskedValue`), takže `-Json` výstup je
  bezpečný ke sdílení.
- Při předání workspace jiné osobě **rotujte klíč**.

Podrobnosti: [`docs/05-SECURITY.md`](../docs/05-SECURITY.md).
