# 0002 — Konfigurace Reasonixu s DeepSeek backendem (cache-first + ceny)

**Kdy to použít:** zakládáte konfiguraci Reasonixu, chcete vědět, které klíče
jsou opravdu potřeba, a chcete, aby se náklady daly odečíst.

## Kde konfigurace bydlí

Reasonix čte konfiguraci v tomto pořadí (první vyhrává):

```
flag > ./reasonix.toml (projekt) > <Reasonix home>/config.toml > výchozí hodnoty
```

`<Reasonix home>` je na Windows `%APPDATA%\reasonix`; proměnná `REASONIX_HOME`
ho přesune (i se stavem a cache). Vzor z workspace
(`gists/snippets/reasonix.toml` → `data/reasonix/config.toml`) je **výchozí
bod**, ne živá konfigurace — Reasonix ho sám nečte.

## Konfigurace

```toml
# Cíl: <Reasonix home>/config.toml nebo ./reasonix.toml v projektu.
# Klíč se bere z prostředí (DEEPSEEK_API_KEY), nikdy se neukládá sem.

config_version = 10
default_model  = "deepseek/deepseek-flash"   # "poskytovatel/model", nebo jen poskytovatel

[ui]
show_turn_usage = true   # token a cost receipt u každého requestu

[billing]
display_currency = "USD"   # auto|CNY|USD; mění jen zobrazení

[agent]
temperature   = 0.0
compact_ratio = 0.80   # jediný automatický trigger kompakce (0.30-0.85)

[environment]
enabled = true   # stabilní souhrn prostředí → byte-stabilní prefix (cache)

[permissions]
mode = "ask"   # ask|allow|deny pro zápisové nástroje

[[providers]]
name          = "deepseek"
kind          = "openai"
base_url      = "https://api.deepseek.com"
models        = ["deepseek-flash", "deepseek-v4-flash", "deepseek-v4-pro"]
default       = "deepseek-flash"
api_key_env   = "DEEPSEEK_API_KEY"
context_window = 1000000
max_output_tokens = 32768   # strop výstupu na turn (cost control)
billing_currency  = "USD"
thinking      = "enabled"
web_search    = true
supported_efforts = ["disabled", "low", "high", "max"]
default_effort    = "high"
model_overrides = { "deepseek-v4-pro" = { max_output_tokens = 65536 } }
```

## Proč jsou tam právě tyto klíče

| Klíč | Význam |
| --- | --- |
| `api_key_env` | odkaz na proměnnou prostředí místo hodnoty — konfigurace je bezpečná ke sdílení |
| `default_model` | `poskytovatel/model`; určuje, co se spustí bez `--model` |
| `compact_ratio` | kompakce kontextu; nižší hodnota = kratší prefix = méně cache hitů |
| `[environment] enabled` | stabilní souhrn prostředí v promptu drží prefix byte-stabilní |
| `[permissions] mode = "ask"` | agent nesmí zapisovat bez potvrzení (zapisujte `allow` jen vědomě) |
| `max_output_tokens` | strop výstupu na jeden turn; dražší model má vlastní přes `model_overrides` |
| `billing_currency` | měna, ke které se vážou pevné sazby poskytovatele |
| `default_effort` | `/effort auto`; `low` = levnější a rychlejší, `high`/`max` = dražší |

## Cachování

DeepSeek vrací prompt z diskové cache jen tehdy, když se **začátek** requestu
nemění byte po byte. Praktické důsledky:

- `compact_ratio` snižte, jen když potřebujete uvolnit kontext — jinak si
  zaplatíte víc summary volání **a** přijdete o cache hity.
- `[environment] enabled` nechte zapnuté; souhrn je stabilní, kdežto vlastní
  vkládané bloky (čas, náhodná pořadí) prefix rozbijí.
- Sledujte `/status` a `[ui] show_turn_usage`; efektivní hodnotu kompakce
  vypíše `reasonix config compact-ratio`.

## Ceny

Reasonix má vlastní oficiální tabulku (`cache_hit` / `input` / `output` za 1M
tokenů) — **nepinujte `prices`, dokud k tomu nemáte důvod**: ručně zapsaná
sazba ji přebije, označí se jako „custom price protected“ a přestane se
aktualizovat.

```powershell
reasonix doctor billing     # display currency, sazby a fingerprinty poskytovatelů
reasonix config currency    # zobrazená měna (auto|CNY|USD)
```

Když model v katalogu není (starší nebo přejmenovaný název), zůstane bez ceny
a cost receipt se nevyplní. Teprve tehdy dopsat vlastní sazbu:

```toml
prices = { "muj-model" = { cache_hit = 0.006, input = 0.3, output = 1.2, currency = "$" } }
```

## Nasazení

```powershell
# 1. Zkopírujte vzor tam, odkud ho Reasonix čte (setup ho už vysadil do data/)
Copy-Item gists\snippets\reasonix.toml data\reasonix\config.toml
Copy-Item data\reasonix\config.toml "$env:APPDATA\reasonix\config.toml"

# 2. Ověřte, že je klíč načtený z prostředí
. .\scripts\_common.ps1
Import-DotEnv
Get-MaskedValue -Value $env:DEEPSEEK_API_KEY

# 3. Ověřte sazby a spusťte Reasonix
reasonix doctor billing
reasonix
```

## Co bylo ve starším vzoru špatně

Starší vzor popisoval schéma, které Reasonix 1.38.x nezná — klíče se tiše
ignorovaly. Při upgradu se držte těchto náhrad:

| Starý klíč | Stav | Náhrada |
| --- | --- | --- |
| `[provider] name/base_url/api_key_env` | neexistuje | `[[providers]]` (pole poskytovatelů) s `name`/`kind`/`base_url`/`api_key_env` |
| `[model] default/reasoning/max_tokens/temperature` | neexistuje | `default_model`, `models`, `max_output_tokens`, `[agent] temperature` |
| `[agent] reasoning_effort` | neexistuje | `default_effort` (a `supported_efforts`) u poskytovatele |
| `[agent] auto_approve` | neexistuje | `[permissions] mode = "ask"/"allow"` |
| `[agent] max_iterations` | neexistuje | strop je v CLI (`reasonix run --max-steps`) |
| `[workspace] root/log_dir/respect_gitignore` | neexistuje | `[sandbox] workspace_root`, `allow_write`; logy jsou v Reasonix home |
| `REASONIX_CONFIG_DIR`, `REASONIX_MODEL`, `REASONIX_REASONING_EFFORT` | neexistují | `REASONIX_HOME`, `reasonix --model`, `default_effort` v konfiguraci |

## Časté chyby

- **Hodnota klíče přímo v TOML.** Nikdy — soubor může skončit v gitu.
- **Soubor na špatném místě.** `data/reasonix/config.toml` Reasonix nečte;
  musí být v projektu jako `./reasonix.toml` nebo v `<Reasonix home>`.
- **Ručně zapsané `prices`.** Přepíšou oficiální katalog a přestanou se
  aktualizovat; ověřte `reasonix doctor billing`.
- **`REASONIX_HOME` nastavené „pro jistotu“.** Přesune celý stav i cache;
  globální konfigurace v `%APPDATA%\reasonix` se pak neuplatní.
