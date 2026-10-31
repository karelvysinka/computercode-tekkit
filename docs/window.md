# window

In-memory virtual terminal layered on a parent term/monitor. Useful for:
- buffering off-screen and flushing as one frame (no flicker)
- splitting a terminal into multiple panes
- giving a sub-program its own clipped surface

- `window.create(parent, x, y, width, height [, visible])` -> window. `visible` defaults to true.

The returned window has the full `term` API (write, blit, clear, setCursorPos, getSize, setBackgroundColor, etc.) plus:

- `:setVisible(bool)` - hide/show.
- `:isVisible()`.
- `:redraw()` - force flush to the parent.
- `:reposition(x, y [, width [, height [, parent]]])`.
- `:getPosition()` -> `x, y`.
- `:restoreCursor()` - put parent's cursor back where this window had it.
- `:getLine(y)` -> `text, fgHex, bgHex`.

## Pattern: double-buffered rendering
```lua
local win = window.create(term.current(), 1, 1, term.getSize(), false)
local prev = term.redirect(win)
draw_frame()       -- writes to off-screen window
term.redirect(prev)
win.setVisible(true) -- atomic flush
```
