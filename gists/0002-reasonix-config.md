# 0002 — Minimální `config.toml` pro Reasonix s DeepSeek backendem

**Kdy to použít:** zakládáte konfiguraci Reasonixu nebo chcete vidět, které
klíče jsou opravdu potřeba.

## Konfigurace

```toml
# data/reasonix/config.toml
# Minimální konfigurace Reasonixu s DeepSeek backendem.
# Klíč se bere z prostředí (DEEPSEEK_API_KEY), nikdy se neukládá sem.

[provider]
name    = "deepseek"
base_url = "https://api.deepseek.com/v1"
api_key_env = "DEEPSEEK_API_KEY"   # název proměnné, ne hodnota!

[model]
default   = "deepseek-chat"
reasoning = "deepseek-reasoner"
max_tokens = 8192
temperature = 0.2

[agent]
reasoning_effort = "medium"   # low | medium | high
auto_approve     = false      # vyžaduj potvrzení před zápisem
max_iterations   = 25

[workspace]
root        = "."             # relativně k této konfiguraci
log_dir     = "logs"
respect_gitignore = true
```

## Proč jsou tam právě tyto klíče

| Klíč | Význam |
| --- | --- |
| `api_key_env` | odkaz na proměnnou prostředí místo hodnoty — konfigurace je bezpečná ke sdílení |
| `reasoning_effort` | `low` = rychlé odpovědi, `high` = lepší u složitých úloh za vyšší cenu |
| `auto_approve = false` | agent nesmí zapisovat bez potvrzení; pro autonomní běh přepněte na `true` |
| `max_iterations` | pojistka proti zacyklení agenta |
| `respect_gitignore` | agent nepřečte `logs/`, `data/` a další ignorované cesty |

## Nasazení

```powershell
# 1. Zkopírujte vzor (setup to udělá sám, pokud cílový soubor neexistuje)
Copy-Item gists\snippets\reasonix.toml data\reasonix\config.toml

# 2. Ověřte, že je klíč načtený z prostředí
. .\scripts\_common.ps1
Import-DotEnv
Get-MaskedValue -Value $env:DEEPSEEK_API_KEY

# 3. Spusťte Reasonix
reasonix
```

## Časté chyby

- **Hodnota klíče přímo v TOML.** Nikdy — soubor může skončit v gitu.
- **Absolutní cesta ve `root`.** Rozbije přenositelnost na USB.
- **Chybějící `api_key_env`** a spoléhání na výchozí název proměnné.
