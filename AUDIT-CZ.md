# Kontrola kompatibility

Provedeno: statická inventura všech Lua souborů upstream projektu včetně PixelUI,
Shrekbox a doplňkových ukázek, kontrola odkazovaných API a syntaxe v Lua 5.1.
Nejedná se o úplný bezpečnostní audit ani o ověření všech UI větví za běhu.

| Oblast | Zjištění a zásah |
|---|---|
| shrekbox.lua | colors.toBlit je od 1.94.0; LUT nyní používá přímo hexadecimální znak. |
| compat.lua | Doplní chybějící toBlit a table.pack/unpack, poskytuje kompilaci přes loadstring/setfenv v Lua 5.1. |
| JSON | Původní serializeJSON(v, {unicode_strings=true}) používá přetížení až od 1.106.0. Všechny aktivní části agenta používají vlastní striktní encoder bez změny globálního textutils. |
| JSON čtení | Používá existující unserializeJSON od 1.87 s parse_null; novější parse_empty_array se nepředává. Zachování prázdných polí ověří místní diagnostika. |
| tools.lua | Lua nástroj používá kompatibilní kompilátor; run_script nově nepovažuje shell.run=false za úspěch. Informace o počítači obsahují _HOST a _VERSION. |
| api.lua | Přečte také třetí návratovou hodnotu HTTP chybové odpovědi, takže se zobrazí například chyba 401 místo obecného selhání sítě. |
| pixelui.lua | Lokální unpack podporuje také Lua 5.1 unpack. Knihovna zachována, nikoli nahrazena jednoduchým chatem. |
| agent.lua | Explicitní cílová verze; vyžaduje zjištění skutečných metod periferií místo předpokladu moderních generic inventory/energy/fluid API. |
| docs.lua | Každý načtený referenční dokument dostane upozornění na cílovou verzi. Reference nejsou celé přepsány na historickou dokumentaci. |
| computercode.lua | Inicializuje kompatibilitu před závislostmi. Nezdvojuje pracovní adresář při sestavování package.path. |
| os.epoch, require | Na uživatelově screenshotu dostupné. Nepřidává se odhadovaná náhrada času. |
| window.getLine | Dostupné od 1.84.0, nevyžaduje náhradu pro 1.89.2. |
| cc.expect | Dostupnost ověří check-tekkit přímo v modpacku; žádná neúplná náhrada se nevkládá. |
| rawterm.lua | Minifikovaná volitelná knihovna vyžadující další API včetně string.pack/unpack. Hlavní agent ji neimportuje. Přesunuta do extras, neinstaluje se a nepovažuje se za portovanou. |
| Ukázky | example.lua, infopad.lua a park.lua jsou beze změn v extras. music.lua vyžaduje explicitní URL služby. Nejsou součástí podporovaného runtime agenta. Zejména audio/DFPWM není pro tento modpack přislíbeno. |
| Instalace | Nový instalátor stahuje opravené soubory z tohoto repozitáře. Původní instalátor byl odstraněn; oba nové instalátory používají pouze tento fork a jeden commit SHA. |

## Ověření

- Syntaxe všech dodaných Lua souborů v enginu Lua 5.1 (lupa.lua51).
- Načtení obou grafických knihoven a všech devíti agentních modulů se stuby CC API.
- Převod barev včetně odmítnutí neplatné barvy.
- Kompilace výrazu s prostředím, odmítnutí chybné syntaxe, table.pack s nil.
- JSON objekty, pole, sentinel null, sentinel prázdného pole, čeština, emoji,
  uvozovky, nové řádky, odmítnutí cyklu a nečíselné číselné hodnoty.
- HTTP úspěch a HTTP 401 s chybovým handlem; skutečné síťové volání nepoužito.

Testovací skript a výstup jsou v validation. Externí knihovna lupa není potřeba
v Minecraftu; slouží jen pro místní vývojové testy na Pythonu.

## Referenční zdroje

- https://tweaked.cc/module/colors.html (toBlit od 1.94.0)
- https://tweaked.cc/module/textutils.html (serializeJSON options od 1.106.0,
  unserializeJSON od 1.87.0, parse_empty_array od 1.100.6)
- https://tweaked.cc/module/window.html (getLine od 1.84.0)
- README původního projektu uvádí licenci MIT; licence přibalených závislostí
  zůstávají jejich původní. Původní texty a hlavičky byly zachovány.
