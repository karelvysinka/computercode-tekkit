# Kontrola adres a zdrojů

Prohledány všechny textové soubory včetně minifikované rawterm.lua, PixelUI,
agentních modulů, ukázek, dokumentace a instalačních skriptů. Vedle URL byly
hledány HTTP požadavky, shell.run/execute, načítání Lua a zmínky o instalaci.

| Nález | Výsledek |
|---|---|
| Původní README | Nahrazen českým návodem instalujícím tento fork. |
| install-upstream.lua.txt | Odstraněn; nemůže být omylem použit ke stažení upstreamu. |
| install.lua a install-tekkit.lua | Oba používají pouze karelvysinka/computercode-tekkit. Žádný záložní upstream, Pastebin ani přepnutí na jiný server. |
| Větev main | Jednou se přes GitHub API převede na commit SHA; všechny soubory jsou staženy ze stejné verze. Selhání rozlišení verze nic nepřepisuje. |
| PixelUI a Shrekbox | Lokální require, žádné síťové načítání ani samostatný updater. Instalátor vždy nahrává upravené kopie z tohoto forku. |
| api.lua | Skutečný API endpoint OpenRouteru zůstává; HTTP-Referer opraven na tento repozitář. Referer nic nestahuje. |
| agent.lua | Systémové pokyny určují tento fork jako zdroj aplikace i závislostí. Generování a spouštění libovolného Lua však není sandbox; nejde o technickou blokaci každého možného stažení. |
| extras/music.lua | Cizí pevný hudební endpoint odstraněn. Ukázka vyžaduje explicitní URL služby. Na GitHub kódový endpoint se nepřesměrovává, protože potřebuje hudební API. |
| extras/rawterm.lua | Zůstává volitelná knihovna, nepoužívá pevný repozitář ani updater. Delegát přijímá adresu od volajícího; není instalována. |
| docs/http.md | api.example.com je pouze ilustrační adresa v příkladu, nespouští se automaticky. |
| Attribution a tweaked.cc | Odkazy na autora a reference jsou pouze dokumentační, nejsou download fallback. |

Oprava nepřesměrovává komunikaci s OpenRouterem na GitHub. Nastavení API klíče
není součástí repozitáře. Starší již nainstalovaný upstream install.lua musí být
nahrazen novým příkazem z README; samotné nahrání na GitHub jej ve hře nezmění.
