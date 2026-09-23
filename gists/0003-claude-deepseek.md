# 0003 — Claude Code s DeepSeek backendem

**Kdy to použít:** chcete používat Claude Code CLI proti DeepSeek API místo
Anthropic API.

## Princip

Claude Code umí mluvit s libovolným endpointem, který implementuje
Anthropic-compatible API. DeepSeek takový endpoint nabízí, takže stačí přenastavit
`ANTHROPIC_BASE_URL` a předat DeepSeek klíč jako `ANTHROPIC_AUTH_TOKEN`.

## Proměnné prostředí

```dotenv
# env/.env
ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
ANTHROPIC_AUTH_TOKEN=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ANTHROPIC_MODEL=deepseek-chat

# Volitelné: menší model pro rychlé operace
ANTHROPIC_SMALL_FAST_MODEL=deepseek-chat
```

> `ANTHROPIC_AUTH_TOKEN` je stejná hodnota jako `DEEPSEEK_API_KEY`. Ve `.env`
> ji definujte jednou a druhou odvoďte — viz blok níže.

## Nastavení v PowerShellu

```powershell
. .\scripts\_common.ps1
Import-DotEnv

# Odvození tokenu z DeepSeek klíče (jediné místo s hodnotou)
if ($env:DEEPSEEK_API_KEY -and -not $env:ANTHROPIC_AUTH_TOKEN) {
    $env:ANTHROPIC_AUTH_TOKEN = $env:DEEPSEEK_API_KEY
}
if (-not $env:ANTHROPIC_BASE_URL) {
    $env:ANTHROPIC_BASE_URL = 'https://api.deepseek.com/anthropic'
}

Write-Log -Message ('Claude Code → {0} ({1})' -f $env:ANTHROPIC_BASE_URL, (Get-MaskedValue -Value $env:ANTHROPIC_AUTH_TOKEN)) -Level OK

claude
```

## Ověření

```powershell
# Musí vrátit 200 a odpověď modelu
claude -p "Odpověz jedním slovem: funguje?"
```

Když vrátí `401`, je token neplatný nebo neodpovídá base URL. Když vrátí
`404`, je špatná cesta endpointu (`/anthropic` vs `/v1`).

## Časté chyby

| Chyba | Příčina |
| --- | --- |
| `401 Unauthorized` | `ANTHROPIC_AUTH_TOKEN` je placeholder nebo expirovaný |
| `404 Not Found` | chybí `/anthropic` v base URL |
| Prázdná odpověď | model v `ANTHROPIC_MODEL` neexistuje |
| Klíč v `settings.json` | secrets patří jen do `env\.env` |
