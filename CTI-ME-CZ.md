# ComputerCode pro Tekkit SMP

AI agent s OpenRouterem pro **ComputerCraft 1.89.2 / Minecraft 1.12.2 / Lua 5.1**.
Kompatibilitní úprava projektu [REALEncryptal/computercode](https://github.com/REALEncryptal/computercode).
Původní autor a licence závislostí zůstávají zachovány.

## Instalace a aktualizace

V shellu počítače v Minecraftu (Lua konzoli nejprve opusť pomocí `exit()`):

```sh
wget run https://raw.githubusercontent.com/karelvysinka/computercode-tekkit/main/install.lua
check-tekkit
computercode
```

Instalátor stahuje **jen z tohoto repozitáře**, včetně upravených PixelUI a Shrekbox.
Nejprve zjistí SHA aktuálního commitu `main`, pak všechny soubory načte z tohoto
jednoho commitu. Nestahuje původní ComputerCode ani žádné knihovny z Pastebinu.
Pokud se verzi nepodaří zjistit, nic nepřepíše. Při chybě uprostřed instalace
aplikaci nespouštěj a zopakuj instalátor se stejným SHA, které vypsal.

Příkaz nahoře funguje i jako aktualizace. Alternativně již nainstalovaný
`install.lua` spustíš jako `install`, volitelně `install COMMIT_SHA`.
`install-tekkit` je totožný alias. Konfigurace a konverzace se nepřepisují;
před aktualizací je můžeš zálohovat. Instalátor potřebuje přibližně 720 kB pro
runtime a další prostor pro relace. HTTP musí umožňovat api.github.com,
raw.githubusercontent.com a openrouter.ai. API klíč zadáš až při spuštění.

## Stav ověření

Lokálně prošla syntaxe Lua 5.1, načtení modulů se stuby CC API a testy JSON,
kompilace kódu, HTTP a instalátoru. Skutečné UI, monitor, TLS a OpenRouter je
potřeba ověřit ve tvém Minecraftu. Diagnostika `check-tekkit` je bez API volání.
Původní seznam modelů není živý katalog; použij dostupný model s tool calling.

Viz [AUDIT-CZ.md](AUDIT-CZ.md), [AUDIT-ODKAZU-CZ.md](AUDIT-ODKAZU-CZ.md).
Volitelné ukázky v `extras` nejsou instalovány ani garantovány pro Tekkit.
Hudební ukázka navíc vyžaduje explicitní adresu hudební služby, nemá výchozí cizí server.
Odkaz na původní projekt je uveden pouze kvůli původu kódu, nikoli jako zdroj aktualizací.

Úplný seznam instalovaných souborů: RUNTIME_FILES.txt.
