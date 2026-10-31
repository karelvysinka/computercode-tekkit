# term

Default output surface. Many APIs (e.g., paintutils, write) write to whatever `term.current()` is.

## Output
- `term.write(text)` - writes at cursor, advances cursor.
- `term.blit(text, fgHex, bgHex)` - per-character colors. Hex strings use `colors.toBlit(c)` digits.
- `term.clear()` / `term.clearLine()`.
- `term.scroll(n)` - positive scrolls up (gains blank lines at bottom).

## Cursor
- `term.setCursorPos(x, y)` / `term.getCursorPos()`.
- `term.setCursorBlink(bool)` / `term.getCursorBlink()`.

## Color
- `term.setTextColor(c)` / `term.setBackgroundColor(c)` - takes a `colors` value.
- `term.getTextColor()` / `term.getBackgroundColor()`.
- `term.isColor()` -> bool (false on basic computers).
- Palette: `term.setPaletteColor(slot, hex)` - e.g. `0xff0000`.

## Sizing
- `term.getSize()` -> `width, height` in characters.

## Redirection
- `term.redirect(target)` -> previous. Use the wrapped monitor as target to write to it.
- `term.current()` -> current target.
- `term.native()` -> the original system terminal.

## Pattern: redirect to a monitor and restore
```lua
local m = peripheral.find("monitor")
m.setTextScale(0.5)
local prev = term.redirect(m)
-- ... draw stuff ...
term.redirect(prev)
```
