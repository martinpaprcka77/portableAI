# Struktura workspace

```
C:\portableAI\
├── README.md              vstupní bod pro člověka
├── VERSION                semver workspace
├── CHANGELOG.md           historie změn (Keep a Changelog)
├── LICENSE                MIT
├── METAPROMPT.md          zadání, podle kterého byl workspace postaven
├── .env.example           vzor konfigurace (bez secrets)
├── .gitignore / .gitattributes / .editorconfig
│
├── scaffold/              dokumentace samotné struktury
├── scripts/               PowerShell automatizace
├── prompts/               knihovna promptů pro AI agenty
├── docs/                  technická dokumentace
├── manual/                uživatelský manuál
├── launcher/              .cmd/.ps1 spouštěče a interaktivní menu
├── landing/               statický HTML rozcestník
├── gists/                 znovupoužitelné snippety a šablony
├── env/                   konfigurace prostředí
├── logs/                  runtime logy (negitované)
├── data/                  runtime data (negitovaná)
├── bin/                   lokální binárky/npm prefix (negitovaný)
└── .vscode/               doporučené nastavení editoru
```

## Kdo co vlastní

| Složka | Vlastník | Měnit ručně? |
| --- | --- | --- |
| `scripts/`, `launcher/` | DevOps / agent | ano, ale vždy přes `Test-Workspace.ps1` |
| `prompts/`, `docs/`, `manual/`, `gists/` | obsah | ano |
| `landing/` | obsah / frontend | ano |
| `logs/`, `data/`, `bin/` | runtime | ne — přepisuje se automaticky |

## Vazby mezi vrstvami

```
launcher/*.cmd ──▶ launcher/Menu.ps1 ──▶ scripts/*.ps1 ──▶ scripts/_common.ps1
                                              │
                                              └─▶ logs/build-*.log
landing/index.html ──(relativní odkazy)──▶ docs/, prompts/, manual/, launcher/
```

`_common.ps1` je jediný sdílený bod — všechny ostatní skripty ho dot-sourcují
a používají `Get-WorkspaceRoot` pro odvození absolutních cest.
