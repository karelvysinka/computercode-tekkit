# monitor (peripheral)

A monitor is a term-like peripheral. Get it with `peripheral.find("monitor")` or `peripheral.wrap("monitor_0")`.

It has all the `term` methods (`write`, `blit`, `clear`, `setCursorPos`, `setBackgroundColor`, etc.) plus:

- `monitor.setTextScale(scale)` - 0.5, 1, 2, 3, 4, 5. Smaller scale = more characters fit.
- `monitor.getTextScale()`.

Multi-block monitor arrays (placed adjacent) act as a single bigger monitor — same wrapped object, just larger `getSize()`.

Touch input fires `monitor_touch` events: `event, side, x, y = os.pullEvent("monitor_touch")`. Coordinates are in the monitor's character grid.

## Pattern: dual mirror via term.redirect
```lua
local m = peripheral.find("monitor")
m.setTextScale(0.5)
local prev = term.redirect(m)
print("hello on monitor")
term.redirect(prev)
```

## Pattern: write directly without redirecting
```lua
m.setCursorPos(1, 1)
m.setBackgroundColor(colors.blue)
m.setTextColor(colors.white)
m.write(" Hi ")
```
